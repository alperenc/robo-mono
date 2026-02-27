// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { AssetLib } from "../contracts/Libraries.sol";
import { MockUSDC } from "../contracts/mocks/MockUSDC.sol";
import { RoboshareTokens } from "../contracts/RoboshareTokens.sol";
import { PartnerManager } from "../contracts/PartnerManager.sol";
import { RegistryRouter } from "../contracts/RegistryRouter.sol";
import { Treasury } from "../contracts/Treasury.sol";
import { Marketplace } from "../contracts/Marketplace.sol";

contract MarketplaceBadTotalSupplyToken {
    function totalSupply() external pure returns (uint256) {
        revert("bad totalSupply");
    }
}

contract MarketplaceBadDecimalsToken {
    function totalSupply() external pure returns (uint256) {
        return 1;
    }

    function decimals() external pure returns (uint8) {
        revert("bad decimals");
    }
}

contract MarketplaceWrongDecimalsToken {
    function totalSupply() external pure returns (uint256) {
        return 1;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }
}

contract MarketplaceTest is BaseTest {
    function setUp() public {
        _ensureState(SetupState.ContractsDeployed);
    }

    function _registerAssetAndPrepareRevenueToken()
        internal
        returns (uint256 assetId, uint256 tokenId, uint256 supply)
    {
        _ensureState(SetupState.InitialAccountsSetup);
        vm.prank(partner1);
        assetId = assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            ),
            ASSET_VALUE
        );
        tokenId = assetId + 1;
        supply = ASSET_VALUE / REVENUE_TOKEN_PRICE;
        vm.prank(address(router));
        roboshareTokens.setRevenueTokenInfo(
            tokenId, REVENUE_TOKEN_PRICE, supply, block.timestamp + 365 days, 10_000, 1_000
        );
    }

    // Initialization Tests

    function testInitialization() public view {
        // Check contract references
        assertEq(address(marketplace.roboshareTokens()), address(roboshareTokens));
        assertEq(address(marketplace.partnerManager()), address(partnerManager));
        assertEq(address(marketplace.router()), address(router));
        assertEq(address(marketplace.treasury()), address(treasury));
        assertEq(address(marketplace.usdc()), address(usdc));

        // Check initial state
        assertEq(marketplace.getCurrentListingId(), 1);

        // Check roles
        assertTrue(marketplace.hasRole(marketplace.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(marketplace.hasRole(marketplace.UPGRADER_ROLE(), admin));

        // Verify role hashes
        assertEq(marketplace.UPGRADER_ROLE(), keccak256("UPGRADER_ROLE"), "Invalid UPGRADER_ROLE hash");
        assertEq(
            marketplace.AUTHORIZED_CONTRACT_ROLE(),
            keccak256("AUTHORIZED_CONTRACT_ROLE"),
            "Invalid AUTHORIZED_CONTRACT_ROLE hash"
        );
    }

    function testInitializationZeroAdmin() public {
        Marketplace newImpl = new Marketplace();
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address)",
                address(0),
                address(roboshareTokens),
                address(partnerManager),
                address(router),
                address(treasury),
                address(usdc)
            )
        );
    }

    function testInitializationZeroTokens() public {
        Marketplace newImpl = new Marketplace();
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address)",
                admin,
                address(0),
                address(partnerManager),
                address(router),
                address(treasury),
                address(usdc)
            )
        );
    }

    function testInitializationZeroPartnerManager() public {
        Marketplace newImpl = new Marketplace();
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address)",
                admin,
                address(roboshareTokens),
                address(0),
                address(router),
                address(treasury),
                address(usdc)
            )
        );
    }

    function testInitializationZeroRouter() public {
        Marketplace newImpl = new Marketplace();
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address)",
                admin,
                address(roboshareTokens),
                address(partnerManager),
                address(0),
                address(treasury),
                address(usdc)
            )
        );
    }

    function testInitializationZeroTreasury() public {
        Marketplace newImpl = new Marketplace();
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address)",
                admin,
                address(roboshareTokens),
                address(partnerManager),
                address(router),
                address(0),
                address(usdc)
            )
        );
    }

    function testInitializationZeroUSDC() public {
        Marketplace newImpl = new Marketplace();
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address)",
                admin,
                address(roboshareTokens),
                address(partnerManager),
                address(router),
                address(treasury),
                address(0)
            )
        );
    }

    // Admin Functions Tests

    function testUpdatePartnerManager() public {
        PartnerManager newPartnerManager = new PartnerManager();

        vm.startPrank(admin);
        marketplace.updatePartnerManager(address(newPartnerManager));
        vm.stopPrank();

        assertEq(address(marketplace.partnerManager()), address(newPartnerManager));
    }

    function testUpdatePartnerManagerZeroAddress() public {
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        vm.startPrank(admin);
        marketplace.updatePartnerManager(address(0));
        vm.stopPrank();
    }

    function testUpdatePartnerManagerUnauthorizedCaller() public {
        PartnerManager newPartnerManager = new PartnerManager();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, marketplace.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(unauthorized);
        marketplace.updatePartnerManager(address(newPartnerManager));
    }

    function testUpdateRouter() public {
        RegistryRouter newRouter = new RegistryRouter();

        vm.startPrank(admin);
        marketplace.updateRouter(address(newRouter));
        vm.stopPrank();

        assertEq(address(marketplace.router()), address(newRouter));
    }

    function testUpdateRouterZeroAddress() public {
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        vm.startPrank(admin);
        marketplace.updateRouter(address(0));
        vm.stopPrank();
    }

    function testUpdateRouterUnauthorizedCaller() public {
        RegistryRouter newRouter = new RegistryRouter();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, marketplace.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(unauthorized);
        marketplace.updateRouter(address(newRouter));
    }

    function testUpdateUSDC() public {
        MockUSDC newUsdc = new MockUSDC();

        vm.startPrank(admin);
        marketplace.updateUSDC(address(newUsdc));
        vm.stopPrank();

        assertEq(address(marketplace.usdc()), address(newUsdc));
    }

    function testUpdateUSDCZeroAddress() public {
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        vm.startPrank(admin);
        marketplace.updateUSDC(address(0));
        vm.stopPrank();
    }

    function testUpdateUSDCUnauthorizedCaller() public {
        MockUSDC newUsdc = new MockUSDC();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, marketplace.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(unauthorized);
        marketplace.updateUSDC(address(newUsdc));
    }

    function testUpdateUSDCInvalidContractTotalSupplyReverts() public {
        MarketplaceBadTotalSupplyToken bad = new MarketplaceBadTotalSupplyToken();

        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.InvalidUSDCContract.selector, address(bad)));
        marketplace.updateUSDC(address(bad));
        vm.stopPrank();
    }

    function testUpdateUSDCInvalidContractDecimalsReverts() public {
        MarketplaceBadDecimalsToken bad = new MarketplaceBadDecimalsToken();

        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.InvalidUSDCContract.selector, address(bad)));
        marketplace.updateUSDC(address(bad));
        vm.stopPrank();
    }

    function testUpdateUSDCUnsupportedUSDCDecimalsReverts() public {
        MarketplaceWrongDecimalsToken bad = new MarketplaceWrongDecimalsToken();

        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.UnsupportedUSDCDecimals.selector, uint8(18)));
        marketplace.updateUSDC(address(bad));
        vm.stopPrank();
    }

    function testUpdateRoboshareTokens() public {
        RoboshareTokens newRoboshareTokens = new RoboshareTokens();

        vm.startPrank(admin);
        marketplace.updateRoboshareTokens(address(newRoboshareTokens));
        vm.stopPrank();

        assertEq(address(marketplace.roboshareTokens()), address(newRoboshareTokens));
    }

    function testUpdateRoboshareTokensZeroAddress() public {
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        vm.startPrank(admin);
        marketplace.updateRoboshareTokens(address(0));
        vm.stopPrank();
    }

    function testUpdateRoboshareTokensUnauthorizedCaller() public {
        RoboshareTokens newRoboshareTokens = new RoboshareTokens();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, marketplace.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(unauthorized);
        marketplace.updateRoboshareTokens(address(newRoboshareTokens));
    }

    function testUpdateTreasury() public {
        Treasury newTreasury = new Treasury();

        vm.startPrank(admin);
        marketplace.updateTreasury(address(newTreasury));
        vm.stopPrank();

        assertEq(address(marketplace.treasury()), address(newTreasury));
    }

    function testUpdateTreasuryZeroAddress() public {
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        vm.startPrank(admin);
        marketplace.updateTreasury(address(0));
        vm.stopPrank();
    }

    function testUpdateTreasuryUnauthorizedCaller() public {
        Treasury newTreasury = new Treasury();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, marketplace.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(unauthorized);
        marketplace.updateTreasury(address(newTreasury));
    }

    function testCreatePrimaryPoolStandaloneLifecycle() public {
        (uint256 assetId, uint256 tokenId, uint256 supply) = _registerAssetAndPrepareRevenueToken();
        assertFalse(marketplace.isPrimaryPoolActive(tokenId));

        vm.prank(partner1);
        vm.expectRevert(Marketplace.AssetNotEligibleForListing.selector);
        marketplace.createPrimaryPool(tokenId, REVENUE_TOKEN_PRICE, supply, false, false);

        vm.prank(address(router));
        assetRegistry.setAssetStatus(assetId, AssetLib.AssetStatus.Active);

        vm.prank(partner2);
        vm.expectRevert(Marketplace.NotPoolPartner.selector);
        marketplace.createPrimaryPool(tokenId, REVENUE_TOKEN_PRICE, supply, false, false);

        vm.prank(partner1);
        marketplace.createPrimaryPool(tokenId, REVENUE_TOKEN_PRICE, supply, false, false);
        assertTrue(marketplace.isPrimaryPoolActive(tokenId));

        vm.prank(partner1);
        vm.expectRevert(Marketplace.PrimaryPoolAlreadyCreated.selector);
        marketplace.createPrimaryPool(tokenId, REVENUE_TOKEN_PRICE, supply, false, false);

        vm.prank(partner1);
        marketplace.pausePrimaryPool(tokenId);
        assertFalse(marketplace.isPrimaryPoolActive(tokenId));

        vm.prank(unauthorized);
        vm.expectRevert(Marketplace.NotPoolPartner.selector);
        marketplace.unpausePrimaryPool(tokenId);

        vm.prank(partner1);
        marketplace.unpausePrimaryPool(tokenId);
        assertTrue(marketplace.isPrimaryPoolActive(tokenId));

        vm.prank(partner1);
        marketplace.closePrimaryPool(tokenId);
        assertFalse(marketplace.isPrimaryPoolActive(tokenId));

        vm.prank(partner1);
        vm.expectRevert(Marketplace.PrimaryPoolAlreadyClosed.selector);
        marketplace.closePrimaryPool(tokenId);
    }

    function testCreatePrimaryPoolInvalidRevenueTokenReverts() public {
        _ensureState(SetupState.AssetRegistered);
        vm.prank(partner1);
        vm.expectRevert(Marketplace.InvalidTokenType.selector);
        marketplace.createPrimaryPool(scenario.assetId, REVENUE_TOKEN_PRICE, 100, false, false);
    }

    function testCreatePrimaryPoolValidationAndClosedStateBranches() public {
        (uint256 assetId, uint256 tokenId,) = _registerAssetAndPrepareRevenueToken();

        vm.prank(address(router));
        assetRegistry.setAssetStatus(assetId, AssetLib.AssetStatus.Active);

        vm.prank(partner1);
        vm.expectRevert(Marketplace.InvalidPrice.selector);
        marketplace.createPrimaryPool(tokenId, 0, 100, false, false);

        vm.prank(partner1);
        vm.expectRevert(Marketplace.InvalidMaxSupply.selector);
        marketplace.createPrimaryPool(tokenId, REVENUE_TOKEN_PRICE, 0, false, false);

        vm.prank(partner1);
        marketplace.createPrimaryPool(tokenId, REVENUE_TOKEN_PRICE, 100, false, false);

        vm.prank(partner1);
        marketplace.closePrimaryPool(tokenId);

        vm.prank(partner1);
        vm.expectRevert(Marketplace.PrimaryPoolAlreadyClosed.selector);
        marketplace.pausePrimaryPool(tokenId);

        vm.prank(partner1);
        vm.expectRevert(Marketplace.PrimaryPoolAlreadyClosed.selector);
        marketplace.unpausePrimaryPool(tokenId);

        (uint256 totalCost, uint256 protocolFee, uint256 partnerProceeds, uint256 protectionFunding) =
            marketplace.previewPrimaryPurchase(tokenId, 0);
        assertEq(totalCost, 0);
        assertEq(protocolFee, 0);
        assertEq(partnerProceeds, 0);
        assertEq(protectionFunding, 0);
    }

    function testPrimaryPoolNotFoundReverts() public {
        vm.expectRevert(Marketplace.PrimaryPoolNotFound.selector);
        marketplace.pausePrimaryPool(999_999);
    }

    function testPreviewPrimaryPurchaseImmediateProceedsBranch() public {
        (uint256 assetId, uint256 tokenId,) = _registerAssetAndPrepareRevenueToken();
        vm.prank(address(router));
        assetRegistry.setAssetStatus(assetId, AssetLib.AssetStatus.Active);
        vm.prank(partner1);
        marketplace.createPrimaryPool(tokenId, REVENUE_TOKEN_PRICE, 100, true, false);

        (uint256 totalCost, uint256 protocolFee, uint256 partnerProceeds,) =
            marketplace.previewPrimaryPurchase(tokenId, 1);
        assertGt(totalCost, 0);
        assertGt(protocolFee, 0);
        assertEq(partnerProceeds, REVENUE_TOKEN_PRICE);
    }

    function testRedeemPrimaryPoolInvalidAmountReverts() public {
        _ensureState(SetupState.RevenueTokensPurchased);
        vm.prank(buyer);
        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.redeemPrimaryPool(scenario.revenueTokenId, 0, 0);
    }

    function testClearTokenEscrowWhenAmountExists() public {
        uint256 tokenId = 12345;
        vm.prank(address(router));
        marketplace.creditTokenEscrow(tokenId, 5);

        vm.prank(address(router));
        uint256 cleared = marketplace.clearTokenEscrow(tokenId);
        assertEq(cleared, 5);
    }

    function testBuyFromPrimaryPoolValidationReverts() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.prank(partner1);
        marketplace.pausePrimaryPool(scenario.revenueTokenId);

        vm.prank(buyer);
        vm.expectRevert(Marketplace.PrimaryPoolNotActive.selector);
        marketplace.buyFromPrimaryPool(scenario.revenueTokenId, 1);

        vm.prank(partner1);
        marketplace.unpausePrimaryPool(scenario.revenueTokenId);

        vm.prank(buyer);
        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.buyFromPrimaryPool(scenario.revenueTokenId, 0);

        vm.prank(address(router));
        assetRegistry.setAssetStatus(scenario.assetId, AssetLib.AssetStatus.Suspended);
        vm.prank(buyer);
        vm.expectRevert(Marketplace.AssetNotActive.selector);
        marketplace.buyFromPrimaryPool(scenario.revenueTokenId, 1);

        vm.prank(address(router));
        assetRegistry.setAssetStatus(scenario.assetId, AssetLib.AssetStatus.Active);

        vm.prank(buyer);
        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.buyFromPrimaryPool(scenario.revenueTokenId, (ASSET_VALUE / REVENUE_TOKEN_PRICE) + 1);

        deal(address(usdc), buyer, 0);
        vm.prank(buyer);
        vm.expectRevert(Marketplace.InsufficientPayment.selector);
        marketplace.buyFromPrimaryPool(scenario.revenueTokenId, 1);
    }

    function testPrimaryRedemptionPreviewAndRedeem() public {
        _ensureState(SetupState.RevenueTokensPurchased);
        uint256 burnAmount = PURCHASE_AMOUNT / 2;

        (uint256 previewPayout,, uint256 circulatingSupply) =
            marketplace.previewPrimaryRedemption(scenario.revenueTokenId, burnAmount);
        assertGt(previewPayout, 0);
        assertGt(circulatingSupply, 0);

        uint256 buyerUsdcBefore = usdc.balanceOf(buyer);
        uint256 buyerTokensBefore = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);

        vm.prank(buyer);
        uint256 payout = marketplace.redeemPrimaryPool(scenario.revenueTokenId, burnAmount, previewPayout);
        assertEq(payout, previewPayout);

        assertEq(roboshareTokens.balanceOf(buyer, scenario.revenueTokenId), buyerTokensBefore - burnAmount);
        assertEq(usdc.balanceOf(buyer), buyerUsdcBefore + payout);
    }

    function testPreviewPrimaryRedemptionZeroAmountAndInactivePoolReverts() public {
        _ensureState(SetupState.RevenueTokensMinted);
        (uint256 payout, uint256 liquidity, uint256 supply) =
            marketplace.previewPrimaryRedemption(scenario.revenueTokenId, 0);
        assertEq(payout, 0);
        assertEq(liquidity, 0);
        assertEq(supply, 0);

        vm.prank(partner1);
        marketplace.closePrimaryPool(scenario.revenueTokenId);

        vm.prank(buyer);
        vm.expectRevert(Marketplace.PrimaryPoolNotActive.selector);
        marketplace.redeemPrimaryPool(scenario.revenueTokenId, 1, 0);
    }

    function testRedeemPrimaryPoolAssetNotOperationalReverts() public {
        _ensureState(SetupState.RevenueTokensPurchased);
        vm.prank(address(router));
        assetRegistry.setAssetStatus(scenario.assetId, AssetLib.AssetStatus.Suspended);

        vm.prank(buyer);
        vm.expectRevert(Marketplace.AssetNotActive.selector);
        marketplace.redeemPrimaryPool(scenario.revenueTokenId, 1, 0);
    }

    function testOnERC1155BatchReceivedSelector() public {
        bytes4 selector = marketplace.onERC1155BatchReceived(
            address(this), address(0xBEEF), new uint256[](0), new uint256[](0), ""
        );
        assertEq(selector, marketplace.onERC1155BatchReceived.selector);
    }

    function testUpgradeUnauthorizedCaller() public {
        Marketplace newImpl = new Marketplace();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, marketplace.UPGRADER_ROLE()
            )
        );
        vm.prank(unauthorized);
        marketplace.upgradeToAndCall(address(newImpl), "");
    }
}
