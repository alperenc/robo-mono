// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/VehicleRegistry.sol";
import "../contracts/RoboshareTokens.sol";
import "../contracts/PartnerManager.sol";
import "../contracts/Libraries.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract VehicleRegistryTest is Test {
    VehicleRegistry public vehicleRegistry;
    VehicleRegistry public vehicleImplementation;
    RoboshareTokens public roboshareTokens;
    RoboshareTokens public tokenImplementation;
    PartnerManager public partnerManager;
    PartnerManager public partnerImplementation;

    address public admin = makeAddr("admin");
    address public partner1 = makeAddr("partner1"); // Fleet operator 1
    address public partner2 = makeAddr("partner2"); // Fleet operator 2
    address public unauthorized = makeAddr("unauthorized");

    // Test vehicle data
    string constant TEST_VIN = "1HGCM82633A123456";
    string constant TEST_MAKE = "Honda";
    string constant TEST_MODEL = "Civic";
    uint256 constant TEST_YEAR = 2024;
    uint256 constant TEST_MANUFACTURER_ID = 1;
    string constant TEST_OPTION_CODES = "EX-L,NAV,HSS";
    string constant TEST_METADATA_URI = "ipfs://QmTestHash123456789abcdefghijklmnopqrstuvwxyzABC";

    string constant PARTNER1_NAME = "RideShare Fleet Co.";
    string constant PARTNER2_NAME = "Urban Delivery Services";

    // Role constants
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function setUp() public {
        // Deploy RoboshareTokens
        tokenImplementation = new RoboshareTokens();
        bytes memory tokenInitData = abi.encodeWithSignature("initialize(address)", admin);
        ERC1967Proxy tokenProxy = new ERC1967Proxy(address(tokenImplementation), tokenInitData);
        roboshareTokens = RoboshareTokens(address(tokenProxy));

        // Deploy PartnerManager
        partnerImplementation = new PartnerManager();
        bytes memory partnerInitData = abi.encodeWithSignature("initialize(address)", admin);
        ERC1967Proxy partnerProxy = new ERC1967Proxy(address(partnerImplementation), partnerInitData);
        partnerManager = PartnerManager(address(partnerProxy));

        // Deploy VehicleRegistry
        vehicleImplementation = new VehicleRegistry();
        bytes memory vehicleInitData = abi.encodeWithSignature(
            "initialize(address,address,address)", admin, address(roboshareTokens), address(partnerManager)
        );
        ERC1967Proxy vehicleProxy = new ERC1967Proxy(address(vehicleImplementation), vehicleInitData);
        vehicleRegistry = VehicleRegistry(address(vehicleProxy));

        // Setup roles and permissions
        vm.startPrank(admin);
        // Grant MINTER_ROLE to VehicleRegistry for token operations
        roboshareTokens.grantRole(MINTER_ROLE, address(vehicleRegistry));
        // Authorize partners (fleet operators)
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);
        partnerManager.authorizePartner(partner2, PARTNER2_NAME);
        vm.stopPrank();
    }

    // Initialization Tests

    function testInitialization() public {
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

        // Test zero tokens
        initData = abi.encodeWithSignature(
            "initialize(address,address,address)", admin, address(0), address(partnerManager)
        );
        vm.expectRevert(VehicleRegistry__ZeroAddress.selector);
        new ERC1967Proxy(address(newImplementation), initData);

        // Test zero partner manager
        initData = abi.encodeWithSignature(
            "initialize(address,address,address)", admin, address(roboshareTokens), address(0)
        );
        vm.expectRevert(VehicleRegistry__ZeroAddress.selector);
        new ERC1967Proxy(address(newImplementation), initData);
    }

    // Vehicle Registration Tests

    function testRegisterVehicle() public {
        vm.expectEmit(true, true, false, true);
        emit VehicleRegistry.VehicleRegistered(1, partner1, TEST_VIN, partner1);

        vm.prank(partner1);
        uint256 vehicleId = vehicleRegistry.registerVehicle(
            partner1, TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        // Check return value
        assertEq(vehicleId, 1);

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
            partner1, TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        // Register second vehicle (fleet operator 2)
        string memory vin2 = "2HGCM82633A654321";
        vm.prank(partner2);
        uint256 vehicleId2 = vehicleRegistry.registerVehicle(
            partner2, vin2, "Toyota", "Camry", 2023, 2, "LE,HYBRID", "ipfs://QmTestHash456789abcdefghijklmnopqrstuvwxyzDEFG"
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
        // First register a vehicle (fleet operator registers their vehicle)
        vm.prank(partner1);
        uint256 vehicleId = vehicleRegistry.registerVehicle(
            partner1, TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        uint256 totalSupply = 1000;

        vm.expectEmit(true, true, true, true);
        emit VehicleRegistry.RevenueShareTokensMinted(vehicleId, 2, partner1, totalSupply);

        // Mint revenue share tokens
        vm.prank(partner1);
        uint256 revenueShareTokenId = vehicleRegistry.mintRevenueShareTokens(vehicleId, totalSupply);

        // Check return value
        assertEq(revenueShareTokenId, 2);

        // Check tokens minted to partner (who will sell them later)
        assertEq(roboshareTokens.balanceOf(partner1, 2), totalSupply);

        // Check tokenId conversion functions
        assertEq(vehicleRegistry.getVehicleIdFromRevenueShareTokenId(2), 1);
        assertEq(vehicleRegistry.getRevenueShareTokenIdFromVehicleId(1), 2);
    }

    function testRegisterVehicleAndMintRevenueShareTokens() public {
        uint256 revenueShareSupply = 500;

        vm.expectEmit(true, true, true, true);
        emit VehicleRegistry.VehicleAndRevenueShareTokensMinted(1, 2, partner1, partner1, revenueShareSupply);

        vm.prank(partner1);
        (uint256 vehicleId, uint256 revenueShareTokenId) = vehicleRegistry
            .registerVehicleAndMintRevenueShareTokens(
            partner1,
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
        assertEq(vehicleId, 1);
        assertEq(revenueShareTokenId, 2);

        // Check vehicle registered to partner
        assertTrue(vehicleRegistry.vehicleExists(1));
        assertEq(roboshareTokens.balanceOf(partner1, 1), 1);

        // Check revenue share tokens minted to partner (for marketplace sale)
        assertEq(roboshareTokens.balanceOf(partner1, 2), revenueShareSupply);

        // Check tokenId conversion
        assertEq(vehicleRegistry.getVehicleIdFromRevenueShareTokenId(2), 1);
        assertEq(vehicleRegistry.getRevenueShareTokenIdFromVehicleId(1), 2);
    }

    // TokenId Conversion Tests

    function testTokenIdConversions() public {
        // Register multiple vehicles to test the pattern
        vm.startPrank(partner1);
        uint256 vehicleId1 = vehicleRegistry.registerVehicle(
            partner1, TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );
        uint256 vehicleId2 = vehicleRegistry.registerVehicle(
            partner1, "2HGCM82633A654321", "Toyota", "Camry", 2023, 2, "LE", "ipfs://QmTest456789abcdefghijklmnopqrstuvwxyzABCDEFGH"
        );
        vm.stopPrank();

        // Test conversions for first vehicle (1 -> 2)
        assertEq(vehicleRegistry.getRevenueShareTokenIdFromVehicleId(vehicleId1), vehicleId1 + 1);
        assertEq(vehicleRegistry.getVehicleIdFromRevenueShareTokenId(vehicleId1 + 1), vehicleId1);

        // Test conversions for second vehicle (3 -> 4)
        assertEq(vehicleRegistry.getRevenueShareTokenIdFromVehicleId(vehicleId2), vehicleId2 + 1);
        assertEq(vehicleRegistry.getVehicleIdFromRevenueShareTokenId(vehicleId2 + 1), vehicleId2);
    }

    // Metadata Update Tests

    function testUpdateVehicleMetadata() public {
        // Register vehicle
        vm.prank(partner1);
        uint256 vehicleId = vehicleRegistry.registerVehicle(
            partner1, TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        string memory newMetadataURI = "ipfs://QmUpdatedHash789abcdefghijklmnopqrstuvwxyzGHIJ";

        vm.prank(partner1);
        vehicleRegistry.updateVehicleMetadata(vehicleId, newMetadataURI);

        // Check metadata updated
        (,,,,,, string memory metadataURI) = vehicleRegistry.getVehicleInfo(vehicleId);
        assertEq(metadataURI, newMetadataURI);
    }

    // Access Control Tests

    function testUnauthorizedPartnerCannotRegisterVehicle() public {
        vm.expectRevert(PartnerManager.PartnerManager__NotAuthorized.selector);
        vm.prank(unauthorized);
        vehicleRegistry.registerVehicle(
            unauthorized, TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );
    }

    function testUnauthorizedPartnerCannotMintRevenueTokens() public {
        // Register vehicle first
        vm.prank(partner1);
        uint256 vehicleId = vehicleRegistry.registerVehicle(
            partner1, TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        vm.expectRevert(PartnerManager.PartnerManager__NotAuthorized.selector);
        vm.prank(unauthorized);
        vehicleRegistry.mintRevenueShareTokens(vehicleId, 100);
    }

    function testUnauthorizedPartnerCannotUpdateMetadata() public {
        // Register vehicle first
        vm.prank(partner1);
        uint256 vehicleId = vehicleRegistry.registerVehicle(
            partner1, TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        vm.expectRevert(PartnerManager.PartnerManager__NotAuthorized.selector);
        vm.prank(unauthorized);
        vehicleRegistry.updateVehicleMetadata(vehicleId, "ipfs://QmHackerTooShortForValidIPFSHashLengthCheck1234");
    }

    // Error Cases Tests

    function testRegisterVehicleWithZeroOwnerFails() public {
        vm.expectRevert(VehicleRegistry__ZeroAddress.selector);
        vm.prank(partner1);
        vehicleRegistry.registerVehicle(
            address(0), TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );
    }

    function testRegisterVehicleWithDuplicateVinFails() public {
        // Register first vehicle
        vm.prank(partner1);
        vehicleRegistry.registerVehicle(
            partner1, TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        // Try to register with same VIN (different fleet operator)
        vm.expectRevert(VehicleRegistry__VehicleAlreadyExists.selector);
        vm.prank(partner2);
        vehicleRegistry.registerVehicle(
            partner2, TEST_VIN, "Toyota", "Camry", 2023, 2, "LE", "ipfs://QmTest456789abcdefghijklmnopqrstuvwxyzABCDEFG"
        );
    }

    function testMintRevenueTokensForNonexistentVehicleFails() public {
        vm.expectRevert(VehicleRegistry__VehicleDoesNotExist.selector);
        vm.prank(partner1);
        vehicleRegistry.mintRevenueShareTokens(999, 100);
    }

    function testUpdateMetadataForNonexistentVehicleFails() public {
        vm.expectRevert(VehicleRegistry__VehicleDoesNotExist.selector);
        vm.prank(partner1);
        vehicleRegistry.updateVehicleMetadata(999, "ipfs://QmTestHashForNonexistentVehicleTestCase1234567");
    }

    function testGetVehicleInfoForNonexistentVehicleFails() public {
        vm.expectRevert(VehicleRegistry__VehicleDoesNotExist.selector);
        vehicleRegistry.getVehicleInfo(999);
    }

    function testGetDisplayNameForNonexistentVehicleFails() public {
        vm.expectRevert(VehicleRegistry__VehicleDoesNotExist.selector);
        vehicleRegistry.getVehicleDisplayName(999);
    }

    function testTokenIdConversionErrorCases() public {
        // Test invalid revenue share token ID (must be even)
        vm.expectRevert(VehicleRegistry__IncorrectRevenueShareTokenId.selector);
        vehicleRegistry.getVehicleIdFromRevenueShareTokenId(1); // odd

        vm.expectRevert(VehicleRegistry__IncorrectRevenueShareTokenId.selector);
        vehicleRegistry.getVehicleIdFromRevenueShareTokenId(0); // zero

        // Test invalid vehicle ID (must be odd)
        vm.expectRevert(VehicleRegistry__IncorrectVehicleId.selector);
        vehicleRegistry.getRevenueShareTokenIdFromVehicleId(2); // even

        vm.expectRevert(VehicleRegistry__IncorrectVehicleId.selector);
        vehicleRegistry.getRevenueShareTokenIdFromVehicleId(0); // zero
    }

    function testTokenIdConversionForNonexistentVehicleFails() public {
        // First register a vehicle to advance the counter
        vm.prank(partner1);
        vehicleRegistry.registerVehicle(
            partner1, "1TEST123456789ABC", "Honda", "Civic", 2024, 1, "EX", TEST_METADATA_URI
        );
        
        // Now test with token IDs that are out of range
        vm.expectRevert(VehicleRegistry__IncorrectRevenueShareTokenId.selector);
        vehicleRegistry.getVehicleIdFromRevenueShareTokenId(100); // Out of range

        vm.expectRevert(VehicleRegistry__IncorrectVehicleId.selector);
        vehicleRegistry.getRevenueShareTokenIdFromVehicleId(101); // Out of range
    }

    // Integration Tests

    function testCompleteVehicleLifecycle() public {
        // 1. Fleet operator registers their vehicle
        vm.prank(partner1);
        uint256 vehicleId = vehicleRegistry.registerVehicle(
            partner1, TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        assertEq(vehicleId, 1);
        assertTrue(vehicleRegistry.vehicleExists(1));
        assertEq(roboshareTokens.balanceOf(partner1, 1), 1);

        // 2. Fleet operator mints revenue share tokens (to sell later)
        vm.prank(partner1);
        uint256 revenueShareTokenId = vehicleRegistry.mintRevenueShareTokens(vehicleId, 1000);

        assertEq(revenueShareTokenId, 2);
        assertEq(roboshareTokens.balanceOf(partner1, 2), 1000);

        // 3. Fleet operator updates metadata (e.g., odometer reading)
        string memory newURI = "ipfs://QmUpdated123456789abcdefghijklmnopqrstuvwxyzJKLM";
        vm.prank(partner1);
        vehicleRegistry.updateVehicleMetadata(vehicleId, newURI);

        (,,,,,, string memory metadataURI) = vehicleRegistry.getVehicleInfo(vehicleId);
        assertEq(metadataURI, newURI);

        // 4. Verify tokenId conversions work
        assertEq(vehicleRegistry.getVehicleIdFromRevenueShareTokenId(2), 1);
        assertEq(vehicleRegistry.getRevenueShareTokenIdFromVehicleId(1), 2);
    }

    // Fuzz Tests


    function testFuzzMintRevenueShareTokens(uint256 supply) public {
        vm.assume(supply > 0 && supply <= 1e18);

        // Register vehicle first
        vm.prank(partner1);
        uint256 vehicleId = vehicleRegistry.registerVehicle(
            partner1, TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        vm.prank(partner1);
        uint256 revenueShareTokenId = vehicleRegistry.mintRevenueShareTokens(vehicleId, supply);

        assertEq(revenueShareTokenId, vehicleId + 1);
        assertEq(roboshareTokens.balanceOf(partner1, revenueShareTokenId), supply);
    }

    // View Function Tests

    function testVehicleExists() public {
        assertFalse(vehicleRegistry.vehicleExists(1));

        vm.prank(partner1);
        vehicleRegistry.registerVehicle(
            partner1, TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        assertTrue(vehicleRegistry.vehicleExists(1));
        assertFalse(vehicleRegistry.vehicleExists(2));
    }

    function testVinExists() public {
        assertFalse(vehicleRegistry.vinExists(TEST_VIN));

        vm.prank(partner1);
        vehicleRegistry.registerVehicle(
            partner1, TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        assertTrue(vehicleRegistry.vinExists(TEST_VIN));
        assertFalse(vehicleRegistry.vinExists("INVALID_VIN"));
    }

    function testGetCurrentTokenId() public {
        assertEq(vehicleRegistry.getCurrentTokenId(), 1);

        vm.prank(partner1);
        vehicleRegistry.registerVehicle(
            partner1, TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        assertEq(vehicleRegistry.getCurrentTokenId(), 3);
    }
}