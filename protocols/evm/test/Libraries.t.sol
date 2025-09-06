// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/Libraries.sol";

contract LibrariesTest is Test {
    using VehicleLib for VehicleLib.VehicleInfo;
    using ProtocolLib for string;

    VehicleLib.Vehicle internal testVehicle;
    
    string constant VALID_IPFS_URI = "ipfs://QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG";
    string constant INVALID_IPFS_URI_SHORT = "ipfs://Qm123";
    string constant INVALID_IPFS_URI_NO_PREFIX = "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG";
    
    string constant TEST_VIN = "1HGCM82633A004352";
    string constant TEST_MAKE = "Tesla";
    string constant TEST_MODEL = "Model S";
    uint256 constant TEST_YEAR = 2024;
    uint256 constant TEST_MANUFACTURER_ID = 1;
    string constant TEST_OPTION_CODES = "P90D,AP1,SUBW";

    function setUp() public {
        // Initialize test vehicle
        testVehicle.vehicleId = 1;
        testVehicle.isActive = true;
        testVehicle.createdAt = block.timestamp;
    }

    // ProtocolLib Tests
    
    function testValidIPFSURI() public {
        assertTrue(ProtocolLib.isValidIPFSURI(VALID_IPFS_URI));
    }

    function testInvalidIPFSURITooShort() public {
        assertFalse(ProtocolLib.isValidIPFSURI(INVALID_IPFS_URI_SHORT));
    }

    function testInvalidIPFSURINoPrefix() public {
        assertFalse(ProtocolLib.isValidIPFSURI(INVALID_IPFS_URI_NO_PREFIX));
    }

    function testInvalidIPFSURIEmpty() public {
        assertFalse(ProtocolLib.isValidIPFSURI(""));
    }

    function testInvalidIPFSURIWrongPrefix() public {
        assertFalse(ProtocolLib.isValidIPFSURI("https://gateway.pinata.cloud/ipfs/QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"));
    }

    // VehicleLib Tests
    
    function testInitializeVehicleInfo() public {
        VehicleLib.initializeVehicleInfo(
            testVehicle.vehicleInfo,
            TEST_VIN,
            TEST_MAKE,
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            VALID_IPFS_URI
        );

        assertEq(testVehicle.vehicleInfo.vin, TEST_VIN);
        assertEq(testVehicle.vehicleInfo.make, TEST_MAKE);
        assertEq(testVehicle.vehicleInfo.model, TEST_MODEL);
        assertEq(testVehicle.vehicleInfo.year, TEST_YEAR);
        assertEq(testVehicle.vehicleInfo.manufacturerId, TEST_MANUFACTURER_ID);
        assertEq(testVehicle.vehicleInfo.optionCodes, TEST_OPTION_CODES);
        assertEq(testVehicle.vehicleInfo.dynamicMetadataURI, VALID_IPFS_URI);
    }

    function testInitializeVehicleInfoInvalidVINTooShort() public {
        vm.expectRevert(VehicleLib__InvalidVINLength.selector);
        VehicleLib.initializeVehicleInfo(
            testVehicle.vehicleInfo,
            "123456789", // 9 chars, too short
            TEST_MAKE,
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            VALID_IPFS_URI
        );
    }

    function testInitializeVehicleInfoInvalidVINTooLong() public {
        vm.expectRevert(VehicleLib__InvalidVINLength.selector);
        VehicleLib.initializeVehicleInfo(
            testVehicle.vehicleInfo,
            "123456789012345678", // 18 chars, too long
            TEST_MAKE,
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            VALID_IPFS_URI
        );
    }

    function testInitializeVehicleInfoEmptyMake() public {
        vm.expectRevert(VehicleLib__InvalidMake.selector);
        VehicleLib.initializeVehicleInfo(
            testVehicle.vehicleInfo,
            TEST_VIN,
            "", // Empty make
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            VALID_IPFS_URI
        );
    }

    function testInitializeVehicleInfoEmptyModel() public {
        vm.expectRevert(VehicleLib__InvalidModel.selector);
        VehicleLib.initializeVehicleInfo(
            testVehicle.vehicleInfo,
            TEST_VIN,
            TEST_MAKE,
            "", // Empty model
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            VALID_IPFS_URI
        );
    }

    function testInitializeVehicleInfoInvalidYearTooOld() public {
        vm.expectRevert(VehicleLib__InvalidYear.selector);
        VehicleLib.initializeVehicleInfo(
            testVehicle.vehicleInfo,
            TEST_VIN,
            TEST_MAKE,
            TEST_MODEL,
            1989, // Too old
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            VALID_IPFS_URI
        );
    }

    function testInitializeVehicleInfoInvalidYearTooNew() public {
        uint256 futureYear = 1970 + (block.timestamp / 365 days) + 5; // 5 years in future
        vm.expectRevert(VehicleLib__InvalidYear.selector);
        VehicleLib.initializeVehicleInfo(
            testVehicle.vehicleInfo,
            TEST_VIN,
            TEST_MAKE,
            TEST_MODEL,
            futureYear,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            VALID_IPFS_URI
        );
    }

    function testInitializeVehicleInfoInvalidIPFS() public {
        vm.expectRevert(VehicleLib__EmptyMetadataURI.selector);
        VehicleLib.initializeVehicleInfo(
            testVehicle.vehicleInfo,
            TEST_VIN,
            TEST_MAKE,
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            INVALID_IPFS_URI_SHORT
        );
    }

    function testUpdateDynamicMetadata() public {
        // First initialize
        VehicleLib.initializeVehicleInfo(
            testVehicle.vehicleInfo,
            TEST_VIN,
            TEST_MAKE,
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            VALID_IPFS_URI
        );

        string memory newURI = "ipfs://QmNewHashForUpdatedMetadata123456789012345";
        VehicleLib.updateDynamicMetadata(testVehicle.vehicleInfo, newURI);
        
        assertEq(testVehicle.vehicleInfo.dynamicMetadataURI, newURI);
    }

    function testUpdateDynamicMetadataInvalidURI() public {
        // First initialize
        VehicleLib.initializeVehicleInfo(
            testVehicle.vehicleInfo,
            TEST_VIN,
            TEST_MAKE,
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            VALID_IPFS_URI
        );

        vm.expectRevert(VehicleLib__EmptyMetadataURI.selector);
        VehicleLib.updateDynamicMetadata(testVehicle.vehicleInfo, INVALID_IPFS_URI_SHORT);
    }

    function testGetDisplayName() public {
        VehicleLib.initializeVehicleInfo(
            testVehicle.vehicleInfo,
            TEST_VIN,
            TEST_MAKE,
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            VALID_IPFS_URI
        );

        string memory displayName = VehicleLib.getDisplayName(testVehicle.vehicleInfo);
        string memory expected = "Tesla Model S (2024)";
        assertEq(displayName, expected);
    }

    // Fuzz Tests
    
    function testFuzzValidVIN(string calldata vin) public {
        vm.assume(bytes(vin).length >= 10 && bytes(vin).length <= 17);
        
        VehicleLib.initializeVehicleInfo(
            testVehicle.vehicleInfo,
            vin,
            TEST_MAKE,
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            VALID_IPFS_URI
        );
        
        assertEq(testVehicle.vehicleInfo.vin, vin);
    }

    function testFuzzValidYear(uint256 year) public {
        uint256 maxYear = 1970 + (block.timestamp / 365 days) + 2;
        vm.assume(year >= 1990 && year <= maxYear);
        
        VehicleLib.initializeVehicleInfo(
            testVehicle.vehicleInfo,
            TEST_VIN,
            TEST_MAKE,
            TEST_MODEL,
            year,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            VALID_IPFS_URI
        );
        
        assertEq(testVehicle.vehicleInfo.year, year);
    }

    function testFuzzIPFSValidation(string calldata uri) public {
        bool isValid = ProtocolLib.isValidIPFSURI(uri);
        bytes memory uriBytes = bytes(uri);
        
        if (isValid) {
            // If marked as valid, should have proper prefix and length
            assertTrue(uriBytes.length >= 53); // "ipfs://" (7) + 46 chars minimum
            
            // Check prefix
            bytes memory prefix = bytes("ipfs://");
            for (uint256 i = 0; i < prefix.length; i++) {
                assertEq(uriBytes[i], prefix[i]);
            }
        }
    }

    // Edge Cases
    
    function testMinimumValidVIN() public {
        string memory minVIN = "1234567890"; // 10 chars - minimum
        
        VehicleLib.initializeVehicleInfo(
            testVehicle.vehicleInfo,
            minVIN,
            TEST_MAKE,
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            VALID_IPFS_URI
        );
        
        assertEq(testVehicle.vehicleInfo.vin, minVIN);
    }

    function testMaximumValidVIN() public {
        string memory maxVIN = "12345678901234567"; // 17 chars - maximum
        
        VehicleLib.initializeVehicleInfo(
            testVehicle.vehicleInfo,
            maxVIN,
            TEST_MAKE,
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            VALID_IPFS_URI
        );
        
        assertEq(testVehicle.vehicleInfo.vin, maxVIN);
    }

    function testCurrentYear() public {
        uint256 currentYear = 1970 + (block.timestamp / 365 days);
        
        VehicleLib.initializeVehicleInfo(
            testVehicle.vehicleInfo,
            TEST_VIN,
            TEST_MAKE,
            TEST_MODEL,
            currentYear,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            VALID_IPFS_URI
        );
        
        assertEq(testVehicle.vehicleInfo.year, currentYear);
    }
}