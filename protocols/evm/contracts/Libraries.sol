// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Vehicle-specific errors
error VehicleLib__InvalidVINLength();
error VehicleLib__InvalidMake();
error VehicleLib__InvalidModel();
error VehicleLib__InvalidYear();
error VehicleLib__EmptyMetadataURI();

// Collateral-specific errors
error CollateralLib__InsufficientCollateral();
error CollateralLib__InvalidCollateralAmount();
error CollateralLib__CollateralAlreadyLocked();
error CollateralLib__NoCollateralLocked();

/**
 * @dev Protocol utilities and constants
 */
library ProtocolLib {
    // IPFS validation constants
    uint256 internal constant IPFS_HASH_LENGTH = 46; // "Qm" + 44 chars
    string internal constant IPFS_PREFIX = "ipfs://";
    
    // Time intervals
    uint256 internal constant MIN_EVENT_INTERVAL = 15 days;
    uint256 internal constant QUARTERLY_INTERVAL = 90 days;
    uint256 internal constant YEARLY_INTERVAL = 365 days;
    
    // Protocol economic constants (basis points)
    uint256 internal constant BP_PRECISION = 10000;
    uint256 internal constant MIN_EARNINGS_BUFFER_BP = 1000; // 10%
    uint256 internal constant MIN_PROTOCOL_BUFFER_BP = 500; // 5%
    uint256 internal constant PROTOCOL_FEE_BP = 250; // 2.5%

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

    /**
     * @dev Calculate protocol fee
     * @param amount Amount to calculate fee on
     * @return Protocol fee amount
     */
    function calculateProtocolFee(uint256 amount) internal pure returns (uint256) {
        return (amount * PROTOCOL_FEE_BP) / BP_PRECISION;
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
        string vin; // Vehicle Identification Number
        string make; // e.g., "Tesla", "Ford"
        string model; // e.g., "Model S", "F-150"
        uint256 year; // Manufacturing year
        uint256 manufacturerId; // Partner's manufacturer ID
        string optionCodes; // e.g., "P90D,AP1,SUBW"
        string dynamicMetadataURI; // IPFS URI for changing data (odometer, etc.)
    }

    /**
     * @dev Main vehicle struct for protocol operations
     */
    struct Vehicle {
        uint256 vehicleId; // Unique protocol identifier
        bool isActive; // Active status in protocol
        uint256 createdAt; // Registration timestamp
        VehicleInfo vehicleInfo; // Immutable data + IPFS metadata URI
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
    function updateDynamicMetadata(VehicleInfo storage info, string memory newMetadataURI) internal {
        if (!ProtocolLib.isValidIPFSURI(newMetadataURI)) {
            revert VehicleLib__EmptyMetadataURI();
        }
        info.dynamicMetadataURI = newMetadataURI;
    }

    /**
     * @dev Get vehicle display name for UI/events
     */
    function getDisplayName(VehicleInfo storage info) internal view returns (string memory) {
        return string(abi.encodePacked(info.make, " ", info.model, " (", _uint256ToString(info.year), ")"));
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

/**
 * @dev Collateral management library for USDC-based collateral operations
 */
library CollateralLib {
    using ProtocolLib for uint256;

    /**
     * @dev Collateral information for vehicles with time-based calculations
     */
    struct CollateralInfo {
        uint256 baseCollateral; // Base collateral amount in USDC
        uint256 totalCollateral; // Total required collateral in USDC
        bool isLocked; // Whether collateral is currently locked
        uint256 lockedAt; // Timestamp when collateral was locked
        uint256 lastEventTimestamp; // Last collateral event timestamp
        uint256 createdAt; // When collateral info was initialized
    }

    /**
     * @dev Initialize collateral info for a vehicle
     * @param info Collateral info storage reference
     * @param revenueTokenPrice Price per revenue share token in USDC
     * @param totalRevenueTokens Total number of revenue share tokens
     * @param bufferTimeInterval Time interval for buffer calculations (e.g., 90 days)
     */
    function initializeCollateralInfo(
        CollateralInfo storage info,
        uint256 revenueTokenPrice,
        uint256 totalRevenueTokens,
        uint256 bufferTimeInterval
    ) internal {
        if (revenueTokenPrice == 0 || totalRevenueTokens == 0) {
            revert CollateralLib__InvalidCollateralAmount();
        }

        info.baseCollateral = revenueTokenPrice * totalRevenueTokens;
        info.totalCollateral = calculateCollateralRequirement(revenueTokenPrice, totalRevenueTokens, bufferTimeInterval);
        info.isLocked = false;
        info.lockedAt = 0;
        info.lastEventTimestamp = block.timestamp;
        info.createdAt = block.timestamp;
    }

    /**
     * @dev Calculate total collateral requirement using time-based buffer calculations
     * Buffers represent specified time period of expected earnings for investor protection
     * @param revenueTokenPrice Price per revenue share token in USDC
     * @param totalRevenueTokens Total number of revenue share tokens
     * @param bufferTimeInterval Time interval for buffer calculations (e.g., 90 days)
     * @return Total collateral requirement in USDC
     */
    function calculateCollateralRequirement(
        uint256 revenueTokenPrice,
        uint256 totalRevenueTokens,
        uint256 bufferTimeInterval
    ) internal pure returns (uint256) {
        uint256 baseAmount = revenueTokenPrice * totalRevenueTokens;
        
        // Calculate expected earnings for the specified time interval
        uint256 expectedIntervalEarnings = (baseAmount * bufferTimeInterval) / ProtocolLib.YEARLY_INTERVAL;
        
        // Calculate buffers for investor protection over the time interval
        uint256 earningsBuffer = (expectedIntervalEarnings * ProtocolLib.MIN_EARNINGS_BUFFER_BP) / ProtocolLib.BP_PRECISION;
        uint256 protocolBuffer = (expectedIntervalEarnings * ProtocolLib.MIN_PROTOCOL_BUFFER_BP) / ProtocolLib.BP_PRECISION;
        
        return baseAmount + earningsBuffer + protocolBuffer;
    }

    /**
     * @dev Check if collateral info is properly initialized
     * @param info Collateral info to check
     * @return True if initialized
     */
    function isInitialized(CollateralInfo storage info) internal view returns (bool) {
        return info.totalCollateral > 0;
    }

    /**
     * @dev Get collateral lock duration
     * @param info Collateral info storage reference
     * @return Duration in seconds since lock
     */
    function getLockDuration(CollateralInfo storage info) internal view returns (uint256) {
        if (!info.isLocked || info.lockedAt == 0) {
            return 0;
        }
        return block.timestamp - info.lockedAt;
    }

    /**
     * @dev Get collateral breakdown for display
     * @param revenueTokenPrice Price per revenue share token in USDC
     * @param totalRevenueTokens Total number of revenue share tokens
     * @param bufferTimeInterval Time interval for buffer calculations (e.g., 90 days)
     * @return baseAmount Base collateral amount
     * @return earningsBuffer Earnings buffer amount
     * @return protocolBuffer Protocol buffer amount
     * @return totalRequired Total collateral required
     */
    function getCollateralBreakdown(
        uint256 revenueTokenPrice,
        uint256 totalRevenueTokens,
        uint256 bufferTimeInterval
    ) internal pure returns (
        uint256 baseAmount,
        uint256 earningsBuffer,
        uint256 protocolBuffer,
        uint256 totalRequired
    ) {
        baseAmount = revenueTokenPrice * totalRevenueTokens;
        
        // Calculate expected earnings for the specified time interval
        uint256 expectedIntervalEarnings = (baseAmount * bufferTimeInterval) / ProtocolLib.YEARLY_INTERVAL;
        
        // Calculate time-based buffers
        earningsBuffer = (expectedIntervalEarnings * ProtocolLib.MIN_EARNINGS_BUFFER_BP) / ProtocolLib.BP_PRECISION;
        protocolBuffer = (expectedIntervalEarnings * ProtocolLib.MIN_PROTOCOL_BUFFER_BP) / ProtocolLib.BP_PRECISION;
        totalRequired = baseAmount + earningsBuffer + protocolBuffer;
    }
}
