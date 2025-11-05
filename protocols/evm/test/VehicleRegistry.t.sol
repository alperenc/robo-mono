// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";
import "../contracts/interfaces/IAssetRegistry.sol";

contract VehicleRegistryTest is BaseTest {
    function setUp() public {
        _ensureState(SetupState.ContractsDeployed);
    }

    // Initialization Tests

    function testInitialization() public view {
        // Check contract references
        assertEq(address(vehicleRegistry.roboshareTokens()), address(roboshareTokens));
        assertEq(address(vehicleRegistry.partnerManager()), address(partnerManager));

        // Check initial state
        assertEq(vehicleRegistry.getCurrentTokenId(), 1);
        assertFalse(vehicleRegistry.vehicleExists(1));
        assertFalse(vehicleRegistry.vinExists(TEST_VIN));

        // Check admin roles
        assertTrue(vehicleRegistry.hasRole(vehicleRegistry.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(vehicleRegistry.hasRole(vehicleRegistry.UPGRADER_ROLE(), admin));
    }

    function testInitializationWithZeroAddressesFails() public {
        VehicleRegistry newImplementation = new VehicleRegistry();

        // Test zero admin
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address)", address(0), address(roboshareTokens), address(partnerManager)
        );
        vm.expectRevert(VehicleRegistry__ZeroAddress.selector);
        new ERC1967Proxy(address(newImplementation), initData);

        // Test zero tokens
        initData =
            abi.encodeWithSignature("initialize(address,address,address)", admin, address(0), address(partnerManager));
        vm.expectRevert(VehicleRegistry__ZeroAddress.selector);
        new ERC1967Proxy(address(newImplementation), initData);

        // Test zero partner manager
        initData =
            abi.encodeWithSignature("initialize(address,address,address)", admin, address(roboshareTokens), address(0));
        vm.expectRevert(VehicleRegistry__ZeroAddress.selector);
        new ERC1967Proxy(address(newImplementation), initData);
    }

    // Error Case Tests

    function testGetVehicleInfoForNonexistentVehicleFails() public {
        vm.expectRevert(VehicleRegistry__VehicleDoesNotExist.selector);
        vehicleRegistry.getVehicleInfo(999);
    }

    function testGetVehicleDisplayNameForNonexistentVehicleFails() public {
        vm.expectRevert(VehicleRegistry__VehicleDoesNotExist.selector);
        vehicleRegistry.getVehicleDisplayName(999);
    }

    function testTokenIdConversionErrorCases() public {
        vm.expectRevert(VehicleRegistry__IncorrectRevenueTokenId.selector);
        vehicleRegistry.getVehicleIdFromRevenueTokenId(1);

        vm.expectRevert(VehicleRegistry__IncorrectRevenueTokenId.selector);
        vehicleRegistry.getVehicleIdFromRevenueTokenId(0);

        vm.expectRevert(VehicleRegistry__IncorrectVehicleId.selector);
        vehicleRegistry.getRevenueTokenIdFromVehicleId(2);

        vm.expectRevert(VehicleRegistry__IncorrectVehicleId.selector);
        vehicleRegistry.getRevenueTokenIdFromVehicleId(0);
    }


    function testGetTokenIdFromAssetId_AssetType() public {
        _ensureState(SetupState.VehicleWithTokens);
        uint256 tokenId = vehicleRegistry.getTokenIdFromAssetId(scenario.vehicleId, IAssetRegistry.TokenType.Asset);
        assertEq(tokenId, scenario.vehicleId);
    }

    function testIsRevenueTokenTrueFalse() public view {
        assertTrue(vehicleRegistry.isRevenueToken(2));
        assertFalse(vehicleRegistry.isRevenueToken(0));
        assertFalse(vehicleRegistry.isRevenueToken(3));
    }

    function testRegisterVehicle_InvalidVinLengthFails() public {
        _ensureState(SetupState.PartnersAuthorized);
        string memory shortVin = "VIN123"; // <10 length
        vm.expectRevert(VehicleLib__InvalidVINLength.selector);
        vm.prank(partner1);
        vehicleRegistry.registerVehicle(
            shortVin, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );
    }

    function testRegisterVehicle_EmptyMakeFails() public {
        _ensureState(SetupState.PartnersAuthorized);
        vm.expectRevert(VehicleLib__InvalidMake.selector);
        vm.prank(partner1);
        vehicleRegistry.registerVehicle(
            TEST_VIN, "", TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );
    }

    function testRegisterVehicle_EmptyModelFails() public {
        _ensureState(SetupState.PartnersAuthorized);
        vm.expectRevert(VehicleLib__InvalidModel.selector);
        vm.prank(partner1);
        vehicleRegistry.registerVehicle(
            TEST_VIN, TEST_MAKE, "", TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );
    }

    function testRegisterVehicle_InvalidYearFails() public {
        _ensureState(SetupState.PartnersAuthorized);
        vm.expectRevert(VehicleLib__InvalidYear.selector);
        vm.prank(partner1);
        vehicleRegistry.registerVehicle(
            TEST_VIN, TEST_MAKE, TEST_MODEL, 1980, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        vm.expectRevert(VehicleLib__InvalidYear.selector);
        vm.prank(partner1);
        vehicleRegistry.registerVehicle(
            TEST_VIN, TEST_MAKE, TEST_MODEL, 2040, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );
    }

    // New branch coverage for registry view helpers
    function testGetAssetIdFromTokenId_OddAndEven() public {
        _ensureState(SetupState.VehicleWithTokens);
        // Odd token id is vehicle id
        uint256 assetFromVehicle = vehicleRegistry.getAssetIdFromTokenId(scenario.vehicleId);
        assertEq(assetFromVehicle, scenario.vehicleId);

        // Even token id maps back to vehicle id
        uint256 assetFromRevenue = vehicleRegistry.getAssetIdFromTokenId(scenario.revenueTokenId);
        assertEq(assetFromRevenue, scenario.vehicleId);
    }

    function testIsAuthorizedForAsset_Scenarios() public {
        _ensureState(SetupState.VehicleWithTokens);

        // Unauthorized account: not a partner
        assertFalse(vehicleRegistry.isAuthorizedForAsset(unauthorized, scenario.vehicleId));

        // Authorized partner but no ownership
        // partner2 is authorized in BaseTest but doesn't own scenario.vehicleId
        assertFalse(vehicleRegistry.isAuthorizedForAsset(partner2, scenario.vehicleId));

        // Authorized and owns
        assertTrue(vehicleRegistry.isAuthorizedForAsset(partner1, scenario.vehicleId));
    }
}
