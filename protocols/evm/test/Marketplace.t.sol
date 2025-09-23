// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";

contract MarketplaceTest is BaseTest {

    function setUp() public {
        _ensureState(SetupState.ContractsDeployed);
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
        
        vm.expectRevert(Marketplace__ZeroAddress.selector);
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
        _ensureState(SetupState.RevenueTokensMinted);
        
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        
        // Expect CollateralLockedAndListed event
        uint256 expectedListingId = 1;
        uint256 expectedCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        
        vm.expectEmit(true, true, true, true, address(marketplace));
        emit Marketplace.CollateralLockedAndListed(
            vehicleId,
            revenueShareTokenId,
            expectedListingId,
            partner1,
            expectedCollateral,
            TOKENS_TO_LIST,
            REVENUE_TOKEN_PRICE,
            true
        );
        
        uint256 newListingId = marketplace.lockCollateralAndList(
            vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS, TOKENS_TO_LIST, LISTING_DURATION, true
        );
        vm.stopPrank();

        // Verify listing created
        assertEq(newListingId, 1);
        
        Marketplace.Listing memory listing = marketplace.getListing(newListingId);
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
        (, , bool isLocked, ,) = treasury.getAssetCollateralInfo(vehicleId);
        assertTrue(isLocked);
    }

    function testLockCollateralAndListUnauthorizedPartner() public {
        _ensureState(SetupState.VehicleRegistered);
        
        vm.expectRevert(PartnerManager.PartnerManager__NotAuthorized.selector);
        vm.prank(unauthorized);
        marketplace.lockCollateralAndList(
            vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS, TOKENS_TO_LIST, LISTING_DURATION, true
        );
    }

    function testLockCollateralAndListInvalidAmount() public {
        _ensureState(SetupState.RevenueTokensMinted);
        
        vm.expectRevert(Marketplace__InvalidAmount.selector);
        vm.prank(partner1);
        marketplace.lockCollateralAndList(
            vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS, TOTAL_REVENUE_TOKENS + 1, LISTING_DURATION, true
        );
    }

    function testLockCollateralAndListInsufficientTokenBalance() public {
        _ensureState(SetupState.RevenueTokensMinted);
        
        // Transfer away some tokens so partner doesn't have enough
        vm.prank(partner1);
        roboshareTokens.safeTransferFrom(partner1, partner2, revenueShareTokenId, 600, "");
        
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        
        vm.expectRevert(Marketplace__InsufficientTokenBalance.selector);
        marketplace.lockCollateralAndList(
            vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS, TOKENS_TO_LIST, LISTING_DURATION, true
        );
        vm.stopPrank();
    }

    // Create Listing Tests

    function testCreateListingRequiresCollateral() public {
        _ensureState(SetupState.RevenueTokensMinted);
        
        vm.expectRevert(Marketplace__CollateralNotLocked.selector);
        vm.prank(partner1);
        marketplace.createListing(revenueShareTokenId, TOKENS_TO_LIST, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
    }

    function testCreateListingInvalidTokenType() public {
        _ensureState(SetupState.VehicleRegistered);
        // Try to list vehicle NFT (odd token ID) instead of revenue share token (even)
        vm.expectRevert(Marketplace__InvalidTokenType.selector);
        vm.prank(partner1);
        marketplace.createListing(1, 1, REVENUE_TOKEN_PRICE, LISTING_DURATION, true); // Vehicle NFT token ID
    }

    // Purchase Listing Tests

    function testPurchaseListingBuyerPaysFee() public {
        _ensureState(SetupState.CollateralLockedAndListed);
        
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
        emit Marketplace.RevenueTokensTraded(
            revenueShareTokenId,
            partner1,
            buyer,
            purchaseAmount,
            listingId,
            totalPrice
        );
        
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
        _ensureState(SetupState.RevenueTokensMinted);
        
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        // Create listing with seller paying fee
        uint256 newListingId = marketplace.lockCollateralAndList(
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
        
        marketplace.purchaseListing(newListingId, purchaseAmount);
        vm.stopPrank();

        // Verify USDC payments
        assertEq(usdc.balanceOf(partner1), sellerUsdcBalanceBefore + sellerReceives); // Seller gets price minus fee
        assertEq(usdc.balanceOf(config.treasuryFeeRecipient), treasuryUsdcBalanceBefore + protocolFee); // Treasury gets fee
    }

    function testPurchaseListingCompletelyExhaustsListing() public {
        _ensureState(SetupState.CollateralLockedAndListed);
        
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
        _ensureState(SetupState.CollateralLockedAndListed);
        
        uint256 purchaseAmount = 100;
        uint256 totalPrice = purchaseAmount * REVENUE_TOKEN_PRICE;
        uint256 protocolFee = ProtocolLib.calculateProtocolFee(totalPrice);
        uint256 requiredPayment = totalPrice + protocolFee; // Buyer pays fee (listing created with buyerPaysFee=true)
        
        // Create a new buyer with insufficient funds
        address poorBuyer = makeAddr("poorBuyer");
        uint256 insufficientAmount = requiredPayment / 2; // Half of what's needed
        usdc.mint(poorBuyer, insufficientAmount);
        
        vm.startPrank(poorBuyer);
        usdc.approve(address(marketplace), requiredPayment); // Approve enough, but balance is insufficient
        
        vm.expectRevert(Marketplace__InsufficientPayment.selector);
        marketplace.purchaseListing(listingId, purchaseAmount);
        vm.stopPrank();
    }

    function testPurchaseListingExpired() public {
        _ensureState(SetupState.CollateralLockedAndListed);
        
        // Fast forward past expiration
        vm.warp(block.timestamp + LISTING_DURATION + 1);
        
        vm.expectRevert(Marketplace__ListingExpired.selector);
        vm.prank(buyer);
        marketplace.purchaseListing(listingId, 100);
    }

    function testPurchaseListingInvalidAmount() public {
        _ensureState(SetupState.CollateralLockedAndListed);
        
        vm.expectRevert(Marketplace__InvalidAmount.selector);
        vm.prank(buyer);
        marketplace.purchaseListing(listingId, TOKENS_TO_LIST + 1); // More than available
    }

    // Cancel Listing Tests

    function testCancelListingSuccess() public {
        _ensureState(SetupState.CollateralLockedAndListed);
        
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
        _ensureState(SetupState.CollateralLockedAndListed);
        
        vm.expectRevert(Marketplace__NotTokenOwner.selector);
        vm.prank(unauthorized);
        marketplace.cancelListing(listingId);
    }

    // View Function Tests

    function testGetVehicleListings() public {
        _ensureState(SetupState.CollateralLockedAndListed);
        
        uint256[] memory activeListings = marketplace.getVehicleListings(vehicleId);
        assertEq(activeListings.length, 1);
        assertEq(activeListings[0], listingId);
    }

    function testCalculatePurchaseCost() public {
        _ensureState(SetupState.CollateralLockedAndListed);
        
        uint256 purchaseAmount = 100;
        (uint256 totalCost, uint256 protocolFee, uint256 expectedPayment) = marketplace.calculatePurchaseCost(listingId, purchaseAmount);
        
        assertEq(totalCost, purchaseAmount * REVENUE_TOKEN_PRICE);
        assertEq(protocolFee, ProtocolLib.calculateProtocolFee(totalCost));
        assertEq(expectedPayment, totalCost + protocolFee); // Buyer pays fee in this test
    }

    function testIsVehicleEligibleForListing() public {
        _ensureState(SetupState.RevenueTokensMinted);
        
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
        vm.expectRevert(Marketplace__ZeroAddress.selector);
        vm.prank(admin);
        marketplace.setTreasuryAddress(address(0));
    }

    // Fuzz Tests
    function testFuzzPurchaseListing(uint256 purchaseAmount) public {
        _ensureState(SetupState.CollateralLockedAndListed);

        vm.assume(purchaseAmount > 0 && purchaseAmount <= TOKENS_TO_LIST);

        uint256 totalPrice = purchaseAmount * REVENUE_TOKEN_PRICE;
        uint256 protocolFee = ProtocolLib.calculateProtocolFee(totalPrice);
        uint256 expectedPayment = totalPrice + protocolFee;

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseListing(listingId, purchaseAmount);
        vm.stopPrank();

        assertEq(roboshareTokens.balanceOf(buyer, revenueShareTokenId), purchaseAmount);
    }
}