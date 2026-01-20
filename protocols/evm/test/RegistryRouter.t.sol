// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { IAssetRegistry } from "../contracts/interfaces/IAssetRegistry.sol";
import { AssetLib } from "../contracts/Libraries.sol";
import { RegistryRouter } from "../contracts/RegistryRouter.sol";

contract RegistryRouterTest is BaseTest {
    RegistryRouter public newRouter;

    function setUp() public {
        _deployContracts();
        _setupInitialRolesAndPartners();
    }

    function testInitialState() public view {
        assertEq(router.getRegistryType(), "RegistryRouter");
        assertEq(router.getRegistryVersion(), 1);
        assertEq(router.treasury(), address(treasury));
    }

    function testAuthorizeRegistry() public {
        address newRegistry = makeAddr("newRegistry");

        vm.startPrank(admin);
        router.grantRole(router.AUTHORIZED_REGISTRY_ROLE(), newRegistry);
        vm.stopPrank();

        assertTrue(router.hasRole(router.AUTHORIZED_REGISTRY_ROLE(), newRegistry));
    }

    function testAuthorizeRegistryUnauthorized() public {
        address newRegistry = makeAddr("newRegistry");

        bytes32 registryManagerRole = router.REGISTRY_ADMIN_ROLE();
        bytes32 authorizedRegistryRole = router.AUTHORIZED_REGISTRY_ROLE();

        vm.startPrank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, registryManagerRole
            )
        );
        router.grantRole(authorizedRegistryRole, newRegistry);
        vm.stopPrank();
    }

    function testDeauthorizeRegistry() public {
        address newRegistry = makeAddr("newRegistry");

        vm.startPrank(admin);
        router.grantRole(router.AUTHORIZED_REGISTRY_ROLE(), newRegistry);
        assertTrue(router.hasRole(router.AUTHORIZED_REGISTRY_ROLE(), newRegistry));

        router.revokeRole(router.AUTHORIZED_REGISTRY_ROLE(), newRegistry);
        assertFalse(router.hasRole(router.AUTHORIZED_REGISTRY_ROLE(), newRegistry));
        vm.stopPrank();
    }

    function testSetTreasury() public {
        address newTreasury = makeAddr("newTreasury");

        vm.startPrank(admin);
        router.setTreasury(newTreasury);
        vm.stopPrank();

        assertEq(router.treasury(), newTreasury);
    }

    function testSetTreasuryZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.ZeroAddress.selector));
        router.setTreasury(address(0));
        vm.stopPrank();

        assertEq(router.treasury(), address(treasury));
    }

    function testSetTreasuryUnauthorized() public {
        address newTreasury = makeAddr("newTreasury");

        vm.startPrank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, router.DEFAULT_ADMIN_ROLE()
            )
        );
        router.setTreasury(newTreasury);
        vm.stopPrank();
    }

    function testSetMarketplace() public {
        address newMarketplace = makeAddr("newMarketplace");

        vm.startPrank(admin);
        router.setMarketplace(newMarketplace);
        vm.stopPrank();

        assertEq(router.marketplace(), newMarketplace);
    }

    function testSetMarketplaceZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.ZeroAddress.selector));
        router.setMarketplace(address(0));
        vm.stopPrank();
    }

    function testBindAsset() public {
        address newRegistry = makeAddr("newRegistry");
        uint256 assetId = 100;

        vm.startPrank(admin);
        router.grantRole(router.AUTHORIZED_REGISTRY_ROLE(), newRegistry);
        vm.stopPrank();

        vm.startPrank(newRegistry);
        router.bindAsset(assetId);
        vm.stopPrank();

        assertEq(router.assetIdToRegistry(assetId), newRegistry);
    }

    function testBindAssetUnauthorizedRegistry() public {
        uint256 assetId = 100;

        vm.startPrank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                router.AUTHORIZED_REGISTRY_ROLE()
            )
        );
        router.bindAsset(assetId);
        vm.stopPrank();
    }

    function testReserveNextTokenIdPair() public {
        address newRegistry = makeAddr("newRegistry");

        vm.startPrank(admin);
        router.grantRole(router.AUTHORIZED_REGISTRY_ROLE(), newRegistry);
        vm.stopPrank();

        vm.startPrank(newRegistry);
        (uint256 assetId, uint256 revenueTokenId) = router.reserveNextTokenIdPair();
        vm.stopPrank();

        assertGt(assetId, 0);
        assertEq(revenueTokenId, assetId + 1);
        assertEq(router.assetIdToRegistry(assetId), newRegistry);
    }

    function testRoutingGetAssetInfo() public {
        // Register asset via VehicleRegistry (which calls router)
        vm.prank(partner1);
        uint256 assetId = assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            )
        );

        // Call via Router
        AssetLib.AssetInfo memory info = router.getAssetInfo(assetId);
        assertEq(uint8(info.status), uint8(AssetLib.AssetStatus.Pending));
    }

    function testRoutingAssetExists() public {
        vm.prank(partner1);
        uint256 assetId = assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            )
        );

        assertTrue(router.assetExists(assetId));
        assertFalse(router.assetExists(INVALID_ASSET_ID));
    }

    function testDirectCallNotAllowed() public {
        vm.expectRevert(RegistryRouter.DirectCallNotAllowed.selector);
        router.registerAsset(bytes(""));

        vm.expectRevert(RegistryRouter.DirectCallNotAllowed.selector);
        router.registerAssetAndMintTokens(bytes(""), DEFAULT_TOKEN_AMOUNT, DEFAULT_TOKEN_AMOUNT, block.timestamp + ONE_YEAR_DAYS * 1 days);
    }

    function testInitializationZeroAddresses() public {
        RegistryRouter newImplementation = new RegistryRouter();

        // Test zero admin
        bytes memory initData =
            abi.encodeWithSignature("initialize(address,address)", address(0), address(roboshareTokens));
        vm.expectRevert(RegistryRouter.ZeroAddress.selector);
        new ERC1967Proxy(address(newImplementation), initData);

        // Test zero tokens
        initData = abi.encodeWithSignature("initialize(address,address)", admin, address(0));
        vm.expectRevert(RegistryRouter.ZeroAddress.selector);
        new ERC1967Proxy(address(newImplementation), initData);
    }

    function testTokenIdConversionErrorCases() public {
        // Test getAssetIdFromTokenId with non-revenue token (e.g. asset ID itself)
        // Asset ID 1 is not a revenue token
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.TokenNotFound.selector, 1));
        router.getAssetIdFromTokenId(1);

        // Test getTokenIdFromAssetId with revenue token ID
        // Revenue Token ID 2 is not an asset ID
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetNotFound.selector, 2));
        router.getTokenIdFromAssetId(2);
    }

    // ============ Admin Function Tests ============

    function testUpdateRoboshareTokens() public {
        address newTokens = makeAddr("newRoboshareTokens");
        address oldTokens = address(router.roboshareTokens());

        vm.prank(admin);
        vm.expectEmit(true, true, false, false);
        emit RegistryRouter.RoboshareTokensUpdated(oldTokens, newTokens);
        router.updateRoboshareTokens(newTokens);

        assertEq(address(router.roboshareTokens()), newTokens);
    }

    function testUpdateRoboshareTokensZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(RegistryRouter.ZeroAddress.selector);
        router.updateRoboshareTokens(address(0));
    }

    function testUpdateRoboshareTokensUnauthorized() public {
        address newTokens = makeAddr("newRoboshareTokens");

        vm.startPrank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, router.DEFAULT_ADMIN_ROLE()
            )
        );
        router.updateRoboshareTokens(newTokens);
        vm.stopPrank();
    }
}
