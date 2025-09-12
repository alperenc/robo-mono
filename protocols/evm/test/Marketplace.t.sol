// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/Marketplace.sol";
import "../contracts/VehicleRegistry.sol";
import "../contracts/RoboshareTokens.sol";
import "../contracts/PartnerManager.sol";
import "../contracts/Treasury.sol";
import "../contracts/Libraries.sol";
import "../script/DeployHelpers.s.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract MarketplaceTest is Test {
    Marketplace public marketplace;
    Marketplace public marketplaceImplementation;
    VehicleRegistry public vehicleRegistry;
    VehicleRegistry public vehicleImplementation;
    RoboshareTokens public roboshareTokens;
    RoboshareTokens public tokenImplementation;
    PartnerManager public partnerManager;
    PartnerManager public partnerImplementation;
    Treasury public treasury;
    Treasury public treasuryImplementation;
    ERC20Mock public usdc;
    
    ScaffoldETHDeploy public deployHelpers;
    ScaffoldETHDeploy.NetworkConfig public config;

    address public admin = makeAddr("admin");
    address public partner1 = makeAddr("partner1");
    address public partner2 = makeAddr("partner2");
    address public buyer = makeAddr("buyer");
    address public unauthorized = makeAddr("unauthorized");

    // Test vehicle data
    string constant TEST_VIN = "1HGCM82633A123456";
    string constant TEST_MAKE = "Honda";
    string constant TEST_MODEL = "Civic";
    uint256 constant TEST_YEAR = 2024;
    uint256 constant TEST_MANUFACTURER_ID = 1;
    string constant TEST_OPTION_CODES = "EX-L,NAV,HSS";
    string constant TEST_METADATA_URI = "ipfs://QmTestHash123456789abcdefghijklmnopqrstuvwxyzABC";

    string constant PARTNER1_NAME = "RideShare Fleet Co.";
    string constant PARTNER2_NAME = "Urban Delivery Services";

    // Role constants
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Test marketplace parameters
    uint256 constant REVENUE_TOKEN_PRICE = 100 * 10 ** 6; // $100 USDC
    uint256 constant TOTAL_REVENUE_TOKENS = 1000;
    uint256 constant TOKENS_TO_LIST = 500;
    uint256 constant LISTING_DURATION = 30 days;

    function setUp() public {
        // Setup network configuration
        deployHelpers = new ScaffoldETHDeploy();
        config = deployHelpers.getActiveNetworkConfig();
        
        // Cast to ERC20Mock for local testing (we know it's a mock on Anvil)
        usdc = ERC20Mock(config.usdcToken);

        // Deploy RoboshareTokens
        tokenImplementation = new RoboshareTokens();
        bytes memory tokenInitData = abi.encodeWithSignature("initialize(address)", admin);
        ERC1967Proxy tokenProxy = new ERC1967Proxy(address(tokenImplementation), tokenInitData);
        roboshareTokens = RoboshareTokens(address(tokenProxy));

        // Deploy PartnerManager
        partnerImplementation = new PartnerManager();
        bytes memory partnerInitData = abi.encodeWithSignature("initialize(address)", admin);
        ERC1967Proxy partnerProxy = new ERC1967Proxy(address(partnerImplementation), partnerInitData);
        partnerManager = PartnerManager(address(partnerProxy));

        // Deploy VehicleRegistry
        vehicleImplementation = new VehicleRegistry();
        bytes memory vehicleInitData = abi.encodeWithSignature(
            "initialize(address,address,address)", admin, address(roboshareTokens), address(partnerManager)
        );
        ERC1967Proxy vehicleProxy = new ERC1967Proxy(address(vehicleImplementation), vehicleInitData);
        vehicleRegistry = VehicleRegistry(address(vehicleProxy));

        // Deploy Treasury
        treasuryImplementation = new Treasury();
        bytes memory treasuryInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address)", admin, address(partnerManager), address(vehicleRegistry), address(roboshareTokens), address(usdc)
        );
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(address(treasuryImplementation), treasuryInitData);
        treasury = Treasury(address(treasuryProxy));

        // Deploy Marketplace
        marketplaceImplementation = new Marketplace();
        bytes memory marketplaceInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address,address)",
            admin,
            address(roboshareTokens),
            address(vehicleRegistry),
            address(partnerManager),
            address(treasury),
            address(usdc),
            config.treasuryFeeRecipient
        );
        ERC1967Proxy marketplaceProxy = new ERC1967Proxy(address(marketplaceImplementation), marketplaceInitData);
        marketplace = Marketplace(address(marketplaceProxy));

        // Setup roles and permissions
        vm.startPrank(admin);
        // Grant MINTER_ROLE to VehicleRegistry for token operations
        roboshareTokens.grantRole(MINTER_ROLE, address(vehicleRegistry));
        // Grant AUTHORIZED_CONTRACT_ROLE to Marketplace for Treasury operations
        treasury.grantRole(treasury.AUTHORIZED_CONTRACT_ROLE(), address(marketplace));
        // Authorize partners
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);
        partnerManager.authorizePartner(partner2, PARTNER2_NAME);
        vm.stopPrank();

        // Fund accounts with USDC (only for local testing)
        if (deployHelpers.isLocalNetwork()) {
            usdc.mint(partner1, 1000000 * 10 ** 6); // 1M USDC
            usdc.mint(partner2, 1000000 * 10 ** 6); // 1M USDC
            usdc.mint(buyer, 1000000 * 10 ** 6); // 1M USDC
        }
    }

    // Setup helper function
    function _setupVehicleAndTokens() internal returns (uint256 vehicleId, uint256 revenueShareTokenId) {
        vm.prank(partner1);
        (vehicleId, revenueShareTokenId) = vehicleRegistry.registerVehicleAndMintRevenueShareTokens(
            TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI, TOTAL_REVENUE_TOKENS
        );
    }

    function _approveAndLockCollateralAndList() internal returns (uint256 vehicleId, uint256 revenueShareTokenId, uint256 listingId) {
        (vehicleId, revenueShareTokenId) = _setupVehicleAndTokens();
        
        // Calculate required collateral
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        
        vm.startPrank(partner1);
        // Approve USDC for collateral
        usdc.approve(address(treasury), requiredCollateral);
        // Lock collateral and list tokens
        listingId = marketplace.lockCollateralAndList(
            vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS, TOKENS_TO_LIST, LISTING_DURATION, true
        );
        vm.stopPrank();
    }

    // Initialization Tests

    function testInitialization() public view {
        // Check contract references
        assertEq(address(marketplace.roboshareTokens()), address(roboshareTokens));
        assertEq(address(marketplace.vehicleRegistry()), address(vehicleRegistry));
        assertEq(address(marketplace.partnerManager()), address(partnerManager));
        assertEq(address(marketplace.treasury()), address(treasury));
        assertEq(address(marketplace.usdcToken()), address(usdc));
        assertEq(marketplace.treasuryAddress(), config.treasuryFeeRecipient);

        // Check initial state
        assertEq(marketplace.getCurrentListingId(), 1);

        // Check roles
        assertTrue(marketplace.hasRole(marketplace.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(marketplace.hasRole(keccak256("UPGRADER_ROLE"), admin));
    }

    function testInitializationWithZeroAddresses() public {
        // Test that initialization fails with zero addresses
        Marketplace newImpl = new Marketplace();
        
        vm.expectRevert("Marketplace__ZeroAddress");
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address,address)",
                address(0), // zero admin address
                address(roboshareTokens),
                address(vehicleRegistry),
                address(partnerManager),
                address(treasury),
                address(usdc),
                config.treasuryFeeRecipient
            )
        );
    }

    // Lock Collateral and List Tests

    function testLockCollateralAndListSuccess() public {
        (uint256 vehicleId, uint256 revenueShareTokenId) = _setupVehicleAndTokens();
        
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        
        // Expect CollateralLockedAndListed event
        vm.expectEmit(true, true, true, true, address(marketplace));
        
        uint256 listingId = marketplace.lockCollateralAndList(
            vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS, TOKENS_TO_LIST, LISTING_DURATION, true
        );
        vm.stopPrank();

        // Verify listing created
        assertEq(listingId, 1);
        
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.tokenId, revenueShareTokenId);
        assertEq(listing.amount, TOKENS_TO_LIST);
        assertEq(listing.pricePerToken, REVENUE_TOKEN_PRICE);
        assertEq(listing.seller, partner1);
        assertTrue(listing.isActive);
        assertTrue(listing.buyerPaysFee);

        // Verify tokens transferred to marketplace
        assertEq(roboshareTokens.balanceOf(address(marketplace), revenueShareTokenId), TOKENS_TO_LIST);
        assertEq(roboshareTokens.balanceOf(partner1, revenueShareTokenId), TOTAL_REVENUE_TOKENS - TOKENS_TO_LIST);

        // Verify collateral locked
        (, , bool isLocked, ,) = treasury.getVehicleCollateralInfo(vehicleId);
        assertTrue(isLocked);
    }

    function testLockCollateralAndListUnauthorizedPartner() public {
        (uint256 vehicleId, ) = _setupVehicleAndTokens();
        
        vm.expectRevert(PartnerManager.PartnerManager__NotAuthorized.selector);
        vm.prank(unauthorized);
        marketplace.lockCollateralAndList(
            vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS, TOKENS_TO_LIST, LISTING_DURATION, true
        );
    }

    function testLockCollateralAndListInvalidAmount() public {
        (uint256 vehicleId, ) = _setupVehicleAndTokens();
        
        vm.expectRevert("Marketplace__InvalidAmount");
        vm.prank(partner1);
        marketplace.lockCollateralAndList(
            vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS, TOTAL_REVENUE_TOKENS + 1, LISTING_DURATION, true
        );
    }

    function testLockCollateralAndListInsufficientTokenBalance() public {
        (uint256 vehicleId, uint256 revenueShareTokenId) = _setupVehicleAndTokens();
        
        // Transfer away some tokens so partner doesn't have enough
        vm.prank(partner1);
        roboshareTokens.safeTransferFrom(partner1, partner2, revenueShareTokenId, 600, "");
        
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        
        vm.expectRevert("Marketplace__InsufficientTokenBalance");
        marketplace.lockCollateralAndList(
            vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS, TOKENS_TO_LIST, LISTING_DURATION, true
        );
        vm.stopPrank();
    }

    // Create Listing Tests

    function testCreateListingRequiresCollateral() public {
        (, uint256 revenueShareTokenId) = _setupVehicleAndTokens();
        
        vm.expectRevert("Marketplace__CollateralNotLocked");
        vm.prank(partner1);
        marketplace.createListing(revenueShareTokenId, TOKENS_TO_LIST, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
    }

    function testCreateListingInvalidTokenType() public {
        // Try to list vehicle NFT (odd token ID) instead of revenue share token (even)
        vm.expectRevert("Marketplace__InvalidTokenType");
        vm.prank(partner1);
        marketplace.createListing(1, 1, REVENUE_TOKEN_PRICE, LISTING_DURATION, true); // Vehicle NFT token ID
    }

    // Purchase Listing Tests

    function testPurchaseListingBuyerPaysFee() public {
        (, uint256 revenueShareTokenId, uint256 listingId) = _approveAndLockCollateralAndList();
        
        uint256 purchaseAmount = 100;
        uint256 totalPrice = purchaseAmount * REVENUE_TOKEN_PRICE;
        uint256 protocolFee = ProtocolLib.calculateProtocolFee(totalPrice);
        uint256 expectedPayment = totalPrice + protocolFee; // Buyer pays fee
        
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        
        uint256 buyerTokenBalanceBefore = roboshareTokens.balanceOf(buyer, revenueShareTokenId);
        uint256 sellerUsdcBalanceBefore = usdc.balanceOf(partner1);
        uint256 treasuryUsdcBalanceBefore = usdc.balanceOf(config.treasuryFeeRecipient);
        
        // Expect RevenueTokensTraded event
        vm.expectEmit(true, true, true, true, address(marketplace));
        
        marketplace.purchaseListing(listingId, purchaseAmount);
        vm.stopPrank();

        // Verify tokens transferred
        assertEq(roboshareTokens.balanceOf(buyer, revenueShareTokenId), buyerTokenBalanceBefore + purchaseAmount);
        
        // Verify USDC payments
        assertEq(usdc.balanceOf(partner1), sellerUsdcBalanceBefore + totalPrice); // Seller gets full price
        assertEq(usdc.balanceOf(config.treasuryFeeRecipient), treasuryUsdcBalanceBefore + protocolFee); // Treasury gets fee
        
        // Verify listing updated
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.amount, TOKENS_TO_LIST - purchaseAmount);
        assertTrue(listing.isActive); // Still active since not fully purchased
    }

    function testPurchaseListingSellerPaysFee() public {
        (uint256 vehicleId,) = _setupVehicleAndTokens();
        
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        // Create listing with seller paying fee
        uint256 listingId = marketplace.lockCollateralAndList(
            vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS, TOKENS_TO_LIST, LISTING_DURATION, false
        );
        vm.stopPrank();
        
        uint256 purchaseAmount = 100;
        uint256 totalPrice = purchaseAmount * REVENUE_TOKEN_PRICE;
        uint256 protocolFee = ProtocolLib.calculateProtocolFee(totalPrice);
        uint256 expectedPayment = totalPrice; // Buyer pays just the price
        uint256 sellerReceives = totalPrice - protocolFee; // Seller absorbs fee
        
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        
        uint256 sellerUsdcBalanceBefore = usdc.balanceOf(partner1);
        uint256 treasuryUsdcBalanceBefore = usdc.balanceOf(config.treasuryFeeRecipient);
        
        marketplace.purchaseListing(listingId, purchaseAmount);
        vm.stopPrank();

        // Verify USDC payments
        assertEq(usdc.balanceOf(partner1), sellerUsdcBalanceBefore + sellerReceives); // Seller gets price minus fee
        assertEq(usdc.balanceOf(config.treasuryFeeRecipient), treasuryUsdcBalanceBefore + protocolFee); // Treasury gets fee
    }

    function testPurchaseListingCompletelyExhaustsListing() public {
        (, uint256 revenueShareTokenId, uint256 listingId) = _approveAndLockCollateralAndList();
        
        uint256 totalPrice = TOKENS_TO_LIST * REVENUE_TOKEN_PRICE;
        uint256 protocolFee = ProtocolLib.calculateProtocolFee(totalPrice);
        
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), totalPrice + protocolFee);
        marketplace.purchaseListing(listingId, TOKENS_TO_LIST); // Buy all tokens
        vm.stopPrank();

        // Verify listing is inactive
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.amount, 0);
        assertFalse(listing.isActive);
        
        // Verify all tokens transferred
        assertEq(roboshareTokens.balanceOf(buyer, revenueShareTokenId), TOKENS_TO_LIST);
        assertEq(roboshareTokens.balanceOf(address(marketplace), revenueShareTokenId), 0);
    }

    function testPurchaseListingInsufficientPayment() public {
        (, , uint256 listingId) = _approveAndLockCollateralAndList();
        
        uint256 purchaseAmount = 100;
        uint256 insufficientPayment = 50 * 10 ** 6; // Way too low
        
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), insufficientPayment);
        
        vm.expectRevert("Marketplace__InsufficientPayment");
        marketplace.purchaseListing(listingId, purchaseAmount);
        vm.stopPrank();
    }

    function testPurchaseListingExpired() public {
        (, , uint256 listingId) = _approveAndLockCollateralAndList();
        
        // Fast forward past expiration
        vm.warp(block.timestamp + LISTING_DURATION + 1);
        
        vm.expectRevert("Marketplace__ListingExpired");
        vm.prank(buyer);
        marketplace.purchaseListing(listingId, 100);
    }

    function testPurchaseListingInvalidAmount() public {
        (, , uint256 listingId) = _approveAndLockCollateralAndList();
        
        vm.expectRevert("Marketplace__InvalidAmount");
        vm.prank(buyer);
        marketplace.purchaseListing(listingId, TOKENS_TO_LIST + 1); // More than available
    }

    // Cancel Listing Tests

    function testCancelListingSuccess() public {
        (, uint256 revenueShareTokenId, uint256 listingId) = _approveAndLockCollateralAndList();
        
        uint256 partnerBalanceBefore = roboshareTokens.balanceOf(partner1, revenueShareTokenId);
        
        vm.prank(partner1);
        marketplace.cancelListing(listingId);
        
        // Verify listing cancelled
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertFalse(listing.isActive);
        
        // Verify tokens returned
        assertEq(roboshareTokens.balanceOf(partner1, revenueShareTokenId), partnerBalanceBefore + TOKENS_TO_LIST);
        assertEq(roboshareTokens.balanceOf(address(marketplace), revenueShareTokenId), 0);
    }

    function testCancelListingUnauthorized() public {
        (, , uint256 listingId) = _approveAndLockCollateralAndList();
        
        vm.expectRevert("Marketplace__NotTokenOwner");
        vm.prank(unauthorized);
        marketplace.cancelListing(listingId);
    }

    // View Function Tests

    function testGetVehicleListings() public {
        (uint256 vehicleId, , uint256 listingId) = _approveAndLockCollateralAndList();
        
        uint256[] memory activeListings = marketplace.getVehicleListings(vehicleId);
        assertEq(activeListings.length, 1);
        assertEq(activeListings[0], listingId);
    }

    function testCalculatePurchaseCost() public {
        (, , uint256 listingId) = _approveAndLockCollateralAndList();
        
        uint256 purchaseAmount = 100;
        (uint256 totalCost, uint256 protocolFee, uint256 expectedPayment) = marketplace.calculatePurchaseCost(listingId, purchaseAmount);
        
        assertEq(totalCost, purchaseAmount * REVENUE_TOKEN_PRICE);
        assertEq(protocolFee, ProtocolLib.calculateProtocolFee(totalCost));
        assertEq(expectedPayment, totalCost + protocolFee); // Buyer pays fee in this test
    }

    function testIsVehicleEligibleForListing() public {
        (uint256 vehicleId, ) = _setupVehicleAndTokens();
        
        // Initially not eligible (no collateral locked)
        assertFalse(marketplace.isVehicleEligibleForListing(vehicleId));
        
        // Lock collateral
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();
        
        // Now eligible
        assertTrue(marketplace.isVehicleEligibleForListing(vehicleId));
    }

    // Admin Function Tests

    function testSetTreasuryAddress() public {
        address newTreasury = makeAddr("newTreasury");
        
        vm.prank(admin);
        marketplace.setTreasuryAddress(newTreasury);
        
        assertEq(marketplace.treasuryAddress(), newTreasury);
    }

    function testSetTreasuryAddressUnauthorized() public {
        address newTreasury = makeAddr("newTreasury");
        
        vm.expectRevert();
        vm.prank(unauthorized);
        marketplace.setTreasuryAddress(newTreasury);
    }

    function testSetTreasuryAddressZeroAddress() public {
        vm.expectRevert("Marketplace__ZeroAddress");
        vm.prank(admin);
        marketplace.setTreasuryAddress(address(0));
    }
}