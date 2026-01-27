// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { AssetLib } from "../contracts/Libraries.sol";
import { IAssetRegistry } from "../contracts/interfaces/IAssetRegistry.sol";
import { RoboshareTokens } from "../contracts/RoboshareTokens.sol";
import { RegistryRouter } from "../contracts/RegistryRouter.sol";
import { Treasury } from "../contracts/Treasury.sol";

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

    function registerAndMint(address partner, uint256 supply, uint256 price)
        external
        returns (uint256 assetId, uint256 revenueTokenId)
    {
        // 1. Reserve IDs from Router (this binds the assetId to this registry in the Router)
        (assetId, revenueTokenId) = router.reserveNextTokenIdPair();

        // 2. Initialize local state
        assets[assetId].id = assetId;
        assets[assetId].info.status = AssetLib.AssetStatus.Active;
        assets[assetId].info.createdAt = block.timestamp;
        assets[assetId].info.updatedAt = block.timestamp;

        // 3. Setup Token Info & Lock Collateral
        uint256 maturityDate = block.timestamp + 365 days;
        roboshareTokens.setRevenueTokenInfo(revenueTokenId, price, supply, maturityDate);

        // Mint Asset NFT first so partner owns it for collateral locking
        roboshareTokens.mint(partner, assetId, 1, "");

        // Lock Collateral (Requires partner to have approved Treasury)
        router.lockCollateralFor(partner, assetId, price, supply);

        // 4. Mint revenue tokens
        roboshareTokens.mint(partner, revenueTokenId, supply, "");

        return (assetId, revenueTokenId);
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

    function isAuthorizedForAsset(address account, uint256 assetId) external view override returns (bool) {
        return roboshareTokens.balanceOf(account, assetId) > 0;
    }

    // Stubs for other functions
    function registerAsset(bytes calldata) external pure override returns (uint256) {
        return 0;
    }

    function mintRevenueTokens(uint256, uint256, uint256, uint256) external pure override returns (uint256) {
        return 0;
    }

    function registerAssetAndMintTokens(bytes calldata, uint256, uint256, uint256)
        external
        pure
        override
        returns (uint256, uint256)
    {
        return (0, 0);
    }

    function registerAssetMintAndList(bytes calldata, uint256, uint256, uint256, uint256, bool)
        external
        pure
        override
        returns (uint256, uint256, uint256)
    {
        return (0, 0, 0);
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

        // Approve Treasury to pull collateral
        uint256 collateral = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        usdc.approve(address(treasury), collateral);

        (uint256 mockAssetId, uint256 mockTokenId) =
            mockRegistry.registerAndMint(partner1, REVENUE_TOKEN_SUPPLY, REVENUE_TOKEN_PRICE);
        vm.stopPrank();

        // Verify IDs
        assertEq(mockAssetId, 3);
        assertEq(mockTokenId, 4);

        // Verify Router knows about MockRegistry
        assertEq(router.getRegistryForAsset(mockAssetId), address(mockRegistry));

        // 3. List Mock Token on Marketplace
        // Marketplace uses Router to find registry, then registry to get asset info/status/collateral
        vm.startPrank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.createListing(mockTokenId, 100, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
        vm.stopPrank();

        // 4. Purchase Mock Token
        uint256 purchaseAmount = 10;
        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(listingId, purchaseAmount);

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(listingId, purchaseAmount);
        vm.stopPrank();

        // 5. End Listing and Claim Tokens (New Escrow Flow)
        vm.prank(partner1);
        marketplace.endListing(listingId);

        vm.prank(buyer);
        marketplace.claimTokens(listingId);

        // Verify ownership transfer
        assertEq(roboshareTokens.balanceOf(buyer, mockTokenId), purchaseAmount);
    }

    // RegistryNotFound Tests

    function testMintRevenueTokensRegistryNotFound() public {
        uint256 nonExistentAssetId = 999;
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, nonExistentAssetId));
        router.mintRevenueTokens(nonExistentAssetId, 100, 100, block.timestamp + 365 days);
    }

    function testGetAssetInfoRegistryNotFound() public {
        uint256 nonExistentAssetId = 999;
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, nonExistentAssetId));
        router.getAssetInfo(nonExistentAssetId);
    }

    function testGetAssetStatusRegistryNotFound() public {
        uint256 nonExistentAssetId = 999;
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, nonExistentAssetId));
        router.getAssetStatus(nonExistentAssetId);
    }

    function testSetAssetStatusRegistryNotFound() public {
        uint256 nonExistentAssetId = 999;
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, nonExistentAssetId));
        router.setAssetStatus(nonExistentAssetId, AssetLib.AssetStatus.Active);
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

    function testIsAuthorizedForAssetRegistryNotFound() public {
        uint256 nonExistentAssetId = 999;
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, nonExistentAssetId));
        router.isAuthorizedForAsset(partner1, nonExistentAssetId);
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

    function testClaimSettlementRegistryNotFound() public {
        uint256 nonExistentAssetId = 999;
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFound.selector, nonExistentAssetId));
        router.claimSettlement(nonExistentAssetId, false);
    }

    // RegistryNotBoundToAsset Tests

    function testLockCollateralForRegistryNotBoundToAsset() public {
        uint256 assetId = 100;
        address unauthorizedRegistry = makeAddr("unauthorizedRegistry");

        vm.startPrank(admin);
        router.grantRole(router.AUTHORIZED_REGISTRY_ROLE(), unauthorizedRegistry);
        vm.stopPrank();

        vm.prank(unauthorizedRegistry);
        vm.expectRevert(RegistryRouter.RegistryNotBoundToAsset.selector);
        router.lockCollateralFor(partner1, assetId, 100, 100);
    }

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

    function _setupRouterWithoutTreasury() internal returns (RegistryRouter) {
        vm.startPrank(admin);
        RegistryRouter freshRouter = new RegistryRouter();
        ERC1967Proxy proxy = new ERC1967Proxy(address(freshRouter), "");
        RegistryRouter proxyRouter = RegistryRouter(address(proxy));
        proxyRouter.initialize(admin, address(roboshareTokens));
        proxyRouter.grantRole(router.AUTHORIZED_REGISTRY_ROLE(), partner1);
        vm.stopPrank();

        vm.prank(partner1);
        proxyRouter.bindId(100);

        return proxyRouter;
    }

    function testLockCollateralForTreasuryNotSet() public {
        RegistryRouter proxyRouter = _setupRouterWithoutTreasury();
        vm.prank(partner1);
        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        proxyRouter.lockCollateralFor(partner1, 100, 100, 100);
    }

    function testReleaseCollateralForTreasuryNotSet() public {
        RegistryRouter proxyRouter = _setupRouterWithoutTreasury();
        vm.prank(partner1);
        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        proxyRouter.releaseCollateralFor(partner1, 100);
    }

    function testIsAssetSolventTreasuryNotSet() public {
        RegistryRouter proxyRouter = _setupRouterWithoutTreasury();
        vm.prank(partner1);
        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        proxyRouter.isAssetSolvent(100);
    }

    function testInitiateSettlementTreasuryNotSet() public {
        RegistryRouter proxyRouter = _setupRouterWithoutTreasury();
        vm.prank(partner1);
        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        proxyRouter.initiateSettlement(partner1, 100, 100);
    }

    function testExecuteLiquidationTreasuryNotSet() public {
        RegistryRouter proxyRouter = _setupRouterWithoutTreasury();
        vm.prank(partner1);
        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        proxyRouter.executeLiquidation(100);
    }

    function testProcessSettlementClaimTreasuryNotSet() public {
        RegistryRouter proxyRouter = _setupRouterWithoutTreasury();
        vm.prank(partner1);
        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        proxyRouter.processSettlementClaim(partner1, 100, 100);
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
}
