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
        assertTrue(vehicleRegistry.hasRole(keccak256("UPGRADER_ROLE"), admin));
    }

    function testInitializationWithZeroAddressesFails() public {
        VehicleRegistry newImplementation = new VehicleRegistry();

        // Test zero admin
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address)", address(0), address(roboshareTokens), address(partnerManager)
        );
        vm.expectRevert(VehicleRegistry__ZeroAddress.selector);
        new ERC1967Proxy(address(newImplementation), initData);
    }

    // Vehicle Registration Tests

    function testRegisterVehicle() public {
        vm.expectEmit(true, true, false, true);
        emit VehicleRegistry.VehicleRegistered(1, partner1, TEST_VIN, partner1);

        vm.prank(partner1);
        uint256 newVehicleId = vehicleRegistry.registerVehicle(
            TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        // Check return value
        assertEq(newVehicleId, 1);

        // Check vehicle exists
        assertTrue(vehicleRegistry.vehicleExists(1));
        assertTrue(vehicleRegistry.vinExists(TEST_VIN));

        // Check token counter updated
        assertEq(vehicleRegistry.getCurrentTokenId(), 3); // Next vehicle will be 3

        // Check NFT was minted to partner (vehicle owner)
        assertEq(roboshareTokens.balanceOf(partner1, 1), 1);

        // Check vehicle info
        (
            string memory vin,
            string memory make,
            string memory model,
            uint256 year,
            uint256 manufacturerId,
            string memory optionCodes,
            string memory metadataURI
        ) = vehicleRegistry.getVehicleInfo(1);

        assertEq(vin, TEST_VIN);
        assertEq(make, TEST_MAKE);
        assertEq(model, TEST_MODEL);
        assertEq(year, TEST_YEAR);
        assertEq(manufacturerId, TEST_MANUFACTURER_ID);
        assertEq(optionCodes, TEST_OPTION_CODES);
        assertEq(metadataURI, TEST_METADATA_URI);

        // Check display name
        string memory displayName = vehicleRegistry.getVehicleDisplayName(1);
        assertEq(displayName, "Honda Civic (2024)");
    }

    function testRegisterMultipleVehicles() public {
        // Register first vehicle (fleet operator 1)
        vm.prank(partner1);
        uint256 vehicleId1 = vehicleRegistry.registerVehicle(
            TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        // Register second vehicle (fleet operator 2)
        string memory vin2 = "2HGCM82633A654321";
        vm.prank(partner2);
        uint256 vehicleId2 = vehicleRegistry.registerVehicle(
            vin2, "Toyota", "Camry", 2023, 2, "LE,HYBRID", "ipfs://QmTestHash456789abcdefghijklmnopqrstuvwxyzDEFG"
        );

        // Check vehicle IDs are odd and sequential
        assertEq(vehicleId1, 1);
        assertEq(vehicleId2, 3);

        // Check both vehicles exist
        assertTrue(vehicleRegistry.vehicleExists(1));
        assertTrue(vehicleRegistry.vehicleExists(3));
        assertTrue(vehicleRegistry.vinExists(TEST_VIN));
        assertTrue(vehicleRegistry.vinExists(vin2));

        // Check token counter
        assertEq(vehicleRegistry.getCurrentTokenId(), 5); // Next vehicle will be 5

        // Check NFTs minted to respective partners
        assertEq(roboshareTokens.balanceOf(partner1, 1), 1);
        assertEq(roboshareTokens.balanceOf(partner2, 3), 1);
    }

    // Revenue Share Token Tests

    function testMintRevenueShareTokens() public {
        _ensureState(SetupState.VehicleRegistered);

        uint256 totalSupply = 1000;

        vm.expectEmit(true, true, true, true);
        emit VehicleRegistry.RevenueShareTokensMinted(vehicleId, vehicleId + 1, partner1, totalSupply);

        // Mint revenue share tokens
        vm.prank(partner1);
        uint256 newRevenueShareTokenId = vehicleRegistry.mintRevenueShareTokens(vehicleId, totalSupply);

        // Check return value
        assertEq(newRevenueShareTokenId, vehicleId + 1);

        // Check tokens minted to partner (who will sell them later)
        assertEq(roboshareTokens.balanceOf(partner1, newRevenueShareTokenId), totalSupply);

        // Check tokenId conversion functions
        assertEq(vehicleRegistry.getVehicleIdFromRevenueShareTokenId(newRevenueShareTokenId), vehicleId);
        assertEq(vehicleRegistry.getRevenueShareTokenIdFromVehicleId(vehicleId), newRevenueShareTokenId);
    }

    function testRegisterVehicleAndMintRevenueShareTokens() public {
        uint256 revenueShareSupply = 500;

        vm.expectEmit(true, true, true, true);
        emit VehicleRegistry.VehicleAndRevenueShareTokensMinted(1, 2, partner1, partner1, revenueShareSupply);

        vm.prank(partner1);
        (uint256 newVehicleId, uint256 newRevenueShareTokenId) = vehicleRegistry
            .registerVehicleAndMintRevenueShareTokens(
            TEST_VIN,
            TEST_MAKE,
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            TEST_METADATA_URI,
            revenueShareSupply
        );

        // Check return values
        assertEq(newVehicleId, 1);
        assertEq(newRevenueShareTokenId, 2);

        // Check vehicle registered to partner
        assertTrue(vehicleRegistry.vehicleExists(1));
        assertEq(roboshareTokens.balanceOf(partner1, 1), 1);

        // Check revenue share tokens minted to partner (for marketplace sale)
        assertEq(roboshareTokens.balanceOf(partner1, 2), revenueShareSupply);

        // Check tokenId conversion
        assertEq(vehicleRegistry.getVehicleIdFromRevenueShareTokenId(2), 1);
        assertEq(vehicleRegistry.getRevenueShareTokenIdFromVehicleId(1), 2);
    }

    // ... other tests from VehicleRegistry.t.sol, refactored to use BaseTest ...
}
