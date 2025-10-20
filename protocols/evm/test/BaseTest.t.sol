// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../contracts/Marketplace.sol";
import "../contracts/VehicleRegistry.sol";
import "../contracts/RoboshareTokens.sol";
import "../contracts/PartnerManager.sol";
import "../contracts/Treasury.sol";
import "../contracts/Libraries.sol";
import { DeployForTest } from "../script/DeployForTest.s.sol";

contract BaseTest is Test {
    enum SetupState {
        None,
        ContractsDeployed,
        PartnersAuthorized,
        AccountsFunded,
        VehicleWithTokens,
        VehicleWithListing,
        VehicleWithPurchase,
        VehicleWithEarnings,
        VehicleWithPartialCollateral,
        VehicleWithCollateral
    }

    SetupState private currentState;

    DeployForTest public deployer;
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
    IERC20 public usdc;

    DeployForTest.NetworkConfig public config;

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
    string constant TEST_METADATA_URI = "ipfs://QmYwAPJzv5CZsnA625b3Xm2fa12p45a8V34vG27s2p45a8";

    string constant PARTNER1_NAME = "RideShare Fleet Co.";
    string constant PARTNER2_NAME = "Urban Delivery Services";

    // Test marketplace parameters
    uint256 constant REVENUE_TOKEN_PRICE = 100 * 10 ** 6; // $100 USDC
    uint256 constant REVENUE_TOKEN_SUPPLY = 1000;
    uint256 constant PURCHASE_AMOUNT = 500;
    uint256 constant LISTING_DURATION = 30 days;

    // Storage for test scenario states
    struct TestScenario {
        uint256 vehicleId;
        uint256 revenueTokenId;
        uint256 listingId;
        uint256 requiredCollateral;
        uint256 earnings;
        uint256 initialProtocolBalance;
    }

    TestScenario public scenario;

    function _ensureState(SetupState requiredState) internal {
        if (currentState >= requiredState) {
            return;
        }

        if (currentState < SetupState.ContractsDeployed) {
            _deployContracts();
            currentState = SetupState.ContractsDeployed;
        }

        if (requiredState >= SetupState.PartnersAuthorized && currentState < SetupState.PartnersAuthorized) {
            _setupInitialRolesAndPartners();
            currentState = SetupState.PartnersAuthorized;
        }

        if (requiredState >= SetupState.AccountsFunded && currentState < SetupState.AccountsFunded) {
            _fundInitialAccounts();
            currentState = SetupState.AccountsFunded;
        }

        if (requiredState >= SetupState.VehicleWithTokens && currentState < SetupState.VehicleWithTokens) {
            (scenario.vehicleId, scenario.revenueTokenId) = _setupVehicleWithTokens();
            currentState = SetupState.VehicleWithTokens;
        }

        // if (requiredState == SetupState.CollateralLocked && currentState < SetupState.CollateralLocked) {
        //     // Approve marketplace to transfer tokens on behalf of partner1
        //     vm.prank(partner1);
        //     roboshareTokens.setApprovalForAll(address(marketplace), true);

        //     // Calculate required collateral
        //     scenario.requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        //     vm.startPrank(partner1);
        //     // Approve USDC for collateral
        //     usdc.approve(address(treasury), scenario.requiredCollateral);
        //     // Lock collateral
        //     treasury.lockCollateral(scenario.vehicleId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        //     vm.stopPrank();
        //     currentState = SetupState.CollateralLocked;
        // }

        if (requiredState >= SetupState.VehicleWithListing && currentState < SetupState.VehicleWithListing) {
            // Approve marketplace to transfer tokens on behalf of partner1
            vm.prank(partner1);
            roboshareTokens.setApprovalForAll(address(marketplace), true);

            // Calculate required collateral
            scenario.requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

            vm.startPrank(partner1);
            // Approve USDC for collateral
            usdc.approve(address(treasury), scenario.requiredCollateral);
            // Lock collateral and list tokens
            scenario.listingId = marketplace.lockCollateralAndList(
                scenario.vehicleId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY, PURCHASE_AMOUNT, LISTING_DURATION, true
            );
            vm.stopPrank();
            currentState = SetupState.VehicleWithListing;
        }

        if (requiredState >= SetupState.VehicleWithPurchase && currentState < SetupState.VehicleWithPurchase) {
            // Buyer approves USDC for purchase
            (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(scenario.listingId, PURCHASE_AMOUNT);
            vm.startPrank(buyer);
            usdc.approve(address(marketplace), expectedPayment);

            // Buyer purchases tokens
            marketplace.purchaseTokens(scenario.listingId, PURCHASE_AMOUNT);
            vm.stopPrank();
            currentState = SetupState.VehicleWithPurchase;
        }
    }

    function _deployContracts() internal {
        deployer = new DeployForTest();
        (marketplace, vehicleRegistry, roboshareTokens, partnerManager, treasury, marketplaceImplementation, vehicleImplementation, tokenImplementation, partnerImplementation, treasuryImplementation) = deployer.run(admin);

        config = deployer.getActiveNetworkConfig();
        usdc = IERC20(config.usdcToken);
    }

    function _setupInitialRolesAndPartners() internal {
        // Setup roles and permissions
        vm.startPrank(admin);
        // Grant MINTER_ROLE and BURNER_ROLE to VehicleRegistry for token operations
        roboshareTokens.grantRole(roboshareTokens.MINTER_ROLE(), address(vehicleRegistry));
        roboshareTokens.grantRole(roboshareTokens.BURNER_ROLE(), address(vehicleRegistry));
        // Grant AUTHORIZED_CONTRACT_ROLE to Marketplace for Treasury operations
        treasury.grantRole(treasury.AUTHORIZED_CONTRACT_ROLE(), address(marketplace));
        // Authorize partners
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);
        partnerManager.authorizePartner(partner2, PARTNER2_NAME);
        vm.stopPrank();
    }

    function _fundInitialAccounts() private {
        // Fund accounts with USDC for testing
        if (deployer.isLocalNetwork()) {
            ERC20Mock mockUSDC = ERC20Mock(address(usdc));
            mockUSDC.mint(partner1, 1000000 * 10 ** 6); // 1M USDC
            mockUSDC.mint(partner2, 1000000 * 10 ** 6); // 1M USDC
            mockUSDC.mint(buyer, 1000000 * 10 ** 6); // 1M USDC
        } else {
            deal(address(usdc), partner1, 1000000 * 10 ** 6); // 1M USDC
            deal(address(usdc), partner2, 1000000 * 10 ** 6); // 1M USDC
            deal(address(usdc), buyer, 1000000 * 10 ** 6); // 1M USDC
        }
    }

    function _setupVehicleWithTokens() internal returns (uint256 vehicleId, uint256 revenueTokenId) {
        vm.prank(partner1);
        (vehicleId, revenueTokenId) = vehicleRegistry.registerVehicleAndMintRevenueTokens(
            TEST_VIN,
            TEST_MAKE,
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            TEST_METADATA_URI,
            REVENUE_TOKEN_SUPPLY
        );
    }

    // ========================================
    // ASSERTION HELPERS
    // ========================================

    /**
     * @dev Assert listing state matches expected values
     */
    function assertListingState(
        uint256 _listingId,
        uint256 expectedTokenId,
        uint256 expectedAmount,
        uint256 expectedPrice,
        address expectedSeller,
        bool expectedActive,
        bool expectedBuyerPaysFee
    ) internal view {
        Marketplace.Listing memory listing = marketplace.getListing(_listingId);
        assertEq(listing.tokenId, expectedTokenId, "Listing token ID mismatch");
        assertEq(listing.amount, expectedAmount, "Listing amount mismatch");
        assertEq(listing.pricePerToken, expectedPrice, "Listing price mismatch");
        assertEq(listing.seller, expectedSeller, "Listing seller mismatch");
        assertEq(listing.isActive, expectedActive, "Listing active state mismatch");
        assertEq(listing.buyerPaysFee, expectedBuyerPaysFee, "Listing fee payer mismatch");
    }

    /**
     * @dev Assert collateral state for a vehicle
     */
    function assertCollateralState(uint256 _vehicleId, uint256 expectedBase, uint256 expectedTotal, bool expectedLocked)
        internal
        view
    {
        (uint256 base, uint256 total, bool locked,,) = treasury.getAssetCollateralInfo(_vehicleId);
        assertEq(base, expectedBase, "Base collateral mismatch");
        assertEq(total, expectedTotal, "Total collateral mismatch");
        assertEq(locked, expectedLocked, "Collateral locked state mismatch");
    }

    /**
     * @dev Assert token balances for an address
     */
    function assertTokenBalance(address account, uint256 tokenId, uint256 expectedBalance, string memory message)
        internal
        view
    {
        uint256 actualBalance = roboshareTokens.balanceOf(account, tokenId);
        assertEq(actualBalance, expectedBalance, message);
    }

    /**
     * @dev Assert USDC balance for an address
     */
    function assertUSDCBalance(address account, uint256 expectedBalance, string memory message) internal view {
        uint256 actualBalance = usdc.balanceOf(account);
        assertEq(actualBalance, expectedBalance, message);
    }

    /**
     * @dev Assert vehicle registration state
     */
    function assertVehicleState(uint256 _vehicleId, address expectedOwner, string memory expectedVin, bool shouldExist)
        internal
        view
    {
        if (shouldExist) {
            // Check ownership via ERC1155 balance
            assertEq(roboshareTokens.balanceOf(expectedOwner, _vehicleId), 1, "Vehicle owner mismatch");

            // Check vehicle info stored in the registry
            (string memory vin,,,,,,) = vehicleRegistry.getVehicleInfo(_vehicleId);
            assertEq(vin, expectedVin, "Vehicle VIN mismatch");

            // Also check the exists function
            assertTrue(vehicleRegistry.vehicleExists(_vehicleId), "vehicleExists should be true");
        } else {
            // Check that the NFT is not owned
            assertEq(roboshareTokens.balanceOf(expectedOwner, _vehicleId), 0, "Vehicle should not be owned");
            // Check that the registry reports it as not existing
            assertFalse(vehicleRegistry.vehicleExists(_vehicleId), "vehicleExists should be false");
        }
    }

    // ========================================
    // TEST DATA GENERATORS
    // ========================================

    /**
     * @dev Generate random VIN for testing
     */
    function generateVIN(uint256 seed) internal pure returns (string memory) {
        string[10] memory vinPrefixes = [
            "1HGCM82633A",
            "2FMDK3GC1D",
            "3FA6P0H75H",
            "4T1BF1FK6G",
            "5NPE24AF3F",
            "6G2VX12G0L",
            "1N4AL3AP0G",
            "2T1BURHE3H",
            "3C4PDCAB0F",
            "4F4YR16U8V"
        ];

        uint256 prefixIndex = seed % 10;
        uint256 suffix = (seed % 900000) + 100000; // 6 digit suffix
        return string(abi.encodePacked(vinPrefixes[prefixIndex], vm.toString(suffix)));
    }

    /**
     * @dev Generate test vehicle data
     */
    function generateVehicleData(uint256 seed)
        internal
        pure
        returns (
            string memory vin,
            string memory make,
            string memory model,
            uint256 year,
            uint256 manufacturerId,
            string memory optionCodes,
            string memory metadataURI
        )
    {
        string[5] memory makes = ["Toyota", "Honda", "Ford", "BMW", "Tesla"];
        string[5] memory models = ["Camry", "Civic", "F-150", "X3", "Model 3"];

        vin = generateVIN(seed);
        make = makes[seed % 5];
        model = models[(seed + 1) % 5];
        year = 2020 + (seed % 5); // 2020-2024
        manufacturerId = (seed % 100) + 1;
        optionCodes = "TEST,OPTION";
        // Use a valid-length IPFS URI (prefix + 46-char CID)
        metadataURI = "ipfs://QmYwAPJzv5CZsnAzt8auVTLpG1bG6dkprdFM5ocTyBCQb";
    }

    /**
     * @dev Generate realistic test addresses
     */
    function generateTestAddresses(uint256 count) internal returns (address[] memory addresses) {
        addresses = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            addresses[i] = makeAddr(string(abi.encodePacked("testAddr", vm.toString(i))));
        }
        return addresses;
    }

    // ========================================
    // TIME MANIPULATION HELPERS
    // ========================================

    /**
     * @dev Warp to listing expiry time
     */
    function warpToListingExpiry(uint256 _listingId) internal {
        Marketplace.Listing memory listing = marketplace.getListing(_listingId);
        vm.warp(listing.expiresAt + 1);
    }

    /**
     * @dev Warp past holding period for penalty-free transfers
     */
    function warpPastHoldingPeriod() internal {
        vm.warp(block.timestamp + 30 days + 1); // Monthly interval + 1
    }

    /**
     * @dev Warp to specific time offset
     */
    function warpToTimeOffset(uint256 offsetSeconds) internal {
        vm.warp(block.timestamp + offsetSeconds);
    }

    /**
     * @dev Save current timestamp and warp, returning original time
     */
    function warpAndSaveTime(uint256 newTime) internal returns (uint256 originalTime) {
        originalTime = block.timestamp;
        vm.warp(newTime);
        return originalTime;
    }

    // ========================================
    // BALANCE TRACKING HELPERS
    // ========================================

    struct BalanceSnapshot {
        uint256 partnerUsdc;
        uint256 buyerUsdc;
        uint256 treasuryUsdc;
        uint256 partnerTokens;
        uint256 buyerTokens;
        uint256 marketplaceTokens;
        uint256 timestamp;
    }

    /**
     * @dev Take a snapshot of all relevant balances
     */
    function takeBalanceSnapshot(uint256 tokenId) internal view returns (BalanceSnapshot memory snapshot) {
        snapshot.partnerUsdc = usdc.balanceOf(partner1);
        snapshot.buyerUsdc = usdc.balanceOf(buyer);
        snapshot.treasuryUsdc = usdc.balanceOf(config.treasuryFeeRecipient);
        snapshot.partnerTokens = roboshareTokens.balanceOf(partner1, tokenId);
        snapshot.buyerTokens = roboshareTokens.balanceOf(buyer, tokenId);
        snapshot.marketplaceTokens = roboshareTokens.balanceOf(address(marketplace), tokenId);
        snapshot.timestamp = block.timestamp;
    }

    /**
     * @dev Compare two balance snapshots and assert expected changes
     */
    function assertBalanceChanges(
        BalanceSnapshot memory before,
        BalanceSnapshot memory afterSnapshot,
        int256 expectedPartnerUsdcChange,
        int256 expectedBuyerUsdcChange,
        int256 expectedTreasuryUsdcChange,
        int256 expectedPartnerTokenChange,
        int256 expectedBuyerTokenChange
    ) internal pure {
        assertEq(
            int256(afterSnapshot.partnerUsdc) - int256(before.partnerUsdc),
            expectedPartnerUsdcChange,
            "Partner USDC change mismatch"
        );
        assertEq(
            int256(afterSnapshot.buyerUsdc) - int256(before.buyerUsdc),
            expectedBuyerUsdcChange,
            "Buyer USDC change mismatch"
        );
        assertEq(
            int256(afterSnapshot.treasuryUsdc) - int256(before.treasuryUsdc),
            expectedTreasuryUsdcChange,
            "Treasury USDC change mismatch"
        );
        assertEq(
            int256(afterSnapshot.partnerTokens) - int256(before.partnerTokens),
            expectedPartnerTokenChange,
            "Partner token change mismatch"
        );
        assertEq(
            int256(afterSnapshot.buyerTokens) - int256(before.buyerTokens),
            expectedBuyerTokenChange,
            "Buyer token change mismatch"
        );
    }

    // ========================================
    // EVENT VERIFICATION HELPERS
    // ========================================

    /**
     * @dev Expect CollateralLockedAndListed event with specific parameters
     */
    function expectCollateralLockedAndListedEvent(
        uint256 _vehicleId,
        uint256 _revenueTokenId,
        uint256 _listingId,
        address partner,
        uint256 collateral,
        uint256 tokensToList,
        uint256 pricePerToken,
        bool buyerPaysFee
    ) internal {
        vm.expectEmit(true, true, true, true, address(marketplace));
        emit Marketplace.CollateralLockedAndListed(
            _vehicleId, _revenueTokenId, _listingId, partner, collateral, tokensToList, pricePerToken, buyerPaysFee
        );
    }

    /**
     * @dev Expect RevenueTokensTraded event with specific parameters
     */
    function expectRevenueTokensTradedEvent(
        uint256 _revenueTokenId,
        address from,
        address to,
        uint256 amount,
        uint256 _listingId,
        uint256 totalPrice
    ) internal {
        vm.expectEmit(true, true, true, true, address(marketplace));
        emit Marketplace.RevenueTokensTraded(_revenueTokenId, from, to, amount, _listingId, totalPrice);
    }

    // ========================================
    // ERROR CONDITION HELPERS
    // ========================================

    /**
     * @dev Set up insufficient funds scenario for address
     */
    function setupInsufficientFunds(address account, uint256 neededAmount) internal {
        uint256 currentBalance = usdc.balanceOf(account);
        if (currentBalance >= neededAmount / 2) {
            // Transfer away most funds, keeping less than half needed
            vm.prank(account);
            usdc.transfer(makeAddr("drain"), currentBalance - (neededAmount / 3));
        }
    }

    /**
     * @dev Set up expired listing scenario
     */
    function setupExpiredListing(uint256 _listingId) internal {
        warpToListingExpiry(_listingId);
    }

    // ========================================
    // CALCULATION HELPERS
    // ========================================

    /**
     * @dev Calculate expected protocol fee
     */
    function calculateExpectedProtocolFee(uint256 amount) internal pure returns (uint256) {
        return ProtocolLib.calculateProtocolFee(amount);
    }

    /**
     * @dev Calculate expected collateral requirement
     */
    function calculateExpectedCollateral(uint256 revenueTokenPrice, uint256 totalTokens)
        internal
        pure
        returns (uint256 base, uint256 earningsBuffer, uint256 protocolBuffer, uint256 total)
    {
        base = revenueTokenPrice * totalTokens;
        uint256 expectedQuarterlyEarnings = (base * 90 days) / 365 days;
        earningsBuffer = (expectedQuarterlyEarnings * 1000) / 10000; // 10%
        protocolBuffer = (expectedQuarterlyEarnings * 500) / 10000; // 5%
        total = base + earningsBuffer + protocolBuffer;
    }

    /**
     * @dev Calculate expected purchase cost breakdown
     */
    function calculatePurchaseCost(uint256 _listingId, uint256 amount)
        internal
        view
        returns (uint256 totalCost, uint256 protocolFee, uint256 expectedPayment)
    {
        return marketplace.calculatePurchaseCost(_listingId, amount);
    }

    /**
     * @dev Calculate expected earnings for a given period
     */
    function calculateExpectedEarnings(uint256 principal, uint256 timeElapsed, uint256 earningsRateBP)
        internal
        pure
        returns (uint256)
    {
        return (principal * earningsRateBP * timeElapsed) / (10000 * 365 days);
    }

    // ========================================
    // MOCK SETUP HELPERS
    // ========================================

    /**
     * @dev Create a test listing with custom parameters
     */
    function createTestListing(
        address partner,
        uint256 tokenPrice,
        uint256 totalTokens,
        uint256 tokensToList,
        uint256 duration,
        bool buyerPaysFee
    ) internal returns (uint256, uint256, uint256) {
        // Generate unique test data
        uint256 seed = uint256(keccak256(abi.encodePacked(partner, tokenPrice, block.timestamp)));
        (
            string memory vin,
            string memory make,
            string memory model,
            uint256 year,
            uint256 manufacturerId,
            string memory optionCodes,
            string memory metadataURI
        ) = generateVehicleData(seed);

        vm.startPrank(partner);

        // Register vehicle
        scenario.vehicleId =
            vehicleRegistry.registerVehicle(vin, make, model, year, manufacturerId, optionCodes, metadataURI);

        // Mint revenue tokens
        scenario.revenueTokenId = vehicleRegistry.mintRevenueTokens(scenario.vehicleId, totalTokens);

        // Lock collateral and create listing
        uint256 requiredCollateral = treasury.getCollateralRequirement(tokenPrice, totalTokens);
        usdc.approve(address(treasury), requiredCollateral);
        roboshareTokens.setApprovalForAll(address(marketplace), true);

        scenario.listingId = marketplace.lockCollateralAndList(
            scenario.vehicleId, tokenPrice, totalTokens, tokensToList, duration, buyerPaysFee
        );

        vm.stopPrank();

        return (scenario.vehicleId, scenario.revenueTokenId, scenario.listingId);
    }

    /**
     * @dev Setup earnings distribution scenario
     */
    function setupEarningsScenario(uint256 _vehicleId, uint256 earningsAmount) internal {
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        treasury.distributeEarnings(_vehicleId, earningsAmount);
        vm.stopPrank();
    }

    /**
     * @dev Create multiple test vehicles for a partner
     */
    function createMultipleTestVehicles(address partner, uint256 count)
        internal
        returns (uint256[] memory vehicleIds)
    {
        vehicleIds = new uint256[](count);

        vm.startPrank(partner);
        for (uint256 i = 0; i < count; i++) {
            (
                string memory vin,
                string memory make,
                string memory model,
                uint256 year,
                uint256 manufacturerId,
                string memory optionCodes,
                string memory metadataURI
            ) = generateVehicleData(i + uint256(keccak256(abi.encodePacked(partner, block.timestamp))));

            vehicleIds[i] =
                vehicleRegistry.registerVehicle(vin, make, model, year, manufacturerId, optionCodes, metadataURI);
        }
        vm.stopPrank();

        return vehicleIds;
    }

    /**
     * @dev Setup multiple partners with authorization
     */
    function setupMultiplePartners(uint256 count) internal returns (address[] memory partners) {
        partners = new address[](count);

        vm.startPrank(admin);
        for (uint256 i = 0; i < count; i++) {
            partners[i] = makeAddr(string(abi.encodePacked("partner", vm.toString(i))));
            partnerManager.authorizePartner(partners[i], string(abi.encodePacked("Partner ", vm.toString(i))));

            // Fund partners if on local network
            if (deployer.isLocalNetwork()) {
                ERC20Mock(address(usdc)).mint(partners[i], 1000000 * 10 ** 6); // 1M USDC
            }
        }
        vm.stopPrank();

        return partners;
    }

    // ========================================
    // UTILITY FUNCTIONS
    // ========================================

    /**
     * @dev Fund an address with USDC (local network only)
     */
    function fundAddressWithUSDC(address account, uint256 amount) internal {
        if (deployer.isLocalNetwork()) {
            ERC20Mock(address(usdc)).mint(account, amount);
        }
    }

    /**
     * @dev Check if address is authorized partner
     */
    function isAuthorizedPartner(address account) internal view returns (bool) {
        return partnerManager.isAuthorizedPartner(account);
    }

    /**
     * @dev Get listing count for a vehicle
     */
    function getListingCount(uint256 _vehicleId) internal view returns (uint256) {
        return marketplace.getVehicleListings(_vehicleId).length;
    }
}
