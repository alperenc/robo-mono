// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ProtocolLib, CollateralLib } from "../contracts/Libraries.sol";
import { RoboshareTokens } from "../contracts/RoboshareTokens.sol";
import { PartnerManager } from "../contracts/PartnerManager.sol";
import { RegistryRouter } from "../contracts/RegistryRouter.sol";
import { VehicleRegistry } from "../contracts/VehicleRegistry.sol";
import { Treasury } from "../contracts/Treasury.sol";
import { Marketplace } from "../contracts/Marketplace.sol";
import { DeployForTest } from "../script/DeployForTest.s.sol";

contract BaseTest is Test {
    // Shared fixture ladder. Only include protocol states that are broadly reusable across suites.
    // Scenario-specific flows such as secondary listings should use dedicated helpers instead.
    enum SetupState {
        None,
        ContractsDeployed,
        InitialAccountsSetup,
        AssetRegistered,
        PrimaryPoolCreated,
        PurchasedFromPrimaryPool,
        BuffersFunded,
        EarningsDistributed
    }

    SetupState private currentState;

    DeployForTest public deployer;
    RoboshareTokens public roboshareTokens;
    PartnerManager public partnerManager;
    Treasury public treasury;
    RegistryRouter public router;
    VehicleRegistry public assetRegistry;
    Marketplace public marketplace;
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
    uint256 constant ASSET_VALUE = 100000 * 10 ** 6; // $100,000 USDC
    uint256 constant PRIMARY_PURCHASE_AMOUNT = (ASSET_VALUE / REVENUE_TOKEN_PRICE) / 2;
    uint256 constant SECONDARY_LISTING_AMOUNT = PRIMARY_PURCHASE_AMOUNT / 2;
    uint256 constant LISTING_DURATION = 30 days;
    uint256 constant SECONDARY_PURCHASE_AMOUNT = SECONDARY_LISTING_AMOUNT / 2;
    uint256 constant EARNINGS_AMOUNT = 1000 * 1e6;
    uint256 constant SMALL_EARNINGS_AMOUNT = 100 * 1e6;
    uint256 constant LARGE_EARNINGS_AMOUNT = 10000 * 1e6;
    uint256 constant SETTLEMENT_TOP_UP_AMOUNT = (PRIMARY_PURCHASE_AMOUNT * REVENUE_TOKEN_PRICE) / 10;

    // Shared scenario handles populated by the fixture helpers below.
    struct TestScenario {
        uint256 assetId;
        uint256 revenueTokenId;
        uint256 listingId;
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

        if (requiredState >= SetupState.InitialAccountsSetup && currentState < SetupState.InitialAccountsSetup) {
            _setupInitialRolesAndAccounts();
            currentState = SetupState.InitialAccountsSetup;
        }

        if (requiredState >= SetupState.AssetRegistered && currentState < SetupState.AssetRegistered) {
            scenario.assetId = _setupAssetRegistered();
            currentState = SetupState.AssetRegistered;
        }

        if (requiredState >= SetupState.PrimaryPoolCreated && currentState < SetupState.PrimaryPoolCreated) {
            scenario.revenueTokenId = _setupPrimaryPoolCreated();
            currentState = SetupState.PrimaryPoolCreated;
        }

        if (requiredState >= SetupState.PurchasedFromPrimaryPool && currentState < SetupState.PurchasedFromPrimaryPool)
        {
            _setupPurchasedFromPrimaryPool();
            currentState = SetupState.PurchasedFromPrimaryPool;
        }

        if (requiredState >= SetupState.BuffersFunded && currentState < SetupState.BuffersFunded) {
            _setupBuffersFunded();
            currentState = SetupState.BuffersFunded;
        }

        if (requiredState >= SetupState.EarningsDistributed && currentState < SetupState.EarningsDistributed) {
            _setupEarningsDistributed(EARNINGS_AMOUNT);
            currentState = SetupState.EarningsDistributed;
        }
    }

    function _deployContracts() internal {
        deployer = new DeployForTest();
        (roboshareTokens, partnerManager, router, assetRegistry, treasury, marketplace) = deployer.run(admin);

        config = deployer.getActiveNetworkConfig();
        usdc = IERC20(config.usdcToken);
    }

    function _setupInitialRolesAndAccounts() internal {
        // Authorize and fund test partners
        _setupMultiplePartners(2);

        // Fund the buyer
        _fundAddressWithUsdc(buyer, 1000000 * 10 ** 6); // 1M USDC
    }

    function _setupAssetRegistered() internal returns (uint256 assetId) {
        vm.prank(partner1);
        assetId = assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            ),
            ASSET_VALUE
        );
    }

    function _setupPrimaryPoolCreated() internal returns (uint256 revenueTokenId) {
        uint256 maturityDate = block.timestamp + 365 days;
        uint256 supply = ASSET_VALUE / REVENUE_TOKEN_PRICE;
        vm.prank(partner1);
        (revenueTokenId,) = assetRegistry.createRevenueTokenPool(
            scenario.assetId, REVENUE_TOKEN_PRICE, maturityDate, 10_000, 1_000, supply, false, false
        );
    }

    function _setupAdditionalAssetAndPrimaryPool(address partner, string memory vin)
        internal
        returns (uint256 assetId, uint256 revenueTokenId, uint256 supply)
    {
        vm.prank(partner);
        assetId = assetRegistry.registerAsset(
            abi.encode(
                vin, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            ),
            ASSET_VALUE
        );

        supply = ASSET_VALUE / REVENUE_TOKEN_PRICE;
        uint256 maturityDate = block.timestamp + 365 days;

        vm.prank(partner);
        (revenueTokenId,) = assetRegistry.createRevenueTokenPool(
            assetId, REVENUE_TOKEN_PRICE, maturityDate, 10_000, 1_000, supply, false, false
        );
    }

    function _setupBuffersFunded() internal {
        uint256 baseAmount = treasury.getPrimaryInvestorLiquidity(scenario.assetId);
        uint256 yieldBP = roboshareTokens.getTargetYieldBP(scenario.revenueTokenId);
        uint256 requiredCollateral = _getTotalBufferRequirement(baseAmount, yieldBP, false);
        vm.prank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        vm.prank(partner1);
        treasury.enableProceeds(scenario.assetId);
    }

    function _creditBaseLiquidity(uint256 amount) internal {
        deal(address(usdc), address(treasury), usdc.balanceOf(address(treasury)) + amount);
        vm.prank(address(marketplace));
        treasury.creditBaseLiquidity(scenario.assetId, amount);
    }

    /**
     * @dev Creates a reusable secondary-listing scenario where the asset owner buys from the
     * primary pool and lists the acquired tokens on the secondary market.
     */
    function _setupSecondaryListingScenario() internal returns (uint256 listingId) {
        _ensureState(SetupState.PrimaryPoolCreated);

        (uint256 primaryCost,,) = marketplace.previewPrimaryPurchase(scenario.revenueTokenId, SECONDARY_LISTING_AMOUNT);

        vm.startPrank(partner1);
        usdc.approve(address(marketplace), primaryCost);
        marketplace.buyFromPrimaryPool(scenario.revenueTokenId, SECONDARY_LISTING_AMOUNT);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        listingId = marketplace.createListing(
            scenario.revenueTokenId, SECONDARY_LISTING_AMOUNT, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
        );
        vm.stopPrank();
    }

    function _ensureSecondaryListingScenario() internal returns (uint256 listingId) {
        if (scenario.listingId != 0) {
            return scenario.listingId;
        }

        scenario.listingId = _setupSecondaryListingScenario();
        return scenario.listingId;
    }

    function _setupPurchasedFromPrimaryPool() internal {
        (uint256 expectedPayment,,) =
            marketplace.previewPrimaryPurchase(scenario.revenueTokenId, PRIMARY_PURCHASE_AMOUNT);
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.buyFromPrimaryPool(scenario.revenueTokenId, PRIMARY_PURCHASE_AMOUNT);
        vm.stopPrank();
    }

    /**
     * @dev Setup earnings distribution scenario
     * @param totalEarningsAmount Total revenue (for tracking)
     * Note: Requires investor tokens to exist (buyer must have purchased tokens first)
     */
    function _setupEarningsDistributed(uint256 totalEarningsAmount) internal {
        vm.startPrank(partner1);
        usdc.approve(address(treasury), totalEarningsAmount);
        treasury.distributeEarnings(scenario.assetId, totalEarningsAmount, false);
        vm.stopPrank();
    }

    function _getInvestorSupply(uint256 revenueTokenId, address partner) internal view returns (uint256) {
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);
        uint256 partnerBalance = roboshareTokens.balanceOf(partner, revenueTokenId);
        return totalSupply > partnerBalance ? totalSupply - partnerBalance : 0;
    }

    function _calculateInvestorAmountFromRevenue(uint256 revenueTokenId, address partner, uint256 totalRevenue)
        internal
        view
        returns (uint256 investorAmount)
    {
        uint256 investorTokens = _getInvestorSupply(revenueTokenId, partner);
        uint256 maxSupply = roboshareTokens.getRevenueTokenMaxSupply(revenueTokenId);
        uint256 revenueShareBP = roboshareTokens.getRevenueShareBP(revenueTokenId);
        uint256 cap = (totalRevenue * revenueShareBP) / ProtocolLib.BP_PRECISION;
        uint256 soldShare = (totalRevenue * investorTokens) / maxSupply;
        return soldShare < cap ? soldShare : cap;
    }

    // ========================================
    // ASSERTION HELPERS
    // ========================================

    /**
     * @dev Assert listing state matches expected values
     */
    function _assertListingState(
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
    function _assertCollateralState(uint256 _assetId, uint256 expectedBase, uint256 expectedTotal, bool expectedLocked)
        internal
        view
    {
        CollateralLib.CollateralInfo memory info = _getCollateralInfo(_assetId);
        assertEq(info.baseCollateral, expectedBase, "Base collateral mismatch");
        assertEq(info.totalCollateral, expectedTotal, "Total collateral mismatch");
        assertEq(info.isLocked, expectedLocked, "Collateral locked state mismatch");
    }

    function _getCollateralInfo(uint256 assetId) internal view returns (CollateralLib.CollateralInfo memory info) {
        (
            info.initialBaseCollateral,
            info.baseCollateral,
            info.earningsBuffer,
            info.protocolBuffer,
            info.totalCollateral,
            info.isLocked,
            info.lockedAt,
            info.lastEventTimestamp,
            info.reservedForLiquidation,
            info.liquidationThreshold,
            info.createdAt,
            info.coveredBaseCollateral
        ) = treasury.assetCollateral(assetId);
    }

    function _getTotalBufferRequirement(uint256 baseAmount, uint256 yieldBP, bool protectionEnabled)
        internal
        pure
        returns (uint256)
    {
        (, uint256 earningsBuffer, uint256 protocolBuffer,) =
            CollateralLib.calculateCollateralRequirements(baseAmount, ProtocolLib.QUARTERLY_INTERVAL, yieldBP);
        return protocolBuffer + (protectionEnabled ? earningsBuffer : 0);
    }

    /**
     * @dev Assert token balances for an address
     */
    function _assertTokenBalance(address account, uint256 tokenId, uint256 expectedBalance, string memory message)
        internal
        view
    {
        uint256 actualBalance = roboshareTokens.balanceOf(account, tokenId);
        assertEq(actualBalance, expectedBalance, message);
    }

    /**
     * @dev Assert USDC balance for an address
     */
    function _assertUsdcBalance(address account, uint256 expectedBalance, string memory message) internal view {
        uint256 actualBalance = usdc.balanceOf(account);
        assertEq(actualBalance, expectedBalance, message);
    }

    function _assertAssetState(uint256 _assetId, address expectedOwner, bool shouldExist) internal view {
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
    function _assertVehicleState(uint256 _assetId, address expectedOwner, string memory expectedVin, bool shouldExist)
        internal
        view
    {
        _assertAssetState(_assetId, expectedOwner, shouldExist);

        if (shouldExist && bytes(expectedVin).length > 0) {
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
    function _generateVin(uint256 seed) internal pure returns (string memory) {
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
    function _generateVehicleData(uint256 seed)
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

        vin = _generateVin(seed);
        make = makes[seed % 5];
        model = models[(seed + 1) % 5];
        year = 2020 + (seed % 5); // 2020-2024
        manufacturerId = (seed % 100) + 1;
        optionCodes = "TEST,OPTION";
        // Use a valid-length IPFS URI (prefix + 46-char CID)
        metadataURI = "ipfs://QmYwAPJzv5CZsnAzt8auVTLpG1bG6dkprdFM5ocTyBCQb";
    }

    // ========================================
    // TIME MANIPULATION HELPERS
    // ========================================

    /**
     * @dev Warp to listing expiry time
     */
    function _warpToListingExpiry(uint256 _listingId) internal {
        Marketplace.Listing memory listing = marketplace.getListing(_listingId);
        vm.warp(listing.expiresAt + 1);
    }

    /**
     * @dev Warp past holding period for penalty-free transfers
     */
    function _warpPastHoldingPeriod() internal {
        vm.warp(block.timestamp + 30 days + 1); // Monthly interval + 1
    }

    /**
     * @dev Warp to specific time offset
     */
    function _warpToTimeOffset(uint256 offsetSeconds) internal {
        vm.warp(block.timestamp + offsetSeconds);
    }

    /**
     * @dev Save current timestamp and warp, returning original time
     */
    function _warpAndSaveTime(uint256 newTime) internal returns (uint256 originalTime) {
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
        uint256 marketplaceContractUsdc;
        uint256 partnerTokens;
        uint256 buyerTokens;
        uint256 marketplaceTokens;
        uint256 timestamp;
    }

    /**
     * @dev Take a snapshot of all relevant balances
     */
    function _takeBalanceSnapshot(uint256 tokenId) internal view returns (BalanceSnapshot memory snapshot) {
        snapshot.partnerUsdc = usdc.balanceOf(partner1);
        snapshot.buyerUsdc = usdc.balanceOf(buyer);
        snapshot.treasuryFeeRecipientUsdc = usdc.balanceOf(config.treasuryFeeRecipient);
        snapshot.treasuryContractUsdc = usdc.balanceOf(address(treasury));
        snapshot.marketplaceContractUsdc = usdc.balanceOf(address(marketplace));
        snapshot.partnerTokens = roboshareTokens.balanceOf(partner1, tokenId);
        snapshot.buyerTokens = roboshareTokens.balanceOf(buyer, tokenId);
        snapshot.marketplaceTokens = roboshareTokens.balanceOf(address(marketplace), tokenId);
        snapshot.timestamp = block.timestamp;
    }

    /**
     * @dev Compare two balance snapshots and assert expected changes
     */
    function _assertBalanceChanges(
        BalanceSnapshot memory before,
        BalanceSnapshot memory afterSnapshot,
        int256 expectedPartnerUsdcChange,
        int256 expectedBuyerUsdcChange,
        int256 expectedTreasuryFeeRecipientUsdcChange,
        int256 expectedTreasuryContractUsdcChange,
        int256 expectedMarketplaceContractUsdcChange,
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
            int256(afterSnapshot.marketplaceContractUsdc) - int256(before.marketplaceContractUsdc),
            expectedMarketplaceContractUsdcChange,
            "Marketplace Contract USDC change mismatch"
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
    function _expectRevenueTokensTradedEvent(
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
    function _setupInsufficientFunds(address account, uint256 neededAmount) internal {
        uint256 currentBalance = usdc.balanceOf(account);
        if (currentBalance >= neededAmount / 2) {
            // Transfer away most funds, keeping less than half needed
            vm.prank(account);
            // forge-lint: disable-next-line(erc20-unchecked-transfer)
            usdc.transfer(makeAddr("drain"), currentBalance - (neededAmount / 3));
        }
    }

    /**
     * @dev Set up expired listing scenario
     */
    function _setupExpiredListing(uint256 _listingId) internal {
        _warpToListingExpiry(_listingId);
    }

    // ========================================
    // CALCULATION HELPERS
    // ========================================

    /**
     * @dev Calculate expected collateral requirement
     */
    function _calculateExpectedBuffers(uint256 baseAmount)
        internal
        pure
        returns (uint256 earningsBuffer, uint256 protocolBuffer, uint256 total)
    {
        uint256 expectedQuarterlyEarnings =
            (baseAmount * ProtocolLib.QUARTERLY_INTERVAL) / ProtocolLib.YEARLY_INTERVAL;
        earningsBuffer = (expectedQuarterlyEarnings * ProtocolLib.BENCHMARK_YIELD_BP) / ProtocolLib.BP_PRECISION;
        protocolBuffer = (expectedQuarterlyEarnings * ProtocolLib.PROTOCOL_FEE_BP) / ProtocolLib.BP_PRECISION;
        total = earningsBuffer + protocolBuffer;
    }

    // ========================================
    // MOCK SETUP HELPERS
    // ========================================

    /**
     * @dev Create multiple test vehicles for a partner
     */
    function _createMultipleTestVehicles(address partner, uint256 count) internal returns (uint256[] memory assetIds) {
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
            ) = _generateVehicleData(i + uint256(keccak256(abi.encodePacked(partner, block.timestamp))));

            assetIds[i] = assetRegistry.registerAsset(
                abi.encode(vin, make, model, year, manufacturerId, optionCodes, metadataURI), ASSET_VALUE
            );
        }
        vm.stopPrank();

        return assetIds;
    }

    /**
     * @dev Setup multiple partners with authorization and funding
     */
    function _setupMultiplePartners(uint256 count) internal returns (address[] memory partners) {
        partners = new address[](count);

        vm.startPrank(admin);
        for (uint256 i = 0; i < count; i++) {
            // Naming convention: partner1, partner2, partner3...
            partners[i] = makeAddr(string(abi.encodePacked("partner", vm.toString(i + 1))));
            partnerManager.authorizePartner(partners[i], string(abi.encodePacked("Partner ", vm.toString(i + 1))));

            // Fund partners with MockUSDC
            _fundAddressWithUsdc(partners[i], 1000000 * 10 ** 6); // 1M USDC
        }
        vm.stopPrank();

        return partners;
    }

    // ========================================
    // UTILITY FUNCTIONS
    // ========================================

    /**
     * @dev Fund an address with USDC
     */
    function _fundAddressWithUsdc(address account, uint256 amount) internal {
        deal(address(usdc), account, amount);
    }

    /**
     * @dev Get listing count for an asset
     */
    function _getListingCount(uint256 _assetId) internal view returns (uint256) {
        return marketplace.getAssetListings(_assetId).length;
    }
}
