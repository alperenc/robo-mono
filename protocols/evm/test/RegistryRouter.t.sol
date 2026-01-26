// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { IAssetRegistry } from "../contracts/interfaces/IAssetRegistry.sol";
import { AssetLib } from "../contracts/Libraries.sol";
import { RegistryRouter } from "../contracts/RegistryRouter.sol";

contract RegistryRouterTest is BaseTest {
    function setUp() public {
        _deployContracts();
        _setupInitialRolesAndAccounts();
    }

    function testInitialization() public view {
        assertEq(router.getRegistryType(), "RegistryRouter");
        assertEq(router.getRegistryVersion(), 1);
        assertEq(router.treasury(), address(treasury));

        // Verify role hashes
        assertEq(router.REGISTRY_ADMIN_ROLE(), keccak256("REGISTRY_ADMIN_ROLE"), "Invalid REGISTRY_ADMIN_ROLE hash");
        assertEq(
            router.AUTHORIZED_REGISTRY_ROLE(),
            keccak256("AUTHORIZED_REGISTRY_ROLE"),
            "Invalid AUTHORIZED_REGISTRY_ROLE hash"
        );
        assertEq(router.UPGRADER_ROLE(), keccak256("UPGRADER_ROLE"), "Invalid UPGRADER_ROLE hash");

        // Verify role hierarchy (AUTHORIZED_REGISTRY_ROLE admin should be REGISTRY_ADMIN_ROLE)
        assertEq(
            router.getRoleAdmin(router.AUTHORIZED_REGISTRY_ROLE()),
            router.REGISTRY_ADMIN_ROLE(),
            "Invalid role admin for registry"
        );
        // Verify default admin for other roles
        assertEq(
            router.getRoleAdmin(router.REGISTRY_ADMIN_ROLE()),
            router.DEFAULT_ADMIN_ROLE(),
            "REGISTRY_ADMIN admin should be default"
        );
    }

    function testAuthorizeRegistry() public {
        address newRegistry = makeAddr("newRegistry");

        vm.startPrank(admin);
        router.grantRole(router.AUTHORIZED_REGISTRY_ROLE(), newRegistry);
        vm.stopPrank();

        assertTrue(router.hasRole(router.AUTHORIZED_REGISTRY_ROLE(), newRegistry));
    }

    function testAuthorizeRegistryUnauthorizedCaller() public {
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

    function testSetTreasuryUnauthorizedCaller() public {
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

    function testSetMarketplaceUnauthorizedCaller() public {
        address newMarketplace = makeAddr("newMarketplace");

        vm.startPrank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, router.DEFAULT_ADMIN_ROLE()
            )
        );
        router.setMarketplace(newMarketplace);
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

    function testBindAssetUnauthorizedCaller() public {
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
        assertFalse(router.assetExists(999));
    }

    function testRegisterAssetDirectCall() public {
        vm.expectRevert(RegistryRouter.DirectCallNotAllowed.selector);
        router.registerAsset(bytes(""));
    }

    function testRegisterAssetAndMintTokensDirectCall() public {
        vm.expectRevert(RegistryRouter.DirectCallNotAllowed.selector);
        router.registerAssetAndMintTokens(bytes(""), 100, 100, block.timestamp + 365 days);
    }

    function testRegisterAssetMintAndListDirectCall() public {
        vm.expectRevert(RegistryRouter.DirectCallNotAllowed.selector);
        router.registerAssetMintAndList(bytes(""), 100, 100, 100, 30 days, true);
    }

    function testInitializationZeroAdmin() public {
        RegistryRouter routerImpl = new RegistryRouter();

        vm.expectRevert(RegistryRouter.ZeroAddress.selector);

        new ERC1967Proxy(
            address(routerImpl),
            abi.encodeWithSignature("initialize(address,address)", address(0), address(roboshareTokens))
        );
    }

    function testInitializationZeroTokens() public {
        RegistryRouter routerImpl = new RegistryRouter();

        vm.expectRevert(RegistryRouter.ZeroAddress.selector);

        new ERC1967Proxy(address(routerImpl), abi.encodeWithSignature("initialize(address,address)", admin, address(0)));
    }

    function testGetAssetIdFromTokenIdTokenNotFound() public {
        // Test getAssetIdFromTokenId with non-revenue token (e.g. asset ID itself)
        // Asset ID 1 is not a revenue token
        vm.expectRevert(abi.encodeWithSelector(RegistryRouter.TokenNotFound.selector, 1));
        router.getAssetIdFromTokenId(1);
    }

    function testGetTokenIdFromAssetIdAssetNotFound() public {
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

    function testUpdateRoboshareTokensUnauthorizedCaller() public {
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
