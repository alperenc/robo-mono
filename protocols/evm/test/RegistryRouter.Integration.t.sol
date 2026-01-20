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
        uint256 maturityDate = block.timestamp + ONE_YEAR_DAYS * 1 days;
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

    function getAssetIdFromTokenId(uint256 tokenId) external pure override returns (uint256) {
        return tokenId - 1;
    }

    function getTokenIdFromAssetId(uint256 assetId) external pure override returns (uint256) {
        return assetId + 1;
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
        _ensureState(SetupState.ContractsDeployed);

        // Get the router deployed in BaseTest
        // router is already set in BaseTest

        // Deploy MockRegistry
        mockRegistry = new MockRegistry(address(router), address(roboshareTokens), address(treasury));

        // Setup Roles
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

        // Verify ownership transfer
        assertEq(roboshareTokens.balanceOf(buyer, mockTokenId), purchaseAmount);
    }

    function testRegistryNotFoundErrors() public {
        uint256 nonExistentAssetId = INVALID_ASSET_ID;

        // mintRevenueTokens (need maturityDate now)
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFoundForAsset.selector, nonExistentAssetId));
        router.mintRevenueTokens(nonExistentAssetId, DEFAULT_TOKEN_AMOUNT, DEFAULT_TOKEN_AMOUNT, block.timestamp + ONE_YEAR_DAYS * 1 days);

        // getAssetInfo
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFoundForAsset.selector, nonExistentAssetId));
        router.getAssetInfo(nonExistentAssetId);

        // getAssetStatus
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFoundForAsset.selector, nonExistentAssetId));
        router.getAssetStatus(nonExistentAssetId);

        // setAssetStatus
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFoundForAsset.selector, nonExistentAssetId));
        router.setAssetStatus(nonExistentAssetId, AssetLib.AssetStatus.Active);

        // burnRevenueTokens
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFoundForAsset.selector, nonExistentAssetId));
        router.burnRevenueTokens(nonExistentAssetId, 100);

        // retireAsset
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFoundForAsset.selector, nonExistentAssetId));
        router.retireAsset(nonExistentAssetId);

        // retireAssetAndBurnTokens
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFoundForAsset.selector, nonExistentAssetId));
        router.retireAssetAndBurnTokens(nonExistentAssetId);

        // isAuthorizedForAsset
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFoundForAsset.selector, nonExistentAssetId));
        router.isAuthorizedForAsset(partner1, nonExistentAssetId);
    }

    function testCollateralOperationsErrors() public {
        uint256 assetId = 100;
        address unauthorizedRegistry = makeAddr("unauthorizedRegistry");

        // 1. RegistryNotBoundToAsset
        // Grant role but don't bind asset
        vm.startPrank(admin);
        router.grantRole(router.AUTHORIZED_REGISTRY_ROLE(), unauthorizedRegistry);
        vm.stopPrank();

        vm.startPrank(unauthorizedRegistry);
        vm.expectRevert(RegistryRouter.RegistryNotBoundToAsset.selector);
        router.lockCollateralFor(partner1, assetId, 100, 100);

        vm.expectRevert(RegistryRouter.RegistryNotBoundToAsset.selector);
        router.releaseCollateralFor(partner1, assetId);

        vm.expectRevert(RegistryRouter.RegistryNotBoundToAsset.selector);
        router.initiateSettlement(partner1, assetId, 100);

        vm.expectRevert(RegistryRouter.RegistryNotBoundToAsset.selector);
        router.executeLiquidation(assetId);

        vm.expectRevert(RegistryRouter.RegistryNotBoundToAsset.selector);
        router.processSettlementClaim(partner1, assetId, 100);

        vm.stopPrank();

        // 2. TreasuryNotSet
        // Unset treasury (requires admin)
        vm.startPrank(admin);

        // Deploy a fresh router without treasury set
        RegistryRouter freshRouter = new RegistryRouter();
        ERC1967Proxy proxy = new ERC1967Proxy(address(freshRouter), "");
        RegistryRouter(address(proxy)).initialize(admin, address(roboshareTokens));

        // Grant AUTHORIZED_REGISTRY_ROLE to partner1
        RegistryRouter(address(proxy)).grantRole(router.AUTHORIZED_REGISTRY_ROLE(), partner1);
        vm.stopPrank();

        vm.startPrank(partner1);
        // Bind asset
        RegistryRouter(address(proxy)).bindAsset(assetId);

        // Now call lock/release - should revert with TreasuryNotSet
        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        RegistryRouter(address(proxy)).lockCollateralFor(partner1, assetId, 100, 100);

        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        RegistryRouter(address(proxy)).releaseCollateralFor(partner1, assetId);

        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        RegistryRouter(address(proxy)).initiateSettlement(partner1, assetId, 100);

        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        RegistryRouter(address(proxy)).executeLiquidation(assetId);

        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        RegistryRouter(address(proxy)).processSettlementClaim(partner1, assetId, 100);

        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        RegistryRouter(address(proxy)).isAssetSolvent(assetId);

        vm.stopPrank();
    }

    function testTreasuryNotSetErrors() public {
        uint256 assetId = 100;

        // Deploy a fresh router without treasury set
        vm.startPrank(admin);
        RegistryRouter freshRouter = new RegistryRouter();
        ERC1967Proxy proxy = new ERC1967Proxy(address(freshRouter), "");
        RegistryRouter(address(proxy)).initialize(admin, address(roboshareTokens));
        RegistryRouter(address(proxy)).grantRole(router.AUTHORIZED_REGISTRY_ROLE(), partner1);
        vm.stopPrank();

        vm.startPrank(partner1);
        RegistryRouter(address(proxy)).bindAsset(assetId);

        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        RegistryRouter(address(proxy)).isAssetSolvent(assetId);
        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        RegistryRouter(address(proxy)).initiateSettlement(partner1, assetId, 100);
        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        RegistryRouter(address(proxy)).executeLiquidation(assetId);
        vm.expectRevert(RegistryRouter.TreasuryNotSet.selector);
        RegistryRouter(address(proxy)).processSettlementClaim(partner1, assetId, 100);
        vm.stopPrank();
    }

    function testSettlementAndLiquidationErrors() public {
        uint256 nonExistentAssetId = INVALID_ASSET_ID;

        // Assuming assetId 1 is already handled by assetRegistry
        // Revert when calling through Router for non-existent registry
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFoundForAsset.selector, nonExistentAssetId));
        router.settleAsset(nonExistentAssetId, 0);

        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFoundForAsset.selector, nonExistentAssetId));
        router.liquidateAsset(nonExistentAssetId);

        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.RegistryNotFoundForAsset.selector, nonExistentAssetId));
        router.claimSettlement(nonExistentAssetId, false);

        // Test non-existent asset when calling processSettlementClaim/initiateSettlement/executeLiquidation
        // These are handled by RegistryRouter.RegistryNotBoundToAsset, TreasuryNotSet, etc.
        // Already covered in testCollateralOperationsErrors and testTreasuryNotSetErrors
    }

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
        // The assetSettlements in Treasury marks it as settled, so isAssetSolvent should reflect that.
        assertFalse(router.isAssetSolvent(scenario.assetId));
    }
}
