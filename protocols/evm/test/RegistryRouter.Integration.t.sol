// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";

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
        roboshareTokens.setRevenueTokenInfo(revenueTokenId, price, supply);

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

    function mintRevenueTokens(uint256, uint256, uint256) external pure override returns (uint256) {
        return 0;
    }

    function registerAssetAndMintTokens(bytes calldata, uint256, uint256)
        external
        pure
        override
        returns (uint256, uint256)
    {
        return (0, 0);
    }

    function setAssetStatus(uint256, AssetLib.AssetStatus) external override { }
    function burnRevenueTokens(uint256, uint256) external override { }
    function retireAsset(uint256) external override { }
    function retireAssetAndBurnTokens(uint256) external override { }

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
}
