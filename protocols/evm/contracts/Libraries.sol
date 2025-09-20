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
    uint256 internal constant MONTHLY_INTERVAL = 30 days;
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

    /**
     * @dev Calculate early sale penalty
     * @param amount Amount to calculate penalty on
     * @param revenueTokenPrice Price per revenue token
     * @return Penalty amount
     */
    function calculatePenalty(uint256 amount, uint256 revenueTokenPrice) internal pure returns (uint256) {
        uint256 EARLY_SALE_PENALTY_BP = 500; // 5%
        return (amount * revenueTokenPrice * EARLY_SALE_PENALTY_BP) / BP_PRECISION;
    }
}

/**
 * @dev Generic asset management library for protocol-wide asset operations
 * Provides common structures and functionality for all asset types
 */
library AssetsLib {
    // Asset status enumeration for lifecycle management
    enum AssetStatus { 
        Inactive,   // Asset exists but not operational
        Active,     // Asset is operational and earning
        Suspended,  // Temporarily halted operations
        Archived    // Permanently retired
    }
    
    // Generic asset information structure
    struct AssetInfo {
        AssetStatus status;        // Current asset status
        uint256 createdAt;         // Asset registration timestamp
        uint256 updatedAt;         // Last status/metadata update
    }

    // Asset lifecycle errors
    error AssetsLib__InvalidStatusTransition(AssetStatus from, AssetStatus to);
    error AssetsLib__AssetNotFound(uint256 assetId);
    error AssetsLib__AssetNotActive(uint256 assetId);

    /**
     * @dev Initialize asset info
     * @param info Storage reference to asset info
     * @param initialStatus Initial status (typically Inactive or Active)
     */
    function initializeAssetInfo(
        AssetInfo storage info,
        AssetStatus initialStatus
    ) internal {
        info.status = initialStatus;
        info.createdAt = block.timestamp;
        info.updatedAt = block.timestamp;
    }

    /**
     * @dev Update asset status with validation
     * @param info Storage reference to asset info
     * @param newStatus New status to set
     */
    function updateAssetStatus(
        AssetInfo storage info,
        AssetStatus newStatus
    ) internal {
        AssetStatus currentStatus = info.status;
        
        // Validate status transition
        if (!isValidStatusTransition(currentStatus, newStatus)) {
            revert AssetsLib__InvalidStatusTransition(currentStatus, newStatus);
        }
        
        info.status = newStatus;
        info.updatedAt = block.timestamp;
    }

    /**
     * @dev Check if status transition is valid
     * @param from Current status
     * @param to Target status
     * @return Whether the transition is allowed
     */
    function isValidStatusTransition(AssetStatus from, AssetStatus to) internal pure returns (bool) {
        // Allow same status (no-op)
        if (from == to) return true;
        
        // Define valid transitions
        if (from == AssetStatus.Inactive) {
            return to == AssetStatus.Active;
        }
        
        if (from == AssetStatus.Active) {
            return to == AssetStatus.Suspended || to == AssetStatus.Archived;
        }
        
        if (from == AssetStatus.Suspended) {
            return to == AssetStatus.Active || to == AssetStatus.Archived;
        }
        
        // Archived is final state
        if (from == AssetStatus.Archived) {
            return false;
        }
        
        return false;
    }

    /**
     * @dev Check if asset is operational (can earn/be used)
     * @param info Storage reference to asset info
     * @return Whether asset can be used for operations
     */
    function isOperational(AssetInfo storage info) internal view returns (bool) {
        return info.status == AssetStatus.Active;
    }

    /**
     * @dev Get asset age in seconds
     * @param info Storage reference to asset info
     * @return Age since creation
     */
    function getAssetAge(AssetInfo storage info) internal view returns (uint256) {
        return block.timestamp - info.createdAt;
    }

    /**
     * @dev Get time since last update
     * @param info Storage reference to asset info
     * @return Time since last status update
     */
    function getTimeSinceUpdate(AssetInfo storage info) internal view returns (uint256) {
        return block.timestamp - info.updatedAt;
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
        uint256 vehicleId; // Unique vehicle identifier
        AssetsLib.AssetInfo assetInfo; // Standard asset management
        VehicleInfo vehicleInfo; // Immutable data + IPFS metadata URI
    }

    /**
     * @dev Initialize complete vehicle with asset info and vehicle-specific data
     */
    function initializeVehicle(
        Vehicle storage vehicle,
        uint256 vehicleId,
        AssetsLib.AssetStatus initialStatus,
        string memory vin,
        string memory make,
        string memory model,
        uint256 year,
        uint256 manufacturerId,
        string memory optionCodes,
        string memory dynamicMetadataURI
    ) internal {
        // Set vehicle ID
        vehicle.vehicleId = vehicleId;
        
        // Initialize asset info
        AssetsLib.initializeAssetInfo(vehicle.assetInfo, initialStatus);
        
        // Initialize vehicle-specific info
        initializeVehicleInfo(
            vehicle.vehicleInfo,
            vin,
            make,
            model,
            year,
            manufacturerId,
            optionCodes,
            dynamicMetadataURI
        );
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
 * @dev Generic token library for position tracking and management
 * Handles ERC1155 token positions, transfers, and holding periods
 */
library TokenLib {
    using ProtocolLib for uint256;

    /**
     * @dev Individual token position
     */
    struct TokenPosition {
        uint256 tokenId;        // ERC1155 token ID
        uint256 amount;         // Number of tokens in this position
        uint256 acquiredAt;     // Timestamp when position was acquired
        uint256 soldAt;         // Timestamp when position was sold (0 if still held)
    }

    /**
     * @dev Token information for tracking
     */
    struct TokenInfo {
        uint256 tokenId;        // ERC1155 token ID
        uint256 totalSupply;    // Total number of tokens issued
        uint256 tokenPrice;     // Price per token in USDC (6 decimals)
        uint256 minHoldingPeriod; // Minimum holding period before penalty-free transfer
        // Track positions per user
        mapping(address => TokenPosition[]) positions;
        // Track total balance per user (for quick lookups)
        mapping(address => uint256) balances;
    }

    /**
     * @dev Initialize token info
     * @param info Storage reference to token info
     * @param tokenId ERC1155 token ID
     * @param totalSupply Total supply of tokens
     * @param tokenPrice Price per token in USDC
     * @param minHoldingPeriod Minimum holding period (defaults to MONTHLY_INTERVAL)
     */
    function initializeTokenInfo(
        TokenInfo storage info,
        uint256 tokenId,
        uint256 totalSupply,
        uint256 tokenPrice,
        uint256 minHoldingPeriod
    ) internal {
        info.tokenId = tokenId;
        info.totalSupply = totalSupply;
        info.tokenPrice = tokenPrice;
        info.minHoldingPeriod = minHoldingPeriod < ProtocolLib.MONTHLY_INTERVAL 
            ? ProtocolLib.MONTHLY_INTERVAL 
            : minHoldingPeriod;
        // mappings are automatically initialized
    }

    /**
     * @dev Add a new position for a token holder
     * @param info Storage reference to token info
     * @param holder Address of the token holder
     * @param amount Number of tokens in the position
     */
    function addPosition(TokenInfo storage info, address holder, uint256 amount) internal {
        info.positions[holder].push(
            TokenPosition({
                tokenId: info.tokenId,
                amount: amount,
                acquiredAt: block.timestamp,
                soldAt: 0
            })
        );
        info.balances[holder] += amount;
    }

    /**
     * @dev Remove positions when tokens are transferred/sold
     * @param info Storage reference to token info
     * @param holder Address of the token holder
     * @param amount Number of tokens to remove
     * @param checkPenalty Whether to calculate early sale penalty
     * @return penaltyAmount Early sale penalty if applicable
     */
    function removePosition(TokenInfo storage info, address holder, uint256 amount, bool checkPenalty)
        internal
        returns (uint256 penaltyAmount)
    {
        require(info.balances[holder] >= amount, "TokenLib: Insufficient balance");

        TokenPosition[] storage positions = info.positions[holder];
        uint256 remaining = amount;
        uint256 totalPenalty;

        // Start from oldest position (FIFO)
        for (uint256 i = 0; i < positions.length && remaining > 0; i++) {
            TokenPosition storage pos = positions[i];

            if (pos.amount > 0) {
                uint256 toRemove = remaining > pos.amount ? pos.amount : remaining;

                // Calculate penalty if holding period not met
                if (checkPenalty && block.timestamp < pos.acquiredAt + info.minHoldingPeriod) {
                    totalPenalty += ProtocolLib.calculatePenalty(toRemove, info.tokenPrice);
                }

                // If partial transfer, create new position for remaining amount
                if (toRemove < pos.amount) {
                    uint256 remainingAmount = pos.amount - toRemove;
                    info.positions[holder].push(
                        TokenPosition({
                            tokenId: pos.tokenId,
                            amount: remainingAmount,
                            acquiredAt: pos.acquiredAt,
                            soldAt: 0
                        })
                    );
                }

                // Mark original position as sold
                pos.amount = 0;
                pos.soldAt = block.timestamp;

                remaining -= toRemove;
                info.balances[holder] -= toRemove;
            }
        }

        return totalPenalty;
    }

    /**
     * @dev Calculate total value of tokens
     * @param info Storage reference to token info
     * @param tokenAmount Number of tokens
     * @return Total value in USDC
     */
    function calculateTokenValue(TokenInfo storage info, uint256 tokenAmount) 
        internal 
        view 
        returns (uint256) 
    {
        return info.tokenPrice * tokenAmount;
    }

    /**
     * @dev Get user's current token balance
     * @param info Storage reference to token info
     * @param holder Address of the token holder
     * @return Current token balance
     */
    function getBalance(TokenInfo storage info, address holder) internal view returns (uint256) {
        return info.balances[holder];
    }

    /**
     * @dev Check if position is eligible for penalty-free transfer
     * @param position The position to check
     * @param minHoldingPeriod Minimum holding period to check against
     * @return Whether the position can be transferred penalty-free
     */
    function isPositionMature(TokenPosition storage position, uint256 minHoldingPeriod) 
        internal 
        view 
        returns (bool) 
    {
        return block.timestamp >= position.acquiredAt + minHoldingPeriod;
    }

    /**
     * @dev Calculate unclaimed earnings for positions between periods
     * @param info Storage reference to token info
     * @param holder Address of the token holder
     * @param earningsInfo Reference to earnings info for period data
     * @param lastClaimedPeriod Last period claimed by holder
     * @return unclaimedAmount Total unclaimed earnings
     */
    function calculateUnclaimedEarningsForPositions(
        TokenInfo storage info,
        address holder,
        EarningsLib.EarningsInfo storage earningsInfo,
        uint256 lastClaimedPeriod
    ) internal view returns (uint256 unclaimedAmount) {
        TokenPosition[] storage positions = info.positions[holder];
        
        for (uint256 i = 0; i < positions.length; i++) {
            TokenPosition storage position = positions[i];
            if (position.amount > 0) { // Active position
                // Calculate earnings for this position across unclaimed periods
                for (uint256 period = lastClaimedPeriod + 1; period <= earningsInfo.currentPeriod; period++) {
                    // Only count earnings for periods where the position was held
                    uint256 periodTimestamp = earningsInfo.periods[period].timestamp;
                    bool wasHeldDuringPeriod = position.acquiredAt <= periodTimestamp && 
                                             (position.soldAt == 0 || position.soldAt >= periodTimestamp);
                    
                    if (wasHeldDuringPeriod) {
                        unclaimedAmount += earningsInfo.periods[period].earningsPerToken * position.amount;
                    }
                }
            }
        }
        
        return unclaimedAmount;
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
        uint256 earningsBuffer; // Current earnings buffer amount
        uint256 protocolBuffer; // Current protocol buffer amount
        uint256 totalCollateral; // Total required collateral in USDC
        bool isLocked; // Whether collateral is currently locked
        uint256 lockedAt; // Timestamp when collateral was locked
        uint256 lastEventTimestamp; // Last collateral event timestamp
        uint256 reservedForLiquidation; // Tracks shortfalls reserved for liquidation
        uint256 liquidationThreshold; // Threshold for liquidation
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

        uint256 baseAmount = revenueTokenPrice * totalRevenueTokens;
        (uint256 earningsBuffer, uint256 protocolBuffer, uint256 totalCollateral) = 
            calculateCollateralRequirements(baseAmount, bufferTimeInterval);

        info.baseCollateral = baseAmount;
        info.earningsBuffer = earningsBuffer;
        info.protocolBuffer = protocolBuffer;
        info.totalCollateral = totalCollateral;
        info.isLocked = false;
        info.lockedAt = 0;
        info.lastEventTimestamp = block.timestamp;
        info.reservedForLiquidation = 0;
        info.liquidationThreshold = earningsBuffer; // Set initial liquidation threshold to earnings buffer
        info.createdAt = block.timestamp;
    }

    /**
     * @dev Calculate collateral requirements with separate buffer components
     * @param baseAmount Base collateral amount (revenueTokenPrice * totalRevenueTokens)
     * @param bufferTimeInterval Time interval for buffer calculations (e.g., 90 days)
     * @return earningsBuffer Earnings buffer amount
     * @return protocolBuffer Protocol buffer amount
     * @return totalCollateral Total collateral requirement
     */
    function calculateCollateralRequirements(
        uint256 baseAmount,
        uint256 bufferTimeInterval
    ) internal pure returns (uint256 earningsBuffer, uint256 protocolBuffer, uint256 totalCollateral) {
        // Calculate expected earnings for the specified time interval
        uint256 expectedIntervalEarnings = (baseAmount * bufferTimeInterval) / ProtocolLib.YEARLY_INTERVAL;
        
        // Calculate buffers for investor protection over the time interval
        earningsBuffer = (expectedIntervalEarnings * ProtocolLib.MIN_EARNINGS_BUFFER_BP) / ProtocolLib.BP_PRECISION;
        protocolBuffer = (expectedIntervalEarnings * ProtocolLib.MIN_PROTOCOL_BUFFER_BP) / ProtocolLib.BP_PRECISION;
        totalCollateral = baseAmount + earningsBuffer + protocolBuffer;
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

    /**
     * @dev Calculate depreciation based on time elapsed
     * @param baseAmount Base collateral amount
     * @param timeElapsed Time elapsed since last event
     * @return Depreciation amount
     */
    function calculateDepreciation(uint256 baseAmount, uint256 timeElapsed) internal pure returns (uint256) {
        uint256 DEPRECIATION_RATE_BP = 1200; // 12% annually
        return (baseAmount * DEPRECIATION_RATE_BP * timeElapsed) / (ProtocolLib.BP_PRECISION * ProtocolLib.YEARLY_INTERVAL);
    }

    /**
     * @dev Process earnings distribution and handle buffer replenishment/shortfall
     * @param info Collateral info storage reference
     * @param netEarnings Actual earnings received for the period
     * @param baseEarnings Expected base earnings for the period
     * @return earningsResult Positive: remaining excess earnings, Negative: shortfall amount, Zero: exact match
     */
    function processEarningsForBuffers(
        CollateralInfo storage info,
        uint256 netEarnings,
        uint256 baseEarnings
    ) internal returns (int256 earningsResult) {
        // Handle shortfall (when netEarnings < baseEarnings)
        if (netEarnings < baseEarnings) {
            uint256 shortfallAmount = baseEarnings - netEarnings;
            
            if (info.earningsBuffer >= shortfallAmount) {
                // Earnings buffer can cover the shortfall
                info.earningsBuffer -= shortfallAmount;
                info.reservedForLiquidation += shortfallAmount;
            } else {
                // Earnings buffer can't fully cover shortfall
                info.reservedForLiquidation += info.earningsBuffer;
                info.earningsBuffer = 0;
            }
            // Update total collateral to reflect the shortfall impact (covers both cases above)
            info.totalCollateral = info.baseCollateral + info.earningsBuffer + info.protocolBuffer;
            
            // Return negative value to indicate shortfall
            return -int256(shortfallAmount);
        }
        // Handle excess earnings (when netEarnings > baseEarnings)
        else if (netEarnings > baseEarnings) {
            uint256 excessEarnings = netEarnings - baseEarnings;
            
            // Calculate target buffer amount (what buffer should be)
            uint256 targetEarningsBuffer = getTargetEarningsBuffer(info.baseCollateral);
            uint256 bufferDeficit = targetEarningsBuffer > info.earningsBuffer 
                ? targetEarningsBuffer - info.earningsBuffer 
                : 0;

            if (info.reservedForLiquidation > 0) {
                // Replenish from reservedForLiquidation first
                uint256 toReplenish = bufferDeficit < info.reservedForLiquidation 
                    ? bufferDeficit 
                    : info.reservedForLiquidation;
                toReplenish = toReplenish < excessEarnings ? toReplenish : excessEarnings;
                
                info.earningsBuffer += toReplenish;
                info.reservedForLiquidation -= toReplenish;
                excessEarnings -= toReplenish;
                
                // Update total collateral
                info.totalCollateral = info.baseCollateral + info.earningsBuffer + info.protocolBuffer;
            }
            
            // Return remaining excess earnings
            return int256(excessEarnings);
        }
        
        // Perfect match: netEarnings == baseEarnings
        return 0;
    }

    /**
     * @dev Get target earnings buffer amount based on current base collateral
     * @param baseCollateral Current base collateral amount
     * @return Target earnings buffer amount
     */
    function getTargetEarningsBuffer(uint256 baseCollateral) internal pure returns (uint256) {
        uint256 expectedQuarterlyEarnings = (baseCollateral * ProtocolLib.QUARTERLY_INTERVAL) / ProtocolLib.YEARLY_INTERVAL;
        return (expectedQuarterlyEarnings * ProtocolLib.MIN_EARNINGS_BUFFER_BP) / ProtocolLib.BP_PRECISION;
    }
}

/**
 * @dev Earnings distribution library for USDC-based earnings calculations
 * Contains pure calculation functions for earnings and benchmark tracking
 */
library EarningsLib {
    /**
     * @dev Earnings period information
     */
    struct EarningsPeriod {
        uint256 earningsPerToken; // USDC earnings per revenue token
        uint256 timestamp;        // When earnings were distributed
        uint256 totalEarnings;    // Total USDC distributed in this period
    }

    /**
     * @dev Vehicle earnings tracking information
     */
    struct EarningsInfo {
        uint256 totalEarnings;            // Total USDC earnings ever distributed
        uint256 totalEarningsPerToken;    // Cumulative USDC earnings per token across all periods
        uint256 currentPeriod;           // Current earnings period number
        uint256 lastEventTimestamp;      // Last collateral event timestamp
        uint256 lastProcessedPeriod;     // Last period processed for collateral release
        uint256 cumulativeBenchmarkEarnings; // Cumulative benchmark earnings for investor protection
        bool isInitialized;              // Whether earnings tracking is initialized
        mapping(uint256 => EarningsPeriod) periods; // period => earnings data
        // Track last claimed period for each individual position
        mapping(address => mapping(uint256 => mapping(uint256 => uint256))) positionsLastClaimedPeriod; // holder => tokenId => positionIndex => lastClaimedPeriod
    }

    /**
     * @dev Initialize earnings tracking for a vehicle
     * @param earningsInfo Storage reference to earnings info
     */
    function initializeEarningsInfo(EarningsInfo storage earningsInfo) internal {
        earningsInfo.totalEarnings = 0;
        earningsInfo.totalEarningsPerToken = 0;
        earningsInfo.currentPeriod = 0;
        earningsInfo.lastEventTimestamp = block.timestamp;
        earningsInfo.lastProcessedPeriod = 0;
        earningsInfo.cumulativeBenchmarkEarnings = 0;
        earningsInfo.isInitialized = true;
    }

    /**
     * @dev Calculate benchmark earnings for investor protection
     * @param principal Base amount (revenue token price * total tokens)
     * @param timeElapsed Time elapsed in seconds
     * @param earningsBP Earnings rate in basis points
     * @return Benchmark earnings amount for investor safety
     */
    function calculateBenchmarkEarnings(uint256 principal, uint256 timeElapsed, uint256 earningsBP)
        internal
        pure
        returns (uint256)
    {
        uint256 effectiveRate = earningsBP > ProtocolLib.MIN_EARNINGS_BUFFER_BP 
            ? earningsBP 
            : ProtocolLib.MIN_EARNINGS_BUFFER_BP;
        return (principal * effectiveRate * timeElapsed) / (ProtocolLib.BP_PRECISION * ProtocolLib.YEARLY_INTERVAL);
    }

    /**
     * @dev Calculate benchmark earnings using default minimum rate
     * @param principal Base amount
     * @param timeElapsed Time elapsed in seconds
     * @return Benchmark earnings amount
     */
    function calculateBenchmarkEarnings(uint256 principal, uint256 timeElapsed)
        internal
        pure
        returns (uint256)
    {
        return calculateBenchmarkEarnings(principal, timeElapsed, ProtocolLib.MIN_EARNINGS_BUFFER_BP);
    }

    /**
     * @dev Calculate unclaimed earnings for a token holder
     * @param earningsInfo Storage reference to earnings info
     * @param tokenBalance Current token balance
     * @param lastClaimedPeriod Last period claimed by holder
     * @return unclaimedAmount Unclaimed USDC earnings
     */
    function calculateUnclaimedEarnings(
        EarningsInfo storage earningsInfo,
        uint256 tokenBalance,
        uint256 lastClaimedPeriod
    ) internal view returns (uint256 unclaimedAmount) {
        if (tokenBalance == 0 || earningsInfo.currentPeriod <= lastClaimedPeriod) {
            return 0;
        }

        // Sum earnings from all unclaimed periods
        for (uint256 i = lastClaimedPeriod + 1; i <= earningsInfo.currentPeriod; i++) {
            unclaimedAmount += earningsInfo.periods[i].earningsPerToken * tokenBalance;
        }

        return unclaimedAmount;
    }

    /**
     * @dev Calculate collateral release amount (simple depreciation)
     * @param earningsInfo Storage reference to earnings info
     * @param collateralInfo Storage reference to collateral info
     * @return releaseAmount Amount of collateral to release based on depreciation
     * @return canRelease Whether enough time has passed for release
     */
    function calculateCollateralRelease(
        EarningsInfo storage earningsInfo,
        CollateralLib.CollateralInfo storage collateralInfo
    ) internal view returns (uint256 releaseAmount, bool canRelease) {
        // Check time restrictions
        uint256 timeSinceLastEvent = block.timestamp - earningsInfo.lastEventTimestamp;
        if (timeSinceLastEvent < ProtocolLib.MIN_EVENT_INTERVAL) {
            return (0, false);
        }

        // Check for new periods to process
        if (earningsInfo.currentPeriod <= earningsInfo.lastProcessedPeriod) {
            return (0, false);
        }

        // Calculate simple depreciation release
        releaseAmount = CollateralLib.calculateDepreciation(collateralInfo.baseCollateral, timeSinceLastEvent);
        canRelease = true;

        return (releaseAmount, canRelease);
    }

    /**
     * @dev Calculate earnings for positions with per-position claim tracking  
     * @param earningsInfo Storage reference to earnings info
     * @param holder Address of the token holder
     * @param positions Memory array of user's positions
     * @return totalEarnings Total claimable earnings
     */
    function calculateEarningsForPositions(
        EarningsInfo storage earningsInfo,
        address holder,
        TokenLib.TokenPosition[] memory positions
    ) internal view returns (uint256 totalEarnings) {
        for (uint256 i = 0; i < positions.length; i++) {
            TokenLib.TokenPosition memory position = positions[i];
            if (position.amount > 0) {
                uint256 lastClaimedPeriod = earningsInfo.positionsLastClaimedPeriod[holder][position.tokenId][i];
                uint256 endPeriod = position.soldAt > 0 
                    ? getPeriodAtTimestamp(earningsInfo, position.soldAt)
                    : earningsInfo.currentPeriod;
                
                // Calculate unclaimed earnings for this position
                for (uint256 period = lastClaimedPeriod + 1; period <= endPeriod; period++) {
                    uint256 periodTimestamp = earningsInfo.periods[period].timestamp;
                    bool wasHeldDuringPeriod = position.acquiredAt <= periodTimestamp && 
                                             (position.soldAt == 0 || position.soldAt >= periodTimestamp);
                    
                    if (wasHeldDuringPeriod) {
                        totalEarnings += earningsInfo.periods[period].earningsPerToken * position.amount;
                    }
                }
            }
        }
        return totalEarnings;
    }

    /**
     * @dev Update claim periods for all positions
     * @param earningsInfo Storage reference to earnings info
     * @param holder Address of the token holder
     * @param positions Memory array of user's positions  
     */
    function updateClaimPeriods(
        EarningsInfo storage earningsInfo,
        address holder,
        TokenLib.TokenPosition[] memory positions
    ) internal {
        for (uint256 i = 0; i < positions.length; i++) {
            TokenLib.TokenPosition memory position = positions[i];
            earningsInfo.positionsLastClaimedPeriod[holder][position.tokenId][i] = earningsInfo.currentPeriod;
        }
    }

    /**
     * @dev Get period number at specific timestamp
     * @param earningsInfo Storage reference to earnings info
     * @param timestamp Timestamp to find period for
     * @return period Period number at timestamp
     */
    function getPeriodAtTimestamp(EarningsInfo storage earningsInfo, uint256 timestamp)
        internal
        view
        returns (uint256 period)
    {
        period = earningsInfo.currentPeriod;
        while (period > 0 && earningsInfo.periods[period].timestamp > timestamp) {
            period--;
        }
        return period;
    }
}
