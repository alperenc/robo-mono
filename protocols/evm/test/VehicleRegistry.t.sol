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
}
