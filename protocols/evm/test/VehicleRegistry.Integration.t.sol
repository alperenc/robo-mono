// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";

contract VehicleRegistryIntegrationTest is BaseTest {
    function setUp() public {
        _ensureState(SetupState.PartnersAuthorized);
    }

    // Vehicle Registration Tests

    function testRegisterVehicle() public {
        vm.expectEmit(true, true, false, true);
        emit VehicleRegistry.VehicleRegistered(1, partner1, TEST_VIN);

        vm.prank(partner1);
        uint256 newVehicleId = vehicleRegistry.registerVehicle(
            TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        assertEq(newVehicleId, 1);
        assertTrue(vehicleRegistry.vehicleExists(1));
        assertTrue(vehicleRegistry.vinExists(TEST_VIN));
        assertEq(vehicleRegistry.getCurrentTokenId(), 3);
        assertEq(roboshareTokens.balanceOf(partner1, 1), 1);
    }

    function testRegisterMultipleVehicles() public {
        vm.prank(partner1);
        uint256 vehicleId1 = vehicleRegistry.registerVehicle(
            TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        string memory vin2 = "2HGCM82633A654321";
        vm.prank(partner2);
        uint256 vehicleId2 =
            vehicleRegistry.registerVehicle(vin2, "Toyota", "Camry", 2023, 2, "LE,HYBRID", "ipfs://QmHash");

        assertEq(vehicleId1, 1);
        assertEq(vehicleId2, 3);
        assertTrue(vehicleRegistry.vehicleExists(vehicleId1));
        assertTrue(vehicleRegistry.vehicleExists(vehicleId2));
        assertEq(vehicleRegistry.getCurrentTokenId(), 5);
        assertEq(roboshareTokens.balanceOf(partner1, 1), 1);
        assertEq(roboshareTokens.balanceOf(partner2, 3), 1);
    }

    // Revenue Share Token Tests

    function testMintRevenueTokens() public {
        _ensureState(SetupState.VehicleWithTokens);

        vm.expectEmit(true, true, true, true);
        emit VehicleRegistry.RevenueTokensMinted(
            scenario.vehicleId, scenario.revenueTokenId, partner1, REVENUE_TOKEN_SUPPLY
        );

        vm.prank(partner1);
        uint256 newRevenueTokenId = vehicleRegistry.mintRevenueTokens(scenario.vehicleId, REVENUE_TOKEN_SUPPLY);

        assertEq(newRevenueTokenId, scenario.revenueTokenId);
        assertEq(roboshareTokens.balanceOf(partner1, newRevenueTokenId), REVENUE_TOKEN_SUPPLY);
    }

    function testRegisterVehicleAndMintRevenueTokens() public {
        _ensureState(SetupState.VehicleWithTokens);

        assertTrue(vehicleRegistry.vehicleExists(scenario.vehicleId));
        assertEq(roboshareTokens.balanceOf(partner1, scenario.vehicleId), 1);
        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), REVENUE_TOKEN_SUPPLY);
    }

    // Metadata Update Tests

    function testUpdateVehicleMetadata() public {
        _ensureState(SetupState.VehicleWithTokens);
        string memory newURI = "ipfs://new-uri";

        vm.prank(partner1);
        vehicleRegistry.updateVehicleMetadata(scenario.vehicleId, newURI);

        (,,,,,, string memory metadataURI) = vehicleRegistry.getVehicleInfo(scenario.vehicleId);
        assertEq(metadataURI, newURI);
    }

    function testTokenIdConversions() public {
        _ensureState(SetupState.VehicleWithTokens);
        assertEq(vehicleRegistry.getRevenueTokenIdFromVehicleId(scenario.vehicleId), scenario.revenueTokenId);
        assertEq(vehicleRegistry.getVehicleIdFromRevenueTokenId(scenario.revenueTokenId), scenario.vehicleId);
    }

    // Access Control Tests

    function testUnauthorizedPartnerCannotRegisterVehicle() public {
        vm.expectRevert(PartnerManager.PartnerManager__NotAuthorized.selector);
        vm.prank(unauthorized);
        vehicleRegistry.registerVehicle(
            TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );
    }

    function testUnauthorizedPartnerCannotMintRevenueTokens() public {
        _ensureState(SetupState.VehicleWithTokens);
        vm.expectRevert(PartnerManager.PartnerManager__NotAuthorized.selector);
        vm.prank(unauthorized);
        vehicleRegistry.mintRevenueTokens(scenario.vehicleId, 100);
    }

    function testUnauthorizedPartnerCannotUpdateMetadata() public {
        _ensureState(SetupState.VehicleWithTokens);
        vm.expectRevert(PartnerManager.PartnerManager__NotAuthorized.selector);
        vm.prank(unauthorized);
        vehicleRegistry.updateVehicleMetadata(scenario.vehicleId, "ipfs://new-uri");
    }

    // Error Cases

    function testRegisterVehicleWithDuplicateVinFails() public {
        _ensureState(SetupState.VehicleWithTokens);
        vm.expectRevert(VehicleRegistry__VehicleAlreadyExists.selector);
        vm.prank(partner2);
        vehicleRegistry.registerVehicle(TEST_VIN, "Toyota", "Camry", 2023, 2, "LE", "ipfs://hash");
    }

    function testMintRevenueTokensForNonexistentVehicleFails() public {
        vm.expectRevert(VehicleRegistry__VehicleDoesNotExist.selector);
        vm.prank(partner1);
        vehicleRegistry.mintRevenueTokens(999, 100);
    }

    function testUpdateMetadataForNonexistentVehicleFails() public {
        vm.expectRevert(VehicleRegistry__VehicleDoesNotExist.selector);
        vm.prank(partner1);
        vehicleRegistry.updateVehicleMetadata(999, "ipfs://new-uri");
    }

    function testTokenIdConversionForNonexistentVehicleFails() public {
        _ensureState(SetupState.VehicleWithTokens);
        vm.expectRevert(VehicleRegistry__IncorrectRevenueTokenId.selector);
        vehicleRegistry.getVehicleIdFromRevenueTokenId(100);

        vm.expectRevert(VehicleRegistry__IncorrectVehicleId.selector);
        vehicleRegistry.getRevenueTokenIdFromVehicleId(101);
    }

    // View Function Tests

    function testVehicleExists() public {
        assertFalse(vehicleRegistry.vehicleExists(999));
        _ensureState(SetupState.VehicleWithTokens);
        assertTrue(vehicleRegistry.vehicleExists(scenario.vehicleId));
    }

    function testVinExists() public {
        assertFalse(vehicleRegistry.vinExists("FAKE_VIN"));
        _ensureState(SetupState.VehicleWithTokens);
        assertTrue(vehicleRegistry.vinExists(TEST_VIN));
    }

    function testGetCurrentTokenId() public {
        assertEq(vehicleRegistry.getCurrentTokenId(), 1);
        _ensureState(SetupState.VehicleWithTokens);
        assertEq(vehicleRegistry.getCurrentTokenId(), 3);
    }

    // Fuzz Tests

    function testFuzzMintRevenueTokens(uint256 supply) public {
        vm.assume(supply > 0 && supply <= 1e18);
        _ensureState(SetupState.VehicleWithTokens);

        vm.prank(partner1);
        uint256 newRevenueTokenId = vehicleRegistry.mintRevenueTokens(scenario.vehicleId, supply);

        assertEq(newRevenueTokenId, scenario.revenueTokenId);
        assertEq(roboshareTokens.balanceOf(partner1, newRevenueTokenId), supply);
    }

    // Lifecycle Test

    function testCompleteVehicleLifecycle() public {
        _ensureState(SetupState.VehicleWithTokens);

        assertTrue(vehicleRegistry.vehicleExists(scenario.vehicleId));

        string memory newURI = "ipfs://new";
        vm.prank(partner1);
        vehicleRegistry.updateVehicleMetadata(scenario.vehicleId, newURI);

        (,,,,,, string memory metadataURI) = vehicleRegistry.getVehicleInfo(scenario.vehicleId);
        assertEq(metadataURI, newURI);
    }
}
