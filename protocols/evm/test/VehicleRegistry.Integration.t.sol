// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";

contract VehicleRegistryIntegrationTest is BaseTest {
    function setUp() public {
        _ensureState(SetupState.PartnersAuthorized);
    }

    // Vehicle Registration Tests

    function testRegisterVehicle() public {
        (string memory vin, string memory make, string memory model, uint256 year, uint256 manufacturerId, string memory optionCodes, string memory metadataURI) = generateVehicleData(1);

        vm.expectEmit(true, true, false, true);
        emit VehicleRegistry.VehicleRegistered(1, partner1, vin);

        vm.prank(partner1);
        uint256 newVehicleId = vehicleRegistry.registerVehicle(
            vin, make, model, year, manufacturerId, optionCodes, metadataURI
        );

        assertEq(newVehicleId, 1);
        assertVehicleState(newVehicleId, partner1, vin, true);
        assertEq(vehicleRegistry.getCurrentTokenId(), 3);
    }

    function testRegisterMultipleVehicles() public {
        (string memory vin1, string memory make1, string memory model1, uint256 year1, uint256 manufacturerId1, string memory optionCodes1, string memory metadataURI1) = generateVehicleData(1);
        vm.prank(partner1);
        uint256 vehicleId1 = vehicleRegistry.registerVehicle(
            vin1, make1, model1, year1, manufacturerId1, optionCodes1, metadataURI1
        );

        (string memory vin2, string memory make2, string memory model2, uint256 year2, uint256 manufacturerId2, string memory optionCodes2, string memory metadataURI2) = generateVehicleData(2);
        vm.prank(partner2);
        uint256 vehicleId2 = vehicleRegistry.registerVehicle(
            vin2, make2, model2, year2, manufacturerId2, optionCodes2, metadataURI2
        );

        assertEq(vehicleId1, 1);
        assertEq(vehicleId2, 3);
        assertVehicleState(vehicleId1, partner1, vin1, true);
        assertVehicleState(vehicleId2, partner2, vin2, true);
        assertEq(vehicleRegistry.getCurrentTokenId(), 5);
    }

    // Revenue Share Token Tests

    function testMintRevenueTokens() public {
        _ensureState(SetupState.VehicleWithTokens);

        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), REVENUE_TOKEN_SUPPLY);
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
        // Use a valid IPFS URI (prefix + 46-char CID)
        string memory newURI = "ipfs://QmYwAPJzv5CZsnAzt8auVTLpG1bG6dkprdFM5ocTyBCQb";

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
        vehicleRegistry.updateVehicleMetadata(
            scenario.vehicleId, "ipfs://QmYwAPJzv5CZsnAzt8auVTLpG1bG6dkprdFM5ocTyBCQb"
        );
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
        vehicleRegistry.updateVehicleMetadata(999, "ipfs://QmYwAPJzv5CZsnAzt8auVTLpG1bG6dkprdFM5ocTyBCQb");
    }

    function testTokenIdConversionForNonexistentVehicleFails() public {
        _ensureState(SetupState.VehicleWithTokens);
        vm.expectRevert(VehicleRegistry__IncorrectRevenueTokenId.selector);
        vehicleRegistry.getVehicleIdFromRevenueTokenId(100);

        vm.expectRevert(VehicleRegistry__IncorrectVehicleId.selector);
        vehicleRegistry.getRevenueTokenIdFromVehicleId(101);
    }

    function testGetVehicleIdFromRevenueTokenIdErrorCases() public {
        _ensureState(SetupState.PartnersAuthorized);

        // Test revenueTokenId == 0
        vm.expectRevert(VehicleRegistry__IncorrectRevenueTokenId.selector);
        vehicleRegistry.getVehicleIdFromRevenueTokenId(0);

        // Test revenueTokenId % 2 != 0 (odd revenue token ID)
        vm.expectRevert(VehicleRegistry__IncorrectRevenueTokenId.selector);
        vehicleRegistry.getVehicleIdFromRevenueTokenId(1); // 1 is an odd ID

        // Test revenueTokenId >= _tokenIdCounter (non-existent revenue token ID)
        vm.expectRevert(VehicleRegistry__IncorrectRevenueTokenId.selector);
        vehicleRegistry.getVehicleIdFromRevenueTokenId(999999);

        // Test vehicles[vehicleId].vehicleId == 0 (corresponding vehicle NFT doesn't exist)
        // To test this, we need a revenueTokenId that is valid in terms of parity and counter,
        // but whose corresponding vehicleId does not exist. This is hard to achieve without
        // directly manipulating _tokenIdCounter or deleting a vehicle, which is not possible.
        // The existing test `testMintRevenueTokensForNonexistentVehicleFails` covers a similar scenario.
    }

    function testGetRevenueTokenIdFromVehicleIdErrorCases() public {
        _ensureState(SetupState.PartnersAuthorized);

        // Test vehicleId == 0
        vm.expectRevert(VehicleRegistry__IncorrectVehicleId.selector);
        vehicleRegistry.getRevenueTokenIdFromVehicleId(0);

        // Test vehicleId % 2 != 1 (even vehicle ID)
        vm.expectRevert(VehicleRegistry__IncorrectVehicleId.selector);
        vehicleRegistry.getRevenueTokenIdFromVehicleId(2); // 2 is an even ID

        // Test vehicleId >= _tokenIdCounter (non-existent vehicle ID)
        vm.expectRevert(VehicleRegistry__IncorrectVehicleId.selector);
        vehicleRegistry.getRevenueTokenIdFromVehicleId(999999);

        // Test vehicles[vehicleId].vehicleId == 0 (vehicle NFT doesn't exist)
        // This is covered by the non-existent vehicle ID test above.
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
        _deployContracts();
        _setupInitialRolesAndPartners();

        vm.prank(partner1);
        uint256 vehicleId = vehicleRegistry.registerVehicle(
            TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        vm.prank(partner1);
        uint256 revenueTokenId = vehicleRegistry.mintRevenueTokens(vehicleId, supply);

        assertEq(roboshareTokens.balanceOf(partner1, revenueTokenId), supply);
    }

    // Lifecycle Test

    function testCompleteVehicleLifecycle() public {
        _ensureState(SetupState.VehicleWithTokens);

        assertTrue(vehicleRegistry.vehicleExists(scenario.vehicleId));

        string memory newURI = "ipfs://QmYwAPJzv5CZsnAzt8auVTLpG1bG6dkprdFM5ocTyBCQb";
        vm.prank(partner1);
        vehicleRegistry.updateVehicleMetadata(scenario.vehicleId, newURI);

        (,,,,,, string memory metadataURI) = vehicleRegistry.getVehicleInfo(scenario.vehicleId);
        assertEq(metadataURI, newURI);
    }
}
