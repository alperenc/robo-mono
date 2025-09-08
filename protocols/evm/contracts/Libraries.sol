// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Vehicle-specific errors
error VehicleLib__InvalidVINLength();
error VehicleLib__InvalidMake();
error VehicleLib__InvalidModel();
error VehicleLib__InvalidYear();
error VehicleLib__EmptyMetadataURI();

/**
 * @dev Protocol utilities for IPFS validation
 */
library ProtocolLib {
    // IPFS validation constants
    uint256 internal constant IPFS_HASH_LENGTH = 46; // "Qm" + 44 chars
    string internal constant IPFS_PREFIX = "ipfs://";

    /**
     * @dev Validate IPFS URI format
     * @param uri IPFS URI to validate
     * @return True if valid IPFS URI
     */
    function isValidIPFSURI(string memory uri) internal pure returns (bool) {
        bytes memory uriBytes = bytes(uri);
        bytes memory prefix = bytes(IPFS_PREFIX);
        
        // Check minimum length
        if (uriBytes.length < prefix.length + IPFS_HASH_LENGTH) {
            return false;
        }
        
        // Check prefix
        for (uint256 i = 0; i < prefix.length; i++) {
            if (uriBytes[i] != prefix[i]) {
                return false;
            }
        }
        
        return true;
    }
}

/**
 * @dev Vehicle-related data structures and functions
 * Hybrid storage: immutable data on-chain, dynamic data on IPFS
 */
library VehicleLib {
    /**
     * @dev Immutable vehicle information stored on-chain
     * Set once during registration, never changes
     */
    struct VehicleInfo {
        string vin;                 // Vehicle Identification Number
        string make;               // e.g., "Tesla", "Ford"  
        string model;              // e.g., "Model S", "F-150"
        uint256 year;              // Manufacturing year
        uint256 manufacturerId;    // Partner's manufacturer ID
        string optionCodes;        // e.g., "P90D,AP1,SUBW"
        string dynamicMetadataURI; // IPFS URI for changing data (odometer, etc.)
    }

    /**
     * @dev Main vehicle struct for protocol operations
     */
    struct Vehicle {
        uint256 vehicleId;          // Unique protocol identifier
        bool isActive;              // Active status in protocol
        uint256 createdAt;          // Registration timestamp
        VehicleInfo vehicleInfo;    // Immutable data + IPFS metadata URI
    }

    /**
     * @dev Initialize vehicle info with validation
     */
    function initializeVehicleInfo(
        VehicleInfo storage info,
        string memory vin,
        string memory make,
        string memory model,
        uint256 year,
        uint256 manufacturerId,
        string memory optionCodes,
        string memory dynamicMetadataURI
    ) internal {
        // Validation
        if (bytes(vin).length < 10 || bytes(vin).length > 17) {
            revert VehicleLib__InvalidVINLength();
        }
        if (bytes(make).length == 0) {
            revert VehicleLib__InvalidMake();
        }
        if (bytes(model).length == 0) {
            revert VehicleLib__InvalidModel();
        }
        if (year < 1990 || year > 2030) {
            revert VehicleLib__InvalidYear();
        }
        if (!ProtocolLib.isValidIPFSURI(dynamicMetadataURI)) {
            revert VehicleLib__EmptyMetadataURI();
        }

        // Set values
        info.vin = vin;
        info.make = make;
        info.model = model;
        info.year = year;
        info.manufacturerId = manufacturerId;
        info.optionCodes = optionCodes;
        info.dynamicMetadataURI = dynamicMetadataURI;
    }

    /**
     * @dev Update dynamic metadata URI (for IPFS data changes like odometer)
     */
    function updateDynamicMetadata(
        VehicleInfo storage info,
        string memory newMetadataURI
    ) internal {
        if (!ProtocolLib.isValidIPFSURI(newMetadataURI)) {
            revert VehicleLib__EmptyMetadataURI();
        }
        info.dynamicMetadataURI = newMetadataURI;
    }

    /**
     * @dev Get vehicle display name for UI/events
     */
    function getDisplayName(VehicleInfo storage info) internal view returns (string memory) {
        return string(abi.encodePacked(
            info.make, " ", info.model, " (", 
            _uint256ToString(info.year), ")"
        ));
    }

    /**
     * @dev Convert uint256 to string (internal utility)
     */
    function _uint256ToString(uint256 value) private pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}