// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
    uint256 internal constant BENCHMARK_EARNINGS_BP = 1000; // 10%
    uint256 internal constant PROTOCOL_FEE_BP = 250; // 2.5%
    uint256 internal constant EARLY_SALE_PENALTY_BP = 500; // 5%
    uint256 internal constant DEPRECIATION_RATE_BP = 1200; // 12% annually
    uint256 internal constant MIN_PROTOCOL_FEE = 1 * 10 ** 6; // 1 USDC (assuming 6 decimals)

    /**
     * @dev Validate IPFS URI format
     * @param uri IPFS URI to validate
     * @return True if valid IPFS URI
     */
    function isValidIPFSURI(string memory uri) internal pure returns (bool) {
        bytes memory uriBytes = bytes(uri);
        bytes memory prefix = bytes(IPFS_PREFIX);

        // Check minimum length
        if (uriBytes.length <= prefix.length) {
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
        uint256 fee = (amount * PROTOCOL_FEE_BP) / BP_PRECISION;
        if (amount > 0 && fee < MIN_PROTOCOL_FEE) {
            return MIN_PROTOCOL_FEE;
        }
        return fee;
    }

    /**
     * @dev Calculate early sale penalty
     * @param amount Amount to calculate penalty on
     * @param revenueTokenPrice Price per revenue token
     * @return Penalty amount
     */
    function calculatePenalty(uint256 amount, uint256 revenueTokenPrice) internal pure returns (uint256) {
        return (amount * revenueTokenPrice * EARLY_SALE_PENALTY_BP) / BP_PRECISION;
    }
}

/**
 * @dev Generic asset management library for protocol-wide asset operations
 * Provides common structures and functionality for all asset types
 */
library AssetLib {
    // Errors
    error InvalidAssetStatus(AssetStatus status);
    error InvalidStatusTransition(AssetStatus from, AssetStatus to);

    // Asset status enumeration for lifecycle management
    enum AssetStatus {
        Pending, // Asset exists but not operational
        Active, // Asset is operational and earning
        Suspended, // Temporarily halted operations
        Archived, // Permanently retired
        Expired, // Reached maturity without owner retirement
        Retired // Retired with settlement (Voluntary or Forced)
    }

    // Generic asset information structure
    struct AssetInfo {
        AssetStatus status; // Current asset status
        uint256 createdAt; // Asset registration timestamp
        uint256 updatedAt; // Last status/metadata update
        uint256 maturityDate; // Date by which asset must be retired
    }

    /**
     * @dev Initialize asset info
     * @param info Storage reference to asset info
     * @param maturityDate Asset maturity timestamp
     */
    function initializeAssetInfo(AssetInfo storage info, uint256 maturityDate) internal {
        info.status = AssetStatus.Pending;
        info.createdAt = block.timestamp;
        info.updatedAt = block.timestamp;
        info.maturityDate = maturityDate;
    }

    /**
     * @dev Update asset status with validation
     * @param info Storage reference to asset info
     * @param newStatus New status to set
     */
    function updateAssetStatus(AssetInfo storage info, AssetStatus newStatus) internal {
        AssetStatus currentStatus = info.status;

        // Validate status transition
        if (!isValidStatusTransition(currentStatus, newStatus)) {
            revert InvalidStatusTransition(currentStatus, newStatus);
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
        if (!isValidAssetStatus(to)) {
            revert InvalidAssetStatus(to);
        }

        if (!isValidAssetStatus(from)) {
            revert InvalidAssetStatus(from);
        }

        // Allow same status (no-op)
        if (from == to) return true;

        // Define valid transitions
        if (from == AssetStatus.Pending) {
            return to == AssetStatus.Active || to == AssetStatus.Expired;
        }

        if (from == AssetStatus.Active) {
            return to == AssetStatus.Suspended || to == AssetStatus.Archived || to == AssetStatus.Expired
                || to == AssetStatus.Retired;
        }

        if (from == AssetStatus.Suspended) {
            return to == AssetStatus.Active || to == AssetStatus.Archived || to == AssetStatus.Expired
                || to == AssetStatus.Retired;
        }

        if (from == AssetStatus.Expired) {
            return to == AssetStatus.Retired || to == AssetStatus.Archived;
        }

        // Archived and Retired are final states (mostly)
        if (from == AssetStatus.Archived || from == AssetStatus.Retired) {
            return false;
        }

        return false;
    }

    function isValidAssetStatus(AssetStatus status) internal pure returns (bool) {
        return status >= AssetStatus.Pending && status <= AssetStatus.Retired;
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
    // Errors
    error InvalidVINLength();
    error InvalidMake();
    error InvalidModel();
    error InvalidYear();
    error InvalidMetadataURI();

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
        AssetLib.AssetInfo assetInfo; // Standard asset management
        VehicleInfo vehicleInfo; // Immutable data + IPFS metadata URI
    }

    /**
     * @dev Initialize complete vehicle with asset info and vehicle-specific data
     */
    function initializeVehicle(
        Vehicle storage vehicle,
        uint256 vehicleId,
        string memory vin,
        string memory make,
        string memory model,
        uint256 year,
        uint256 manufacturerId,
        string memory optionCodes,
        string memory dynamicMetadataURI,
        uint256 maturityDate
    ) internal {
        // Set vehicle ID
        vehicle.vehicleId = vehicleId;

        // Initialize asset info
        AssetLib.initializeAssetInfo(vehicle.assetInfo, maturityDate);

        // Initialize vehicle-specific info
        initializeVehicleInfo(
            vehicle.vehicleInfo, vin, make, model, year, manufacturerId, optionCodes, dynamicMetadataURI
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
            revert InvalidVINLength();
        }
        if (bytes(make).length == 0) {
            revert InvalidMake();
        }
        if (bytes(model).length == 0) {
            revert InvalidModel();
        }
        if (year < 1990 || year > 2030) {
            revert InvalidYear();
        }
        if (!ProtocolLib.isValidIPFSURI(dynamicMetadataURI)) {
            revert InvalidMetadataURI();
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
            revert InvalidMetadataURI();
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
        uint256 tokenId; // ERC1155 token ID
        uint256 amount; // Number of tokens in this position
        uint256 acquiredAt; // Timestamp when position was acquired
        uint256 soldAt; // Timestamp when position was sold (0 if still held)
    }

    /**
     * @dev Token information for tracking
     */
    struct TokenInfo {
        uint256 tokenId; // ERC1155 token ID
        uint256 tokenPrice; // Price per token in USDC (6 decimals)
        uint256 tokenSupply; // Total number of tokens issued
        uint256 minHoldingPeriod; // Minimum holding period before penalty-free transfer
        // Track positions per user
        mapping(address => TokenPosition[]) positions;
    }

    error TokenLib__InsufficientTokenBalance();

    /**
     * @dev Initialize token info
     * @param info Storage reference to token info
     * @param tokenId ERC1155 token ID
     * @param tokenPrice Price per token in USDC
     * @param minHoldingPeriod Minimum holding period (defaults to MONTHLY_INTERVAL)
     */
    function initializeTokenInfo(TokenInfo storage info, uint256 tokenId, uint256 tokenPrice, uint256 minHoldingPeriod)
        internal
    {
        info.tokenId = tokenId;
        info.tokenPrice = tokenPrice;
        info.tokenSupply = 0; // Initialize to 0, will be updated by minting/burning
        info.minHoldingPeriod =
            minHoldingPeriod < ProtocolLib.MONTHLY_INTERVAL ? ProtocolLib.MONTHLY_INTERVAL : minHoldingPeriod;
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
            TokenPosition({ tokenId: info.tokenId, amount: amount, acquiredAt: block.timestamp, soldAt: 0 })
        );
    }

    /**
     * @dev Remove positions when tokens are transferred/sold
     * @param info Storage reference to token info
     * @param holder Address of the token holder
     * @param amount Number of tokens to remove
     */
    function removePosition(TokenInfo storage info, address holder, uint256 amount) internal {
        TokenPosition[] storage positions = info.positions[holder];
        uint256 remaining = amount;

        // Start from oldest position (FIFO)
        for (uint256 i = 0; i < positions.length && remaining > 0; i++) {
            TokenPosition storage pos = positions[i];

            if (pos.amount > 0) {
                uint256 toRemove = remaining > pos.amount ? pos.amount : remaining;

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
            }
        }
    }

    /**
     * @dev Calculates the early sale penalty for a given amount of tokens without modifying state.
     * @param info Storage reference to token info.
     * @param holder Address of the token holder.
     * @param amountToSell Number of tokens being sold.
     * @return penaltyAmount The calculated early sale penalty.
     */
    function calculateSalesPenalty(TokenInfo storage info, address holder, uint256 amountToSell)
        internal
        view
        returns (uint256 penaltyAmount)
    {
        if (amountToSell == 0) return 0;

        TokenPosition[] storage positions = info.positions[holder];
        uint256 remaining = amountToSell;
        uint256 totalPenalty;

        // Start from oldest position (FIFO)
        for (uint256 i = 0; i < positions.length && remaining > 0; i++) {
            TokenPosition storage pos = positions[i];

            if (pos.amount > 0) {
                // Only consider active positions
                uint256 toConsider = remaining > pos.amount ? pos.amount : remaining;

                // Calculate penalty if holding period not met
                if (block.timestamp < pos.acquiredAt + info.minHoldingPeriod) {
                    totalPenalty += ProtocolLib.calculatePenalty(toConsider, info.tokenPrice);
                }
                remaining -= toConsider;
            }
        }
        return totalPenalty;
    }

    /**
     * @dev Checks if a token ID corresponds to a revenue share token (even numbers).
     * @param tokenId The ID of the token to check.
     * @return True if the token is a revenue share token, false otherwise.
     */
    function isRevenueToken(uint256 tokenId) internal pure returns (bool) {
        return tokenId != 0 && tokenId % 2 == 0;
    }

    /**
     * @dev Calculate total value of tokens
     * @param info Storage reference to token info
     * @param tokenAmount Number of tokens
     * @return Total value in USDC
     */
    function calculateTokenValue(TokenInfo storage info, uint256 tokenAmount) internal view returns (uint256) {
        return info.tokenPrice * tokenAmount;
    }

    /**
     * @dev Check if position is eligible for penalty-free transfer
     * @param position The position to check
     * @param minHoldingPeriod Minimum holding period to check against
     * @return Whether the position can be transferred penalty-free
     */
    function isPositionMature(TokenPosition storage position, uint256 minHoldingPeriod) internal view returns (bool) {
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
            if (position.amount > 0) {
                // Active position
                // Calculate earnings for this position across unclaimed periods
                for (uint256 period = lastClaimedPeriod + 1; period <= earningsInfo.currentPeriod; period++) {
                    // Only count earnings for periods where the position was held
                    uint256 periodTimestamp = earningsInfo.periods[period].timestamp;
                    bool wasHeldDuringPeriod = position.acquiredAt <= periodTimestamp
                        && (position.soldAt == 0 || position.soldAt >= periodTimestamp);

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

    // Errors
    error InsufficientCollateral();
    error InvalidCollateralAmount();
    error CollateralAlreadyLocked();
    error NoCollateralLocked();

    /**
     * @dev Collateral information for vehicles with time-based calculations
     */
    struct CollateralInfo {
        uint256 initialBaseCollateral; // Initial base collateral amount (for linear depreciation)
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
     * @param tokenSupply Total number of revenue share tokens
     * @param bufferTimeInterval Time interval for buffer calculations (e.g., 90 days)
     */
    function initializeCollateralInfo(
        CollateralInfo storage info,
        uint256 revenueTokenPrice,
        uint256 tokenSupply,
        uint256 bufferTimeInterval
    ) internal {
        if (revenueTokenPrice == 0 || tokenSupply == 0) {
            revert InvalidCollateralAmount();
        }

        (uint256 baseAmount, uint256 earningsBuffer, uint256 protocolBuffer, uint256 totalCollateral) =
            calculateCollateralRequirements(revenueTokenPrice, tokenSupply, bufferTimeInterval);

        info.initialBaseCollateral = baseAmount;
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
     * @param revenueTokenPrice Price per revenue share token in USDC
     * @param tokenSupply Total number of revenue share tokens
     * @param bufferTimeInterval Time interval for buffer calculations (e.g., 90 days)
     * @return baseAmount Base collateral amount
     * @return earningsBuffer Earnings buffer amount
     * @return protocolBuffer Protocol buffer amount
     * @return totalCollateral Total collateral requirement
     */
    function calculateCollateralRequirements(uint256 revenueTokenPrice, uint256 tokenSupply, uint256 bufferTimeInterval)
        internal
        pure
        returns (uint256 baseAmount, uint256 earningsBuffer, uint256 protocolBuffer, uint256 totalCollateral)
    {
        // Calculate base collateral amount
        baseAmount = revenueTokenPrice * tokenSupply;

        // Calculate buffers for investor protection over the time interval
        earningsBuffer = EarningsLib.calculateBenchmarkEarnings(baseAmount, bufferTimeInterval);
        protocolBuffer = EarningsLib.calculateProtocolEarnings(baseAmount, bufferTimeInterval);

        // Total collateral is sum of base and buffers
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
     * @dev Calculate linear base collateral release amount based on initial base and elapsed time.
     *      Depreciation is linear at 12% per year, prorated by time, and does not compound.
     *      Buffers are not considered here; caller is responsible for gating and buffer processing.
     */
    function calculateCollateralRelease(CollateralInfo storage info) internal view returns (uint256 releaseAmount) {
        // Cumulative allowed release from initial base
        uint256 elapsedSinceLock = block.timestamp - info.lockedAt;
        uint256 cumulativeAllowed = (info.initialBaseCollateral * 1200 * elapsedSinceLock)
            / (ProtocolLib.BP_PRECISION * ProtocolLib.YEARLY_INTERVAL);

        // Already released from base
        uint256 releasedSoFar = info.initialBaseCollateral - info.baseCollateral;
        if (cumulativeAllowed <= releasedSoFar) {
            return 0;
        }

        releaseAmount = cumulativeAllowed - releasedSoFar;
        if (releaseAmount > info.baseCollateral) {
            releaseAmount = info.baseCollateral;
        }
    }

    /**
     * @dev Calculate depreciation based on time elapsed
     * @param baseAmount Base collateral amount
     * @param timeElapsed Time elapsed since last event
     * @return Depreciation amount
     */
    function calculateDepreciation(uint256 baseAmount, uint256 timeElapsed) internal pure returns (uint256) {
        return (baseAmount * ProtocolLib.DEPRECIATION_RATE_BP * timeElapsed)
            / (ProtocolLib.BP_PRECISION * ProtocolLib.YEARLY_INTERVAL);
    }

    /**
     * @dev Process earnings distribution and handle buffer replenishment/shortfall
     * @param info Collateral info storage reference
     * @param netEarnings Actual earnings received for the period
     * @param baseEarnings Expected base earnings for the period
     * @return earningsResult Positive: remaining excess earnings, Negative: shortfall amount, Zero: exact match
     * @return replenishmentAmount Amount replenished to earnings buffer from reserved funds
     */
    function processEarningsForBuffers(CollateralInfo storage info, uint256 netEarnings, uint256 baseEarnings)
        internal
        returns (int256 earningsResult, uint256 replenishmentAmount)
    {
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
            return (-int256(shortfallAmount), 0);
        }
        // Handle excess earnings (when netEarnings > baseEarnings)
        else if (netEarnings > baseEarnings) {
            uint256 excessEarnings = netEarnings - baseEarnings;

            // Calculate benchmark buffer amount (what buffer should be)
            uint256 benchmarkEarningsBuffer = getBenchmarkEarningsBuffer(info.baseCollateral);
            uint256 bufferDeficit =
                benchmarkEarningsBuffer > info.earningsBuffer ? benchmarkEarningsBuffer - info.earningsBuffer : 0;

            uint256 replenished = 0;
            if (info.reservedForLiquidation > 0) {
                // Replenish from reservedForLiquidation first
                uint256 toReplenish =
                    bufferDeficit < info.reservedForLiquidation ? bufferDeficit : info.reservedForLiquidation;
                toReplenish = toReplenish < excessEarnings ? toReplenish : excessEarnings;

                if (toReplenish > 0) {
                    info.earningsBuffer += toReplenish;
                    info.reservedForLiquidation -= toReplenish;
                    excessEarnings -= toReplenish;
                    replenished = toReplenish;

                    // Update total collateral
                    info.totalCollateral = info.baseCollateral + info.earningsBuffer + info.protocolBuffer;
                }
            }

            // Return remaining excess earnings and replenishment amount
            return (int256(excessEarnings), replenished);
        }

        // Perfect match: netEarnings == baseEarnings
        return (0, 0);
    }

    /**
     * @dev Get benchmark earnings buffer amount based on current base collateral
     * @param baseCollateral Current base collateral amount
     * @return Benchmark earnings buffer amount
     */
    function getBenchmarkEarningsBuffer(uint256 baseCollateral) internal pure returns (uint256) {
        uint256 benchmarkQuarterlyEarnings =
            (baseCollateral * ProtocolLib.QUARTERLY_INTERVAL) / ProtocolLib.YEARLY_INTERVAL;
        return (benchmarkQuarterlyEarnings * ProtocolLib.BENCHMARK_EARNINGS_BP) / ProtocolLib.BP_PRECISION;
    }

    /**
     * @dev Check if asset collateral is solvent
     * @param info Storage reference to collateral info
     * @return True if solvent (no reserved funds needed for liquidation)
     */
    function isSolvent(CollateralInfo storage info) internal view returns (bool) {
        return info.reservedForLiquidation == 0;
    }

    /**
     * @dev Get total collateral claimable by investors (excluding protocol buffer)
     * @param info Storage reference to collateral info
     * @return Total claimable amount in USDC
     */
    function getInvestorClaimableCollateral(CollateralInfo storage info) internal view returns (uint256) {
        // Claimable = Base + EarningsBuffer + ReservedForLiquidation (which is part of earnings buffer moved)
        return info.baseCollateral + info.earningsBuffer + info.reservedForLiquidation;
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
        uint256 timestamp; // When earnings were distributed
        uint256 totalEarnings; // Total USDC distributed in this period
    }

    /**
     * @dev Vehicle earnings tracking information
     */
    struct EarningsInfo {
        uint256 totalEarnings; // Total USDC earnings ever distributed
        uint256 totalEarningsPerToken; // Cumulative USDC earnings per token across all periods
        uint256 currentPeriod; // Current earnings period number
        uint256 lastEventTimestamp; // Last collateral event timestamp
        uint256 lastProcessedPeriod; // Last period processed for collateral release
        uint256 cumulativeBenchmarkEarnings; // Cumulative benchmark earnings for investor protection
        uint256 cumulativeExcessEarnings; // Cumulative excess earnings for performance bonus calculations
        bool isInitialized; // Whether earnings tracking is initialized
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
     * @dev Calculate earnings based on principal, time elapsed, and earnings rate
     * @param principal Base amount
     * @param timeElapsed Time elapsed in seconds
     * @param earningsBP Earnings rate in basis points
     * @return Earnings amount
     */
    function calculateEarnings(uint256 principal, uint256 timeElapsed, uint256 earningsBP)
        internal
        pure
        returns (uint256)
    {
        return (principal * timeElapsed * earningsBP) / (ProtocolLib.YEARLY_INTERVAL * ProtocolLib.BP_PRECISION);
    }

    /**
     * @dev Calculate benchmark earnings for investor protection
     * @param principal Base amount (revenue token price * total tokens)
     * @param timeElapsed Time elapsed in seconds
     * @return Benchmark earnings amount for investor safety
     */
    function calculateProtocolEarnings(uint256 principal, uint256 timeElapsed) internal pure returns (uint256) {
        return calculateEarnings(principal, timeElapsed, ProtocolLib.PROTOCOL_FEE_BP);
    }

    /**
     * @dev Calculate benchmark earnings for investor protection
     * @param principal Base amount (revenue token price * total tokens)
     * @param timeElapsed Time elapsed in seconds
     * @return Benchmark earnings amount for investor safety
     */
    function calculateBenchmarkEarnings(uint256 principal, uint256 timeElapsed) internal pure returns (uint256) {
        return calculateEarnings(principal, timeElapsed, ProtocolLib.BENCHMARK_EARNINGS_BP);
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
                    bool wasHeldDuringPeriod = position.acquiredAt <= periodTimestamp
                        && (position.soldAt == 0 || position.soldAt >= periodTimestamp);

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
