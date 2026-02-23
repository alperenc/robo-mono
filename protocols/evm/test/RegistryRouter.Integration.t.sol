// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { AssetLib, TokenLib } from "../contracts/Libraries.sol";
import { IAssetRegistry } from "../contracts/interfaces/IAssetRegistry.sol";
import { RoboshareTokens } from "../contracts/RoboshareTokens.sol";
import { RegistryRouter } from "../contracts/RegistryRouter.sol";
import { Treasury } from "../contracts/Treasury.sol";
import { PartnerManager } from "../contracts/PartnerManager.sol";

// Simple Mock Registry to simulate a second asset type (e.g., "MachineRegistry")
contract MockRegistry is IAssetRegistry {
    RegistryRouter public router;
    RoboshareTokens public roboshareTokens;
    Treasury public treasuryContract;

    struct MockAsset {
        uint256 id;
        AssetLib.AssetInfo info;
    }

    mapping(uint256 => MockAsset) public assets;

    constructor(address _router, address _tokens, address _treasury) {
        router = RegistryRouter(_router);
        roboshareTokens = RoboshareTokens(_tokens);
        treasuryContract = Treasury(_treasury);
    }

    function registerAndMint(address partner, uint256 assetValue, uint256 tokenPrice)
        external
        returns (uint256 assetId, uint256 revenueTokenId, uint256 listingId)
    {
        // 1. Reserve IDs from Router (this binds the assetId to this registry in the Router)
        (assetId, revenueTokenId) = router.reserveNextTokenIdPair();

        // 2. Initialize local state
        assets[assetId].id = assetId;
        assets[assetId].info.assetValue = assetValue;
        assets[assetId].info.status = AssetLib.AssetStatus.Active;
        assets[assetId].info.createdAt = block.timestamp;
        assets[assetId].info.updatedAt = block.timestamp;

        // 3. Compute supply for preview + mint flow
        uint256 maturityDate = block.timestamp + 365 days;

        // Mint Asset NFT first so partner owns it for collateral locking
        roboshareTokens.mint(partner, assetId, 1, "");

        // 4. Mint + list through router flow (registry wrapper)
        (,, listingId) =
            router.mintRevenueTokensAndListFor(partner, assetId, tokenPrice, maturityDate, 10_000, 1_000, 1 days, true);

        return (assetId, revenueTokenId, listingId);
    }

    function registerAssetForTest(uint256 assetId, uint256 assetValue) external {
        assets[assetId].id = assetId;
        assets[assetId].info.assetValue = assetValue;
        assets[assetId].info.status = AssetLib.AssetStatus.Active;
        assets[assetId].info.createdAt = block.timestamp;
        assets[assetId].info.updatedAt = block.timestamp;
    }

    // Implement required IAssetRegistry view functions
    function assetExists(uint256 assetId) external view override returns (bool) {
        return assets[assetId].id != 0;
    }

    function getAssetInfo(uint256 assetId) external view override returns (AssetLib.AssetInfo memory) {
        return assets[assetId].info;
    }

    function getAssetStatus(uint256 assetId) external view override returns (AssetLib.AssetStatus) {
        return assets[assetId].info.status;
    }

    // Stubs for other functions
    function registerAsset(bytes calldata, uint256) external pure override returns (uint256) {
        return 0;
    }

    function registerAssetMintAndList(bytes calldata, uint256, uint256, uint256, uint256, uint256, uint256, bool)
        external
        pure
        override
        returns (uint256, uint256, uint256, uint256)
    {
        return (0, 0, 0, 0);
    }

    function mintRevenueTokensAndList(uint256, uint256, uint256, uint256, uint256, uint256, bool)
        external
        pure
        override
        returns (uint256, uint256, uint256)
    {
        return (0, 0, 0);
    }

    function previewMintRevenueTokens(uint256 assetId, address partner, uint256 tokenPrice)
        external
        view
        override
        returns (uint256 tokenId, uint256 supply)
    {
        if (assets[assetId].id == 0) {
            revert AssetNotFound(assetId);
        }
        if (roboshareTokens.balanceOf(partner, assetId) == 0) {
            revert NotAssetOwner();
        }

        tokenId = TokenLib.getTokenIdFromAssetId(assetId);
        if (roboshareTokens.getRevenueTokenSupply(tokenId) > 0) {
            revert RevenueTokensAlreadyMinted();
        }

        supply = assets[assetId].info.assetValue / tokenPrice;
    }

    function setAssetStatus(uint256, AssetLib.AssetStatus) external override { }
    function burnRevenueTokens(uint256, uint256) external override { }
    function retireAsset(uint256) external override { }
    function retireAssetAndBurnTokens(uint256) external override { }

    function settleAsset(
        uint256 assetId,
        uint256 /* topUpAmount */
    )
        external
        override
    {
        // Mock implementation: just set status to Retired
        assets[assetId].info.status = AssetLib.AssetStatus.Retired;
    }

    function liquidateAsset(uint256 assetId) external override {
        // Mock implementation: just set status to Expired
        assets[assetId].info.status = AssetLib.AssetStatus.Expired;
    }

    function claimSettlement(uint256, bool) external pure override returns (uint256, uint256) {
        return (0, 0);
    }

    function claimSettlementFor(address, uint256, bool) external pure override returns (uint256, uint256) {
        return (0, 0);
    }

    function getRegistryType() external pure override returns (string memory) {
        return "MockRegistry";
    }

    function getRegistryVersion() external pure override returns (uint256) {
        return 1;
    }

    function setTreasury(address) external { }

    function treasury() external view returns (address) {
        return address(treasuryContract);
    }

    function getRegistryForAsset(uint256) external view override returns (address) {
        return address(this);
    }
}

contract RegistryRouterHarness is RegistryRouter {
    function exposeMintRevenueTokensToEscrow(address registry, uint256 revenueTokenId, uint256 amount) external {
        _mintRevenueTokensToEscrow(registry, revenueTokenId, amount);
    }
}

contract RegistryRouterIntegrationTest is BaseTest {
    MockRegistry public mockRegistry;

    function setUp() public {
        _ensureState(SetupState.InitialAccountsSetup);

        // Get the router deployed in BaseTest
        // router is already set in BaseTest

        // Deploy MockRegistry
        mockRegistry = new MockRegistry(address(router), address(roboshareTokens), address(treasury));

        // Setup Roles for MockRegistry
        vm.startPrank(admin);

        // 1. Grant AUTHORIZED_REGISTRY_ROLE to MockRegistry on Router
        router.grantRole(router.AUTHORIZED_REGISTRY_ROLE(), address(mockRegistry));

        // 2. Grant MINTER_ROLE to MockRegistry on RoboshareTokens
        roboshareTokens.grantRole(roboshareTokens.MINTER_ROLE(), address(mockRegistry));

        // 3. Grant AUTHORIZED_CONTRACT_ROLE to MockRegistry on Treasury
        treasury.grantRole(treasury.AUTHORIZED_CONTRACT_ROLE(), address(mockRegistry));

        vm.stopPrank();
    }

    function testMultiRegistryOperations() public {
        // 1. Register a standard Vehicle (Asset ID 1, Token ID 2)
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 vehicleAssetId = scenario.assetId;

        // Verify Router knows about VehicleRegistry
        assertEq(router.getRegistryForAsset(vehicleAssetId), address(assetRegistry));

        // 2. Register a Mock Asset (Asset ID 3, Token ID 4)
        vm.startPrank(partner1);

        (uint256 mockAssetId, uint256 mockTokenId, uint256 listingId) =
            mockRegistry.registerAndMint(partner1, ASSET_VALUE, REVENUE_TOKEN_PRICE);
        vm.stopPrank();

        // Verify IDs
        assertEq(mockAssetId, 3);
        assertEq(mockTokenId, 4);

        // Verify Router knows about MockRegistry
        assertEq(router.getRegistryForAsset(mockAssetId), address(mockRegistry));

        // 3. Purchase Mock Token
        uint256 purchaseAmount = PURCHASE_AMOUNT;
        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(listingId, purchaseAmount);

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(listingId, purchaseAmount);
        vm.stopPrank();

        // 4. End Listing and Claim Tokens (New Escrow Flow)
        vm.prank(partner1);
        usdc.approve(address(treasury), type(uint256).max);

        vm.prank(partner1);
        marketplace.endListing(listingId);

        vm.prank(buyer);
        marketplace.claimTokens(listingId);

        // Verify ownership transfer
        assertEq(roboshareTokens.balanceOf(buyer, mockTokenId), purchaseAmount);
    }

    function testMintRevenueTokensAndList() public {
        _ensureState(SetupState.InitialAccountsSetup);

        vm.startPrank(admin);
        router.setMarketplace(address(marketplace));
        marketplace.grantRole(marketplace.AUTHORIZED_CONTRACT_ROLE(), address(router));
        vm.stopPrank();

        // Register asset only
        vm.startPrank(partner1);
        uint256 assetId = assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            ),
            ASSET_VALUE
        );

        (uint256 revenueTokenId, uint256 tokenSupply, uint256 listingId) = router.mintRevenueTokensAndList(
            assetId, REVENUE_TOKEN_PRICE, block.timestamp + 365 days, 10_000, 1_000, 30 days, true
        );
        vm.stopPrank();

        assertEq(uint8(assetRegistry.getAssetStatus(assetId)), uint8(AssetLib.AssetStatus.Active));
        assertEq(roboshareTokens.balanceOf(address(marketplace), revenueTokenId), tokenSupply);
        _assertListingState(listingId, revenueTokenId, tokenSupply, REVENUE_TOKEN_PRICE, partner1, true, true);
    }

    // RegistryNotFound Tests

    function testGetAssetInfoRegistryNotFound() public {
        uint256 nonExistentAssetId = 999;
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, nonExistentAssetId));
        router.getAssetInfo(nonExistentAssetId);
    }

    function testMintRevenueTokensAndListRegistryNotFound() public {
        _ensureState(SetupState.InitialAccountsSetup);
        uint256 nonExistentAssetId = 999;
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, nonExistentAssetId));
        vm.prank(partner1);
        router.mintRevenueTokensAndList(
            nonExistentAssetId, REVENUE_TOKEN_PRICE, block.timestamp + 365 days, 10_000, 1_000, 30 days, true
        );
    }

    function testMintRevenueTokensAndListUnauthorizedPartner() public {
        _ensureState(SetupState.AssetRegistered);
        vm.expectRevert(PartnerManager.UnauthorizedPartner.selector);
        vm.prank(buyer);
        router.mintRevenueTokensAndList(
            scenario.assetId, REVENUE_TOKEN_PRICE, block.timestamp + 365 days, 10_000, 1_000, 30 days, true
        );
    }

    function testPreviewMintRevenueTokensRegistryNotFound() public {
        uint256 nonExistentAssetId = 999;
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, nonExistentAssetId));
        router.previewMintRevenueTokens(nonExistentAssetId, partner1, REVENUE_TOKEN_PRICE);
    }

    function testPreviewMintRevenueTokens() public {
        _ensureState(SetupState.AssetRegistered);
        (uint256 tokenId, uint256 supply) =
            router.previewMintRevenueTokens(scenario.assetId, partner1, REVENUE_TOKEN_PRICE);

        assertEq(tokenId, TokenLib.getTokenIdFromAssetId(scenario.assetId));
        assertEq(supply, ASSET_VALUE / REVENUE_TOKEN_PRICE);
    }

    function testGetAssetStatusRegistryNotFound() public {
        uint256 nonExistentAssetId = 999;
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, nonExistentAssetId));
        router.getAssetStatus(nonExistentAssetId);
    }

    function testSetAssetStatusRegistryNotFound() public {
        uint256 nonExistentAssetId = 999;
        vm.prank(address(treasury));
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, nonExistentAssetId));
        router.setAssetStatus(nonExistentAssetId, AssetLib.AssetStatus.Active);
    }

    function testSetAssetStatusTreasurySuccess() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.prank(address(treasury));
        router.setAssetStatus(scenario.assetId, AssetLib.AssetStatus.Active);

        assertEq(uint8(router.getAssetStatus(scenario.assetId)), uint8(AssetLib.AssetStatus.Active));
    }

    function testSetAssetStatusNotTreasury() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.expectRevert(RegistryRouter.NotTreasury.selector);
        router.setAssetStatus(scenario.assetId, AssetLib.AssetStatus.Active);
    }

    function testBurnRevenueTokensRegistryNotFound() public {
        uint256 nonExistentAssetId = 999;
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, nonExistentAssetId));
        router.burnRevenueTokens(nonExistentAssetId, 100);
    }

    function testRetireAssetRegistryNotFound() public {
        uint256 nonExistentAssetId = 999;
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, nonExistentAssetId));
        router.retireAsset(nonExistentAssetId);
    }

    function testRetireAssetAndBurnTokensRegistryNotFound() public {
        uint256 nonExistentAssetId = 999;
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, nonExistentAssetId));
        router.retireAssetAndBurnTokens(nonExistentAssetId);
    }

    function testSettleAssetRegistryNotFound() public {
        uint256 nonExistentAssetId = 999;
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, nonExistentAssetId));
        router.settleAsset(nonExistentAssetId, 0);
    }

    function testLiquidateAssetRegistryNotFound() public {
        uint256 nonExistentAssetId = 999;
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, nonExistentAssetId));
        router.liquidateAsset(nonExistentAssetId);
    }

    function testClaimSettlementForRegistryNotFound() public {
        uint256 nonExistentAssetId = 999;
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, nonExistentAssetId));
        router.claimSettlementFor(partner1, nonExistentAssetId, false);
    }

    function testRecordSoldSupply() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 soldAmount = 10;
        uint256 beforeSold = roboshareTokens.getSoldSupply(scenario.revenueTokenId);

        vm.prank(address(marketplace));
        router.recordSoldSupply(scenario.revenueTokenId, soldAmount);

        uint256 afterSold = roboshareTokens.getSoldSupply(scenario.revenueTokenId);
        assertEq(afterSold, beforeSold + soldAmount);
    }

    function testRecordSoldSupplyNotMarketplace() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.expectRevert(RegistryRouter.NotMarketplace.selector);
        router.recordSoldSupply(scenario.revenueTokenId, 10);
    }

    function testRecordSoldSupplyRegistryNotFound() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 unboundTokenId = scenario.revenueTokenId + 2;

        vm.prank(address(marketplace));
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, unboundTokenId));
        router.recordSoldSupply(unboundTokenId, 10);
    }

    function testRecordSoldSupplyZeroAmount() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 beforeSold = roboshareTokens.getSoldSupply(scenario.revenueTokenId);

        vm.prank(address(marketplace));
        router.recordSoldSupply(scenario.revenueTokenId, 0);

        assertEq(roboshareTokens.getSoldSupply(scenario.revenueTokenId), beforeSold);
    }

    function testCreditTokenEscrow() public {
        _ensureState(SetupState.RevenueTokensMinted);

        uint256 tokenId = scenario.revenueTokenId;
        uint256 beforeEscrow = marketplace.tokenEscrow(tokenId);
        uint256 amount = 123;

        vm.prank(address(assetRegistry));
        router.creditTokenEscrow(scenario.assetId, amount);

        assertEq(marketplace.tokenEscrow(tokenId), beforeEscrow + amount);
    }

    function testClearTokenEscrow() public {
        _ensureState(SetupState.RevenueTokensMinted);

        uint256 tokenId = scenario.revenueTokenId;
        uint256 beforeEscrow = marketplace.tokenEscrow(tokenId);

        vm.prank(address(assetRegistry));
        uint256 cleared = router.clearTokenEscrow(scenario.assetId);

        assertEq(cleared, beforeEscrow);
        assertEq(marketplace.tokenEscrow(tokenId), 0);
    }

    function testClearTokenEscrowRegistryNotBoundToAsset() public {
        _ensureState(SetupState.RevenueTokensMinted);
        address unauthorizedRegistry = makeAddr("unauthorizedRegistry");

        vm.startPrank(admin);
        router.grantRole(router.AUTHORIZED_REGISTRY_ROLE(), unauthorizedRegistry);
        vm.stopPrank();

        vm.prank(unauthorizedRegistry);
        vm.expectRevert(RegistryRouter.RegistryNotBoundToAsset.selector);
        router.clearTokenEscrow(scenario.assetId);
    }

    function testCreditTokenEscrowRegistryNotBoundToAsset() public {
        _ensureState(SetupState.RevenueTokensMinted);
        address unauthorizedRegistry = makeAddr("unauthorizedRegistry");

        vm.startPrank(admin);
        router.grantRole(router.AUTHORIZED_REGISTRY_ROLE(), unauthorizedRegistry);
        vm.stopPrank();

        vm.prank(unauthorizedRegistry);
        vm.expectRevert(RegistryRouter.RegistryNotBoundToAsset.selector);
        router.creditTokenEscrow(scenario.assetId, 10);
    }

    // RegistryNotBoundToAsset Tests

    function testReleaseCollateralForRegistryNotBoundToAsset() public {
        uint256 assetId = 100;
        address unauthorizedRegistry = makeAddr("unauthorizedRegistry");

        vm.startPrank(admin);
        router.grantRole(router.AUTHORIZED_REGISTRY_ROLE(), unauthorizedRegistry);
        vm.stopPrank();

        vm.prank(unauthorizedRegistry);
        vm.expectRevert(RegistryRouter.RegistryNotBoundToAsset.selector);
        router.releaseCollateralFor(partner1, assetId);
    }

    function testInitiateSettlementRegistryNotBoundToAsset() public {
        uint256 assetId = 100;
        address unauthorizedRegistry = makeAddr("unauthorizedRegistry");

        vm.startPrank(admin);
        router.grantRole(router.AUTHORIZED_REGISTRY_ROLE(), unauthorizedRegistry);
        vm.stopPrank();

        vm.prank(unauthorizedRegistry);
        vm.expectRevert(RegistryRouter.RegistryNotBoundToAsset.selector);
        router.initiateSettlement(partner1, assetId, 100);
    }

    function testExecuteLiquidationRegistryNotBoundToAsset() public {
        uint256 assetId = 100;
        address unauthorizedRegistry = makeAddr("unauthorizedRegistry");

        vm.startPrank(admin);
        router.grantRole(router.AUTHORIZED_REGISTRY_ROLE(), unauthorizedRegistry);
        vm.stopPrank();

        vm.prank(unauthorizedRegistry);
        vm.expectRevert(RegistryRouter.RegistryNotBoundToAsset.selector);
        router.executeLiquidation(assetId);
    }

    function testProcessSettlementClaimRegistryNotBoundToAsset() public {
        uint256 assetId = 100;
        address unauthorizedRegistry = makeAddr("unauthorizedRegistry");

        vm.startPrank(admin);
        router.grantRole(router.AUTHORIZED_REGISTRY_ROLE(), unauthorizedRegistry);
        vm.stopPrank();

        vm.prank(unauthorizedRegistry);
        vm.expectRevert(RegistryRouter.RegistryNotBoundToAsset.selector);
        router.processSettlementClaim(partner1, assetId, 100);
    }

    // TreasuryNotSet Tests

    function _setupRouterWithoutTreasury() internal returns (RegistryRouter, uint256 assetId) {
        vm.startPrank(admin);
        RegistryRouter freshRouter = new RegistryRouter();
        ERC1967Proxy proxy = new ERC1967Proxy(address(freshRouter), "");
        RegistryRouter proxyRouter = RegistryRouter(address(proxy));
        proxyRouter.initialize(admin, address(roboshareTokens), address(partnerManager));
        proxyRouter.grantRole(proxyRouter.AUTHORIZED_REGISTRY_ROLE(), address(assetRegistry));
        roboshareTokens.grantRole(roboshareTokens.MINTER_ROLE(), address(proxyRouter));
        vm.stopPrank();

        vm.prank(address(assetRegistry));
        (assetId,) = proxyRouter.reserveNextTokenIdPair();

        return (proxyRouter, assetId);
    }

    function testReleaseCollateralForTreasuryNotSet() public {
        (RegistryRouter proxyRouter, uint256 assetId) = _setupRouterWithoutTreasury();
        vm.prank(address(assetRegistry));
        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        proxyRouter.releaseCollateralFor(partner1, assetId);
    }

    function testIsAssetSolventTreasuryNotSet() public {
        (RegistryRouter proxyRouter, uint256 assetId) = _setupRouterWithoutTreasury();
        vm.prank(address(assetRegistry));
        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        proxyRouter.isAssetSolvent(assetId);
    }

    function testPreviewLiquidationEligibilityTreasuryNotSet() public {
        (RegistryRouter proxyRouter, uint256 assetId) = _setupRouterWithoutTreasury();
        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        proxyRouter.previewLiquidationEligibility(assetId);
    }

    function testInitiateSettlementTreasuryNotSet() public {
        (RegistryRouter proxyRouter, uint256 assetId) = _setupRouterWithoutTreasury();
        vm.prank(address(assetRegistry));
        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        proxyRouter.initiateSettlement(partner1, assetId, 100);
    }

    function testExecuteLiquidationTreasuryNotSet() public {
        (RegistryRouter proxyRouter, uint256 assetId) = _setupRouterWithoutTreasury();
        vm.prank(address(assetRegistry));
        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        proxyRouter.executeLiquidation(assetId);
    }

    function testProcessSettlementClaimTreasuryNotSet() public {
        (RegistryRouter proxyRouter, uint256 assetId) = _setupRouterWithoutTreasury();
        vm.prank(address(assetRegistry));
        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        proxyRouter.processSettlementClaim(partner1, assetId, 100);
    }

    function testSnapshotAndClaimEarningsTreasuryNotSet() public {
        (RegistryRouter proxyRouter, uint256 assetId) = _setupRouterWithoutTreasury();
        vm.prank(address(assetRegistry));
        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        proxyRouter.snapshotAndClaimEarnings(assetId, partner1, false);
    }

    function testSnapshotAndClaimEarningsRegistryNotBoundToAsset() public {
        uint256 assetId = 100;
        address unauthorizedRegistry = makeAddr("unauthorizedRegistry");

        vm.startPrank(admin);
        router.grantRole(router.AUTHORIZED_REGISTRY_ROLE(), unauthorizedRegistry);
        vm.stopPrank();

        vm.prank(unauthorizedRegistry);
        vm.expectRevert(RegistryRouter.RegistryNotBoundToAsset.selector);
        router.snapshotAndClaimEarnings(assetId, partner1, false);
    }

    // MarketplaceNotSet Tests

    function _setupRouterWithoutMarketplace() internal returns (RegistryRouter, uint256 assetId) {
        vm.startPrank(admin);
        RegistryRouter freshRouter = new RegistryRouter();
        ERC1967Proxy proxy = new ERC1967Proxy(address(freshRouter), "");
        RegistryRouter proxyRouter = RegistryRouter(address(proxy));
        proxyRouter.initialize(admin, address(roboshareTokens), address(partnerManager));
        proxyRouter.setTreasury(address(treasury));
        proxyRouter.grantRole(proxyRouter.AUTHORIZED_REGISTRY_ROLE(), address(assetRegistry));
        roboshareTokens.grantRole(roboshareTokens.MINTER_ROLE(), address(proxyRouter));
        vm.stopPrank();

        vm.prank(address(assetRegistry));
        (assetId,) = proxyRouter.reserveNextTokenIdPair();

        return (proxyRouter, assetId);
    }

    function testCreateListingForMarketplaceNotSet() public {
        (RegistryRouter proxyRouter, uint256 assetId) = _setupRouterWithoutMarketplace();
        uint256 tokenId = TokenLib.getTokenIdFromAssetId(assetId);

        vm.prank(address(assetRegistry));
        vm.expectRevert(RegistryRouter.MarketplaceNotSet.selector);
        proxyRouter.createListingFor(partner1, tokenId, 1, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
    }

    function testMintRevenueTokensAndListForMarketplaceNotSet() public {
        (RegistryRouter proxyRouter,) = _setupRouterWithoutMarketplace();
        vm.startPrank(admin);
        assetRegistry.updateRouter(address(proxyRouter));
        proxyRouter.grantRole(proxyRouter.AUTHORIZED_REGISTRY_ROLE(), address(assetRegistry));
        vm.stopPrank();

        vm.prank(partner1);
        uint256 assetId = assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            ),
            ASSET_VALUE
        );

        vm.prank(address(assetRegistry));
        vm.expectRevert(RegistryRouter.MarketplaceNotSet.selector);
        proxyRouter.mintRevenueTokensAndListFor(
            partner1, assetId, REVENUE_TOKEN_PRICE, block.timestamp + 365 days, 10_000, 1_000, 30 days, true
        );
    }

    function testClearTokenEscrowMarketplaceNotSet() public {
        (RegistryRouter proxyRouter, uint256 assetId) = _setupRouterWithoutMarketplace();
        vm.prank(address(assetRegistry));
        vm.expectRevert(RegistryRouter.MarketplaceNotSet.selector);
        proxyRouter.clearTokenEscrow(assetId);
    }

    function testCreditTokenEscrowMarketplaceNotSet() public {
        (RegistryRouter proxyRouter, uint256 assetId) = _setupRouterWithoutMarketplace();
        vm.prank(address(assetRegistry));
        vm.expectRevert(RegistryRouter.MarketplaceNotSet.selector);
        proxyRouter.creditTokenEscrow(assetId, 10);
    }

    function testBurnRevenueTokensFromEscrowRegistryNotBoundToAsset() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 unboundTokenId = scenario.revenueTokenId + 2;

        vm.prank(address(assetRegistry));
        vm.expectRevert(RegistryRouter.RegistryNotBoundToAsset.selector);
        router.burnRevenueTokensFromEscrow(unboundTokenId);
    }

    function testBurnRevenueTokensFromEscrowMarketplaceNotSet() public {
        (RegistryRouter proxyRouter, uint256 assetId) = _setupRouterWithoutMarketplace();
        uint256 tokenId = TokenLib.getTokenIdFromAssetId(assetId);

        vm.prank(address(assetRegistry));
        vm.expectRevert(RegistryRouter.MarketplaceNotSet.selector);
        proxyRouter.burnRevenueTokensFromEscrow(tokenId);
    }

    function testMintRevenueTokensToEscrowRegistryNotBoundToAsset() public {
        _ensureState(SetupState.RevenueTokensMinted);

        RegistryRouterHarness harness = new RegistryRouterHarness();
        ERC1967Proxy proxy = new ERC1967Proxy(address(harness), "");
        RegistryRouterHarness proxyHarness = RegistryRouterHarness(address(proxy));

        vm.startPrank(admin);
        proxyHarness.initialize(admin, address(roboshareTokens), address(partnerManager));
        proxyHarness.setMarketplace(address(marketplace));
        marketplace.grantRole(marketplace.AUTHORIZED_CONTRACT_ROLE(), address(proxyHarness));
        vm.stopPrank();

        uint256 unboundTokenId = scenario.revenueTokenId + 2;
        vm.expectRevert(RegistryRouter.RegistryNotBoundToAsset.selector);
        proxyHarness.exposeMintRevenueTokensToEscrow(address(assetRegistry), unboundTokenId, 10);
    }

    // Solvency Tests

    function testIsAssetSolvent() public {
        _ensureState(SetupState.RevenueTokensMinted); // Asset 1 is active and solvent by default

        // Initially solvent
        assertTrue(router.isAssetSolvent(scenario.assetId));

        // Get maturity date from RoboshareTokens (now stored in TokenInfo)
        uint256 revenueTokenId = scenario.assetId + 1;
        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(revenueTokenId);

        // Warp to after maturity date to enable liquidation
        vm.warp(maturityDate + 1);

        // Trigger liquidation to make it Expired
        vm.prank(unauthorized); // Anyone can call liquidateAsset
        assetRegistry.liquidateAsset(scenario.assetId);

        // After liquidation, Treasury should reflect non-solvency due to settlement (even if solvent before)
        assertFalse(router.isAssetSolvent(scenario.assetId));
    }

    function testPreviewLiquidationEligibility() public {
        _ensureState(SetupState.RevenueTokensMinted);
        _setupBaseEscrowCredited(ASSET_VALUE);

        (bool eligible, uint8 reason) = router.previewLiquidationEligibility(scenario.assetId);
        assertFalse(eligible);
        assertEq(reason, 3); // NotEligible

        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(scenario.revenueTokenId);
        vm.warp(maturityDate + 1);

        (eligible, reason) = router.previewLiquidationEligibility(scenario.assetId);
        assertTrue(eligible);
        assertEq(reason, 0); // EligibleByMaturity
    }
}
