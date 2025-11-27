// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";
import "../contracts/RegistryRouter.sol";

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
        assertFalse(router.assetExists(999));
    }

    function testDirectCallNotAllowed() public {
        vm.expectRevert(RegistryRouter__DirectCallNotAllowed.selector);
        router.registerAsset(bytes(""));

        vm.expectRevert(RegistryRouter__DirectCallNotAllowed.selector);
        router.registerAssetAndMintTokens(bytes(""), 100, 100);
    }
}
