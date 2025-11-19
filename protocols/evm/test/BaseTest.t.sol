// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../contracts/interfaces/IAssetRegistry.sol";
import "../contracts/Libraries.sol";
import "../contracts/RoboshareTokens.sol";
import "../contracts/PartnerManager.sol";
import "../contracts/VehicleRegistry.sol";
import "../contracts/Treasury.sol";
import "../contracts/Marketplace.sol";
import { DeployForTest } from "../script/DeployForTest.s.sol";

contract BaseTest is Test {
    enum SetupState {
        None,
        ContractsDeployed,
        PartnersAuthorized,
        AccountsFunded,
        AssetRegistered,
        RevenueTokensMinted,
        AssetWithListing,
        AssetWithPurchase,
        AssetWithEarnings,
        AssetWithPartialCollateralRelease,
        AssetWithFullCollateralRelease
    }

    SetupState private currentState;

    DeployForTest public deployer;
    RoboshareTokens public roboshareTokens;
    RoboshareTokens public tokenImplementation;
    PartnerManager public partnerManager;
    PartnerManager public partnerImplementation;
    Treasury public treasury;
    Treasury public treasuryImplementation;
    VehicleRegistry public assetRegistry;
    VehicleRegistry public registryImplementation;
    Marketplace public marketplace;
    Marketplace public marketplaceImplementation;
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
    uint256 constant LISTING_AMOUNT = 500;
    uint256 constant LISTING_DURATION = 30 days;
    uint256 constant PURCHASE_AMOUNT = 100;

    // Storage for test scenario states
    struct TestScenario {
        uint256 assetId;
        uint256 revenueTokenId;
        uint256 requiredCollateral;
        uint256 listingId;
        uint256 initialProtocolBalance;
        uint256 earnings;
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

        if (requiredState >= SetupState.AssetRegistered && currentState < SetupState.AssetRegistered) {
            scenario.assetId = _setupAssetRegistered();
            currentState = SetupState.AssetRegistered;
        }

        if (requiredState >= SetupState.RevenueTokensMinted && currentState < SetupState.RevenueTokensMinted) {
            scenario.revenueTokenId = _setupRevenueTokensMinted();
            currentState = SetupState.RevenueTokensMinted;
        }

        if (requiredState >= SetupState.AssetWithListing && currentState < SetupState.AssetWithListing) {
            // Approve marketplace to transfer tokens on behalf of partner1
            vm.prank(partner1);
            roboshareTokens.setApprovalForAll(address(marketplace), true);

            vm.prank(partner1);
            // Create listing for tokens (collateral already locked)
            scenario.listingId = marketplace.createListing(
                scenario.revenueTokenId, LISTING_AMOUNT, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
            );
            currentState = SetupState.AssetWithListing;
        }

        if (requiredState >= SetupState.AssetWithPurchase && currentState < SetupState.AssetWithPurchase) {
            // Buyer approves USDC for purchase
            (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(scenario.listingId, PURCHASE_AMOUNT);
            vm.startPrank(buyer);
            usdc.approve(address(marketplace), expectedPayment);

            // Buyer purchases tokens
            marketplace.purchaseTokens(scenario.listingId, PURCHASE_AMOUNT);
            vm.stopPrank();
            currentState = SetupState.AssetWithPurchase;
        }

        if (requiredState >= SetupState.AssetWithEarnings && currentState < SetupState.AssetWithEarnings) {
            setupEarningsScenario(scenario.assetId, 1000e6);
            currentState = SetupState.AssetWithEarnings;
        }
    }

    function _deployContracts() internal {
        deployer = new DeployForTest();
        (
            marketplace,
            assetRegistry,
            roboshareTokens,
            partnerManager,
            treasury,
            marketplaceImplementation,
            registryImplementation,
            tokenImplementation,
            partnerImplementation,
            treasuryImplementation
        ) = deployer.run(admin);

        config = deployer.getActiveNetworkConfig();
        usdc = IERC20(config.usdcToken);
    }

    function _setupInitialRolesAndPartners() internal {
        // Setup roles and permissions
        vm.startPrank(admin);
        // Grant MINTER_ROLE and BURNER_ROLE to VehicleRegistry for token operations
        roboshareTokens.grantRole(roboshareTokens.MINTER_ROLE(), address(assetRegistry));
        roboshareTokens.grantRole(roboshareTokens.BURNER_ROLE(), address(assetRegistry));
        // Grant AUTHORIZED_CONTRACT_ROLE to VehicleRegistry and Marketplace for Treasury operations
        treasury.grantRole(treasury.AUTHORIZED_CONTRACT_ROLE(), address(assetRegistry));
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

    function _setupAssetRegistered() internal returns (uint256 assetId) {
        vm.prank(partner1);
        assetId = assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            )
        );
    }

    function _setupRevenueTokensMinted() internal returns (uint256 revenueTokenId) {
        // Calculate required collateral
        scenario.requiredCollateral = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        vm.startPrank(partner1);
        // Approve USDC for collateral
        usdc.approve(address(treasury), scenario.requiredCollateral);

        revenueTokenId = assetRegistry.mintRevenueTokens(scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();
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
     * @dev Assert collateral state for an asset
     */
    function assertCollateralState(uint256 _assetId, uint256 expectedBase, uint256 expectedTotal, bool expectedLocked)
        internal
        view
    {
        (uint256 base, uint256 total, bool locked,,) = treasury.getAssetCollateralInfo(_assetId);
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

    function assertAssetState(uint256 _assetId, address expectedOwner, bool shouldExist) internal view {
        if (shouldExist) {
            // Check ownership via ERC1155 balance
            assertEq(roboshareTokens.balanceOf(expectedOwner, _assetId), 1, "Asset owner mismatch");
            // Also check the exists function
            assertTrue(assetRegistry.assetExists(_assetId), "assetExists should be true");
        } else {
            // Check that the NFT is not owned
            assertEq(roboshareTokens.balanceOf(expectedOwner, _assetId), 0, "Asset should not be owned");
            // Check that the registry reports it as not existing
            assertFalse(assetRegistry.assetExists(_assetId), "assetExists should be false");
        }
    }

    /**
     * @dev Assert vehicle-specific registration state
     */
    function assertVehicleState(uint256 _assetId, address expectedOwner, string memory expectedVin, bool shouldExist)
        internal
        view
    {
        assertAssetState(_assetId, expectedOwner, shouldExist);

        if (shouldExist) {
            // Check vehicle info stored in the registry
            (string memory vin,,,,,,) = assetRegistry.getVehicleInfo(_assetId);
            assertEq(vin, expectedVin, "Vehicle VIN mismatch");
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
        uint256 treasuryFeeRecipientUsdc;
        uint256 treasuryContractUsdc;
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
        snapshot.treasuryFeeRecipientUsdc = usdc.balanceOf(config.treasuryFeeRecipient);
        snapshot.treasuryContractUsdc = usdc.balanceOf(address(treasury));
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
        int256 expectedTreasuryFeeRecipientUsdcChange,
        int256 expectedTreasuryContractUsdcChange,
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
            int256(afterSnapshot.treasuryFeeRecipientUsdc) - int256(before.treasuryFeeRecipientUsdc),
            expectedTreasuryFeeRecipientUsdcChange,
            "Treasury Fee Recipient USDC change mismatch"
        );
        assertEq(
            int256(afterSnapshot.treasuryContractUsdc) - int256(before.treasuryContractUsdc),
            expectedTreasuryContractUsdcChange,
            "Treasury Contract USDC change mismatch"
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
        uint256 expectedQuarterlyEarnings = (base * ProtocolLib.QUARTERLY_INTERVAL) / ProtocolLib.YEARLY_INTERVAL;
        earningsBuffer =
            (expectedQuarterlyEarnings * ProtocolLib.BENCHMARK_EARNINGS_BP) / ProtocolLib.BP_PRECISION;
        protocolBuffer =
            (expectedQuarterlyEarnings * ProtocolLib.PROTOCOL_FEE_BP) / ProtocolLib.BP_PRECISION;
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

        // Register asset and mint tokens in one go
        (scenario.assetId, scenario.revenueTokenId) = assetRegistry.registerAssetAndMintTokens(
            abi.encode(vin, make, model, year, manufacturerId, optionCodes, metadataURI), tokenPrice, totalTokens
        );

        // Approve RoboshareTokens for Marketplace listing
        roboshareTokens.setApprovalForAll(address(marketplace), true);

        scenario.listingId =
            marketplace.createListing(scenario.revenueTokenId, tokensToList, tokenPrice, duration, buyerPaysFee);

        vm.stopPrank();

        return (scenario.assetId, scenario.revenueTokenId, scenario.listingId);
    }

    /**
     * @dev Setup earnings distribution scenario
     */
    function setupEarningsScenario(uint256 _assetId, uint256 earningsAmount) internal {
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        treasury.distributeEarnings(_assetId, earningsAmount);
        vm.stopPrank();
    }

    /**
     * @dev Create multiple test vehicles for a partner
     */
    function createMultipleTestVehicles(address partner, uint256 count) internal returns (uint256[] memory assetIds) {
        assetIds = new uint256[](count);

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

            assetIds[i] = assetRegistry.registerAsset(
                abi.encode(vin, make, model, year, manufacturerId, optionCodes, metadataURI)
            );
        }
        vm.stopPrank();

        return assetIds;
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
     * @dev Get listing count for an asset
     */
    function getListingCount(uint256 _assetId) internal view returns (uint256) {
        return marketplace.getAssetListings(_assetId).length;
    }
}
