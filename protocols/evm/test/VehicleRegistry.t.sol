// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";

contract VehicleRegistryTest is BaseTest {
    function setUp() public {
        _ensureState(SetupState.ContractsDeployed);
    }

    // Initialization Tests

    function testInitialization() public view {
        // Check contract references
        assertEq(address(assetRegistry.roboshareTokens()), address(roboshareTokens));
        assertEq(address(assetRegistry.partnerManager()), address(partnerManager));

        // Check initial state
        assertFalse(assetRegistry.assetExists(1));
        assertFalse(assetRegistry.vinExists(TEST_VIN));

        // Check admin roles
        assertTrue(assetRegistry.hasRole(assetRegistry.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(assetRegistry.hasRole(assetRegistry.UPGRADER_ROLE(), admin));
    }

    function testInitializationZeroAddresses() public {
        VehicleRegistry newImplementation = new VehicleRegistry();

        // Test zero admin
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address)", address(0), address(roboshareTokens), address(partnerManager)
        );
        vm.expectRevert();
        new ERC1967Proxy(address(newImplementation), initData);

        // Test zero tokens
        initData =
            abi.encodeWithSignature("initialize(address,address,address)", admin, address(0), address(partnerManager));
        vm.expectRevert();
        new ERC1967Proxy(address(newImplementation), initData);

        // Test zero partner manager
        initData =
            abi.encodeWithSignature("initialize(address,address,address)", admin, address(roboshareTokens), address(0));
        vm.expectRevert();
        new ERC1967Proxy(address(newImplementation), initData);
    }

    function testGetAssetInfoNonexistent() public {
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetNotFound.selector, 999));
        assetRegistry.getAssetInfo(999);
    }

    function testGetAssetStatusNonexistent() public {
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetNotFound.selector, 999));
        assetRegistry.getAssetStatus(999);
    }

    // Error Case Tests

    function testGetVehicleInfoNonexistentVehicle() public {
        vm.expectRevert(VehicleRegistry__VehicleDoesNotExist.selector);
        assetRegistry.getVehicleInfo(999);
    }

    function testGetVehicleDisplayNameNonexistentVehicle() public {
        vm.expectRevert(VehicleRegistry__VehicleDoesNotExist.selector);
        assetRegistry.getVehicleDisplayName(999);
    }

    function testTokenIdConversionErrorCases() public {
        vm.expectRevert(VehicleRegistry__IncorrectRevenueTokenId.selector);
        assetRegistry.getAssetIdFromTokenId(1);

        vm.expectRevert(VehicleRegistry__IncorrectRevenueTokenId.selector);
        assetRegistry.getAssetIdFromTokenId(0);

        vm.expectRevert(VehicleRegistry__IncorrectVehicleId.selector);
        assetRegistry.getTokenIdFromAssetId(2);

        vm.expectRevert(VehicleRegistry__IncorrectVehicleId.selector);
        assetRegistry.getTokenIdFromAssetId(0);
    }

    function testRegisterVehicleInvalidVINLength() public {
        _ensureState(SetupState.PartnersAuthorized);
        string memory shortVin = "VIN123"; // <10 length
        vm.expectRevert(VehicleLib.InvalidVINLength.selector);
        vm.prank(partner1);
        assetRegistry.registerAsset(
            abi.encode(
                shortVin, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            )
        );
    }

    function testRegisterVehicleEmptyMake() public {
        _ensureState(SetupState.PartnersAuthorized);
        vm.expectRevert(VehicleLib.InvalidMake.selector);
        vm.prank(partner1);
        assetRegistry.registerAsset(
            abi.encode(TEST_VIN, "", TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI)
        );
    }

    function testRegisterVehicleEmptyModel() public {
        _ensureState(SetupState.PartnersAuthorized);
        vm.expectRevert(VehicleLib.InvalidModel.selector);
        vm.prank(partner1);
        assetRegistry.registerAsset(
            abi.encode(TEST_VIN, TEST_MAKE, "", TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI)
        );
    }

    function testRegisterVehicleInvalidYear() public {
        _ensureState(SetupState.PartnersAuthorized);
        vm.expectRevert(VehicleLib.InvalidYear.selector);
        vm.prank(partner1);
        assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, 1980, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            )
        );

        vm.expectRevert(VehicleLib.InvalidYear.selector);
        vm.prank(partner1);
        assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, 2040, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            )
        );
    }

    // New branch coverage for registry view helpers
    function testGetAssetIdFromTokenId() public {
        _ensureState(SetupState.RevenueTokensMinted);

        uint256 assetFromRevenue = assetRegistry.getAssetIdFromTokenId(scenario.revenueTokenId);
        assertEq(assetFromRevenue, scenario.assetId);
    }

    function testIsAuthorizedForAssetScenarios() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Unauthorized account: not a partner
        assertFalse(assetRegistry.isAuthorizedForAsset(unauthorized, scenario.assetId));

        // Authorized partner but no ownership
        // partner2 is authorized in BaseTest but doesn't own scenario.assetId
        assertFalse(assetRegistry.isAuthorizedForAsset(partner2, scenario.assetId));

        // Authorized and owns
        assertTrue(assetRegistry.isAuthorizedForAsset(partner1, scenario.assetId));
    }

    function testSetAssetStatus() public {
        _ensureState(SetupState.AssetRegistered);
        uint256 assetId = scenario.assetId;

        // Initial status is Pending
        assertEq(uint8(assetRegistry.getAssetStatus(assetId)), uint8(AssetLib.AssetStatus.Pending));

        // Valid transition: Pending -> Active (called by Router)
        vm.startPrank(address(router));
        assetRegistry.setAssetStatus(assetId, AssetLib.AssetStatus.Active);
        vm.stopPrank();

        assertEq(uint8(assetRegistry.getAssetStatus(assetId)), uint8(AssetLib.AssetStatus.Active));
    }

    function testSetAssetStatusUnauthorized() public {
        _ensureState(SetupState.AssetRegistered);
        uint256 assetId = scenario.assetId;

        // Invalid access: unauthorized caller
        vm.startPrank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                assetRegistry.AUTHORIZED_CONTRACT_ROLE()
            )
        );
        assetRegistry.setAssetStatus(assetId, AssetLib.AssetStatus.Pending);
        vm.stopPrank();

        // Invalid access: Treasury (revoked)
        vm.startPrank(address(treasury));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(treasury),
                assetRegistry.AUTHORIZED_CONTRACT_ROLE()
            )
        );
        assetRegistry.setAssetStatus(assetId, AssetLib.AssetStatus.Pending);
        vm.stopPrank();
    }
}
