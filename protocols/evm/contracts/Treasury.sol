// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IAssetRegistry } from "./interfaces/IAssetRegistry.sol";
import { ProtocolLib, TokenLib, CollateralLib, EarningsLib } from "./Libraries.sol";
import { PartnerManager } from "./PartnerManager.sol";
import { RoboshareTokens } from "./RoboshareTokens.sol";

// Treasury errors
error Treasury__UnauthorizedPartner();
error Treasury__UnauthorizedContract();
error Treasury__NoCollateralLocked();
error Treasury__CollateralAlreadyLocked();
error Treasury__IncorrectCollateralAmount();
error Treasury__InsufficientCollateral();
error Treasury__NoPendingWithdrawals();
error Treasury__ZeroAddressNotAllowed();
error Treasury__TransferFailed();
error Treasury__AssetNotFound();
error Treasury__NotAssetOwner();
error Treasury__InvalidEarningsAmount();
error Treasury__NoEarningsToDistribute();
error Treasury__NoEarningsToClaim();
error Treasury__NoRevenueTokensIssued();
error Treasury__TooSoonForCollateralRelease();
error Treasury__NoPriorEarningsDistribution();
error Treasury__NoNewPeriodsToProcess();
error Treasury__InsufficientTokenBalance();
error Treasury__EarningsLessThanMinimumFee();

/**
 * @dev Treasury contract for USDC-based collateral management and earnings distribution.
 */
contract Treasury is Initializable, AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    using CollateralLib for CollateralLib.CollateralInfo;
    using TokenLib for TokenLib.TokenInfo;
    using EarningsLib for EarningsLib.EarningsInfo;
    using SafeERC20 for IERC20;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");
    bytes32 public constant AUTHORIZED_CONTRACT_ROLE = keccak256("AUTHORIZED_CONTRACT_ROLE");

    // Core contracts
    PartnerManager public partnerManager;
    IAssetRegistry public assetRegistry;
    RoboshareTokens public roboshareTokens;
    IERC20 public usdc;

    // Storage mappings
    mapping(uint256 => CollateralLib.CollateralInfo) public assetCollateral; // Collateral storage - assetId => CollateralInfo
    mapping(uint256 => EarningsLib.EarningsInfo) public assetEarnings; // Earnings tracking - assetId => EarningsInfo
    mapping(address => uint256) public pendingWithdrawals;

    // Treasury state
    uint256 public totalCollateralDeposited;
    uint256 public totalEarningsDeposited;
    address public treasuryFeeRecipient;

    // Events
    event CollateralLocked(uint256 indexed assetId, address indexed partner, uint256 amount);
    event CollateralReleased(uint256 indexed assetId, address indexed partner, uint256 amount);
    event ShortfallReserved(uint256 indexed assetId, uint256 amount);
    event BufferReplenished(uint256 indexed assetId, uint256 amount, uint256 fromReserved);
    event CollateralBuffersUpdated(
        uint256 indexed assetId, uint256 newEarningsBuffer, uint256 newReservedForLiquidation
    );
    event EarningsDistributed(uint256 indexed assetId, address indexed partner, uint256 amount, uint256 period);
    event EarningsClaimed(uint256 indexed assetId, address indexed holder, uint256 amount);
    event WithdrawalProcessed(address indexed recipient, uint256 amount);

    /**
     * @dev Modifier to restrict access to authorized partners
     */
    modifier onlyAuthorizedPartner() {
        if (!partnerManager.isAuthorizedPartner(msg.sender)) {
            revert Treasury__UnauthorizedPartner();
        }
        _;
    }

    /**
     * @dev Modifier to restrict access to authorized contracts
     */
    modifier onlyAuthorizedContract() {
        if (!hasRole(AUTHORIZED_CONTRACT_ROLE, msg.sender)) {
            revert Treasury__UnauthorizedContract();
        }
        _;
    }

    /**
     * @dev Initialize Treasury with core contract references
     */
    function initialize(
        address _admin,
        address _partnerManager,
        address _assetRegistry,
        address _roboshareTokens,
        address _usdc,
        address _treasuryFeeRecipient
    ) public initializer {
        if (
            _admin == address(0) || _partnerManager == address(0) || _assetRegistry == address(0)
                || _roboshareTokens == address(0) || _usdc == address(0) || _treasuryFeeRecipient == address(0)
        ) {
            revert Treasury__ZeroAddressNotAllowed();
        }

        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
        _grantRole(TREASURER_ROLE, _admin);

        partnerManager = PartnerManager(_partnerManager);
        assetRegistry = IAssetRegistry(_assetRegistry);
        roboshareTokens = RoboshareTokens(_roboshareTokens);
        usdc = IERC20(_usdc);
        treasuryFeeRecipient = _treasuryFeeRecipient;
    }

    // Collateral Locking Functions

    /**
     * @dev Lock USDC collateral for asset registration
     * Note: Partner must approve Treasury to spend USDC before calling this function
     * @param assetId The ID of the asset to lock collateral for
     * @param revenueTokenPrice Price per revenue share token in USDC (with decimals)
     * @param tokenSupply Total number of revenue share tokens to be issued
     */
    function lockCollateral(uint256 assetId, uint256 revenueTokenPrice, uint256 tokenSupply)
        external
        onlyAuthorizedPartner
        nonReentrant
    {
        // The balanceOf check is sufficient proof of existence, as NFTs are only minted upon registration.
        if (roboshareTokens.balanceOf(msg.sender, assetId) == 0) {
            revert Treasury__NotAssetOwner();
        }

        CollateralLib.CollateralInfo storage collateralInfo = assetCollateral[assetId];

        // Check if collateral is already locked
        if (collateralInfo.isLocked) {
            revert Treasury__CollateralAlreadyLocked();
        }

        // Initialize or update collateral info
        if (!CollateralLib.isInitialized(collateralInfo)) {
            CollateralLib.initializeCollateralInfo(
                collateralInfo, revenueTokenPrice, tokenSupply, ProtocolLib.QUARTERLY_INTERVAL
            );
        }

        uint256 requiredCollateral = collateralInfo.totalCollateral;

        // Transfer USDC from partner to treasury (requires prior approval)
        usdc.safeTransferFrom(msg.sender, address(this), requiredCollateral);

        // Mark collateral as locked
        collateralInfo.isLocked = true;
        collateralInfo.lockedAt = block.timestamp;
        collateralInfo.lastEventTimestamp = block.timestamp;

        totalCollateralDeposited += requiredCollateral;

        emit CollateralLocked(assetId, msg.sender, requiredCollateral);
    }

    /**
     * @dev Lock USDC collateral for asset registration (delegated call by authorized contracts)
     * @param partner The partner who owns the asset
     * @param assetId The ID of the asset to lock collateral for
     * @param revenueTokenPrice Price per revenue share token in USDC (with decimals)
     * @param tokenSupply Total number of revenue share tokens to be issued
     */
    function lockCollateralFor(address partner, uint256 assetId, uint256 revenueTokenPrice, uint256 tokenSupply)
        external
        onlyAuthorizedContract
        nonReentrant
    {
        // Verify partner is authorized
        if (!partnerManager.isAuthorizedPartner(partner)) {
            revert Treasury__UnauthorizedPartner();
        }

        // The balanceOf check is sufficient proof of existence, as NFTs are only minted upon registration.
        if (roboshareTokens.balanceOf(partner, assetId) == 0) {
            revert Treasury__NotAssetOwner();
        }

        CollateralLib.CollateralInfo storage collateralInfo = assetCollateral[assetId];

        // Check if collateral is already locked
        if (collateralInfo.isLocked) {
            revert Treasury__CollateralAlreadyLocked();
        }

        // Initialize or update collateral info
        if (!CollateralLib.isInitialized(collateralInfo)) {
            CollateralLib.initializeCollateralInfo(
                collateralInfo, revenueTokenPrice, tokenSupply, ProtocolLib.QUARTERLY_INTERVAL
            );
        }

        uint256 requiredCollateral = collateralInfo.totalCollateral;

        // Transfer USDC from partner to treasury (requires prior approval)
        usdc.safeTransferFrom(partner, address(this), requiredCollateral);

        // Mark collateral as locked
        collateralInfo.isLocked = true;
        collateralInfo.lockedAt = block.timestamp;
        collateralInfo.lastEventTimestamp = block.timestamp;

        totalCollateralDeposited += requiredCollateral;

        emit CollateralLocked(assetId, partner, requiredCollateral);
    }

    /**
     * @dev Release full collateral for asset (when partner owns all tokens)
     * @param assetId The ID of the asset to release collateral for
     */
    function releaseCollateral(uint256 assetId) external onlyAuthorizedPartner nonReentrant {
        // The balanceOf check is sufficient proof of existence, as NFTs are only minted upon registration.
        if (roboshareTokens.balanceOf(msg.sender, assetId) == 0) {
            revert Treasury__NotAssetOwner();
        }

        CollateralLib.CollateralInfo storage collateralInfo = assetCollateral[assetId];
        if (!collateralInfo.isLocked) {
            revert Treasury__NoCollateralLocked();
        }

        uint256 collateralAmount = collateralInfo.totalCollateral;

        // Unlock the collateral
        collateralInfo.isLocked = false;
        collateralInfo.lockedAt = 0;
        collateralInfo.baseCollateral = 0;
        collateralInfo.totalCollateral = 0;

        // Add to pending withdrawals
        pendingWithdrawals[msg.sender] += collateralAmount;
        totalCollateralDeposited -= collateralAmount;

        emit CollateralReleased(assetId, msg.sender, collateralAmount);
    }

    /**
     * @dev Process withdrawal from pending withdrawals
     */
    function processWithdrawal() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) {
            revert Treasury__NoPendingWithdrawals();
        }

        pendingWithdrawals[msg.sender] = 0;

        // Transfer USDC back to partner
        usdc.safeTransfer(msg.sender, amount);

        emit WithdrawalProcessed(msg.sender, amount);
    }

    /**
     * @dev Record a pending withdrawal for a recipient (for fees, etc.)
     * @param recipient The address to credit with a pending withdrawal
     * @param amount The amount to credit
     */
    function recordPendingWithdrawal(address recipient, uint256 amount) external onlyAuthorizedContract {
        if (amount > 0) {
            pendingWithdrawals[recipient] += amount;
        }
    }

    // Earnings Distribution Functions

    /**
     * @dev Distribute USDC earnings for revenue token holders
     * @param assetId The ID of the asset
     * @param amount Amount of USDC earnings to distribute
     */
    function distributeEarnings(uint256 assetId, uint256 amount) external onlyAuthorizedPartner nonReentrant {
        if (amount == 0) revert Treasury__InvalidEarningsAmount();
        if (amount < ProtocolLib.MINIMUM_PROTOCOL_FEE) revert Treasury__EarningsLessThanMinimumFee();

        // Verify partner owns the asset
        if (roboshareTokens.balanceOf(msg.sender, assetId) == 0) {
            revert Treasury__NotAssetOwner();
        }

        uint256 revenueTokenId = assetRegistry.getTokenIdFromAssetId(assetId);
        uint256 tokenTotalSupply = roboshareTokens.getRevenueTokenTotalSupply(revenueTokenId);
        if (tokenTotalSupply == 0) {
            revert Treasury__NoRevenueTokensIssued();
        }

        // Calculate protocol fee and net earnings
        uint256 protocolFee = ProtocolLib.calculateProtocolFee(amount);
        uint256 netEarnings = amount - protocolFee;

        // Transfer USDC from partner to treasury
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        // Initialize earnings tracking if needed
        EarningsLib.EarningsInfo storage earningsInfo = assetEarnings[assetId];
        if (!earningsInfo.isInitialized) {
            EarningsLib.initializeEarningsInfo(earningsInfo);
        }

        // Calculate earnings per token
        uint256 earningsPerToken = netEarnings / tokenTotalSupply;

        // Update earnings info
        earningsInfo.totalEarnings += netEarnings;
        earningsInfo.totalEarningsPerToken += earningsPerToken;
        earningsInfo.currentPeriod++;

        earningsInfo.periods[earningsInfo.currentPeriod] = EarningsLib.EarningsPeriod({
            earningsPerToken: earningsPerToken,
            timestamp: block.timestamp,
            totalEarnings: netEarnings
        });

        // Update treasury totals (total amount deposited, including protocol fees)
        totalEarningsDeposited += amount;

        // Add protocol fee to pending withdrawals for treasury fee collection
        if (protocolFee > 0) {
            pendingWithdrawals[treasuryFeeRecipient] += protocolFee;
        }

        emit EarningsDistributed(assetId, msg.sender, netEarnings, earningsInfo.currentPeriod);
    }

    /**
     * @dev Claim earnings from revenue token holdings
     * @param assetId The ID of the asset
     */
    function claimEarnings(uint256 assetId) external nonReentrant {
        // Verify asset exists
        if (!assetRegistry.assetExists(assetId)) {
            revert Treasury__AssetNotFound();
        }

        // Check token ownership (source of truth)
        uint256 revenueTokenId = assetRegistry.getTokenIdFromAssetId(assetId);
        uint256 tokenBalance = roboshareTokens.balanceOf(msg.sender, revenueTokenId);
        if (tokenBalance == 0) {
            revert Treasury__InsufficientTokenBalance();
        }

        // Get earnings info
        EarningsLib.EarningsInfo storage earningsInfo = assetEarnings[assetId];
        if (!earningsInfo.isInitialized || earningsInfo.currentPeriod == 0) {
            revert Treasury__NoEarningsToClaim();
        }

        // Get user's positions from RoboshareTokens (single source of truth)
        TokenLib.TokenPosition[] memory positions = roboshareTokens.getUserPositions(revenueTokenId, msg.sender);

        // Calculate position-based earnings using Treasury's claim tracking
        uint256 unclaimedAmount = EarningsLib.calculateEarningsForPositions(earningsInfo, msg.sender, positions);
        if (unclaimedAmount == 0) {
            revert Treasury__NoEarningsToClaim();
        }

        // Update claim periods for all positions
        EarningsLib.updateClaimPeriods(earningsInfo, msg.sender, positions);

        // Add to pending withdrawals
        pendingWithdrawals[msg.sender] += unclaimedAmount;

        emit EarningsClaimed(assetId, msg.sender, unclaimedAmount);
    }

    /**
     * @dev Release partial collateral based on depreciation and unprocessed earnings periods
     * @dev Aggregates all unprocessed earnings and processes buffer logic once
     * @param assetId The ID of the asset
     */
    function releasePartialCollateral(uint256 assetId) external onlyAuthorizedPartner nonReentrant {
        // Verify partner owns the asset
        if (roboshareTokens.balanceOf(msg.sender, assetId) == 0) {
            revert Treasury__NotAssetOwner();
        }

        CollateralLib.CollateralInfo storage collateralInfo = assetCollateral[assetId];
        EarningsLib.EarningsInfo storage earningsInfo = assetEarnings[assetId];

        // Early revert if no collateral locked
        if (!collateralInfo.isLocked) {
            revert Treasury__NoCollateralLocked();
        }

        // Early revert if no prior earnings distribution
        if (!earningsInfo.isInitialized || earningsInfo.currentPeriod == 0) {
            revert Treasury__NoPriorEarningsDistribution();
        }

        // Early revert if minimum interval not met
        uint256 timeSinceLastEvent = block.timestamp - collateralInfo.lastEventTimestamp;
        if (timeSinceLastEvent < ProtocolLib.MIN_EVENT_INTERVAL) {
            revert Treasury__TooSoonForCollateralRelease();
        }

        // Check if there are new periods to process for buffer calculation
        bool hasNewPeriods = earningsInfo.currentPeriod > earningsInfo.lastProcessedPeriod;

        // Performance gate: require at least one distribution since last release
        if (!hasNewPeriods) {
            revert Treasury__NoNewPeriodsToProcess();
        }

        // Process buffers across new periods
        {
            uint256 startPeriod = earningsInfo.lastProcessedPeriod;
            uint256 endPeriod = earningsInfo.currentPeriod;

            // Calculate benchmark earnings for the full period since last collateral event
            uint256 aggregatedBenchmarkEarnings =
                EarningsLib.calculateBenchmarkEarnings(collateralInfo.baseCollateral, timeSinceLastEvent);

            // Aggregate all unprocessed net earnings
            uint256 aggregatedNetEarnings = 0;
            for (uint256 i = startPeriod + 1; i <= endPeriod; i++) {
                aggregatedNetEarnings += earningsInfo.periods[i].totalEarnings;
            }

            // Process buffer replenishment/shortfall with aggregated values
            (int256 earningsResult, uint256 replenishmentAmount) = CollateralLib.processEarningsForBuffers(
                collateralInfo, aggregatedNetEarnings, aggregatedBenchmarkEarnings
            );

            // Emit shortfall event if applicable
            if (earningsResult < 0) {
                uint256 shortfallAmount = uint256(-earningsResult);
                emit ShortfallReserved(assetId, shortfallAmount);
            }
            // Handle remaining excess earnings
            else if (earningsResult > 0) {
                uint256 excessEarnings = uint256(earningsResult);
                // Add to cumulative excess earnings tracking
                earningsInfo.cumulativeExcessEarnings += excessEarnings;
            }

            // Emit buffer replenishment event if any buffer was replenished
            if (replenishmentAmount > 0) {
                emit BufferReplenished(assetId, replenishmentAmount, replenishmentAmount);
            }

            // Update processed period tracking
            earningsInfo.lastProcessedPeriod = endPeriod;
        }

        // Always emit buffer status update for transparency
        emit CollateralBuffersUpdated(assetId, collateralInfo.earningsBuffer, collateralInfo.reservedForLiquidation);

        // Calculate linear base-only collateral release amount
        uint256 releaseAmount = CollateralLib.calculateCollateralRelease(collateralInfo);
        if (releaseAmount == 0) {
            revert Treasury__InsufficientCollateral();
        }

        // Ensure we don't release more than available
        if (releaseAmount > collateralInfo.totalCollateral) {
            releaseAmount = collateralInfo.totalCollateral;
        }

        // Update collateral info
        collateralInfo.baseCollateral -= releaseAmount;
        collateralInfo.totalCollateral -= releaseAmount;
        collateralInfo.lastEventTimestamp = block.timestamp;

        // Update earnings info timestamps
        earningsInfo.lastEventTimestamp = block.timestamp;

        // Update treasury totals
        totalCollateralDeposited -= releaseAmount;

        // Add to pending withdrawals
        pendingWithdrawals[msg.sender] += releaseAmount;

        emit CollateralReleased(assetId, msg.sender, releaseAmount);
    }

    // View Functions

    /**
     * @dev Get collateral requirement for specific revenue token parameters
     * @param revenueTokenPrice Price per revenue share token in USDC
     * @param tokenSupply Total number of revenue share tokens
     * @return Total collateral requirement in USDC
     */
    function getCollateralRequirement(uint256 revenueTokenPrice, uint256 tokenSupply) external pure returns (uint256) {
        uint256 baseAmount = revenueTokenPrice * tokenSupply;
        (,, uint256 totalCollateral) =
            CollateralLib.calculateCollateralRequirements(baseAmount, ProtocolLib.QUARTERLY_INTERVAL);
        return totalCollateral;
    }

    /**
     * @dev Get collateral breakdown for display purposes
     * @param revenueTokenPrice Price per revenue share token in USDC
     * @param tokenSupply Total number of revenue share tokens
     * @return baseAmount Base collateral amount
     * @return earningsBuffer Earnings buffer amount
     * @return protocolBuffer Protocol buffer amount
     * @return totalRequired Total collateral required
     */
    function getCollateralBreakdown(uint256 revenueTokenPrice, uint256 tokenSupply)
        external
        pure
        returns (uint256 baseAmount, uint256 earningsBuffer, uint256 protocolBuffer, uint256 totalRequired)
    {
        return CollateralLib.getCollateralBreakdown(revenueTokenPrice, tokenSupply, ProtocolLib.QUARTERLY_INTERVAL);
    }

    /**
     * @dev Get asset's collateral information
     * @param assetId The ID of the asset
     * @return baseCollateral Base collateral amount
     * @return totalCollateral Total collateral amount
     * @return isLocked Whether collateral is locked
     * @return lockedAt Timestamp when locked
     * @return lockDuration Duration since lock in seconds
     */
    function getAssetCollateralInfo(uint256 assetId)
        external
        view
        returns (uint256 baseCollateral, uint256 totalCollateral, bool isLocked, uint256 lockedAt, uint256 lockDuration)
    {
        CollateralLib.CollateralInfo storage info = assetCollateral[assetId];
        return (
            info.baseCollateral, info.totalCollateral, info.isLocked, info.lockedAt, CollateralLib.getLockDuration(info)
        );
    }

    /**
     * @dev Get pending withdrawal amount for an address
     * @param account The account to check
     * @return Pending withdrawal amount
     */
    function getPendingWithdrawal(address account) external view returns (uint256) {
        return pendingWithdrawals[account];
    }

    /**
     * @dev Get treasury statistics
     * @return totalDeposited Total collateral deposited
     * @return treasuryBalance Current USDC balance
     */
    function getTreasuryStats() external view returns (uint256 totalDeposited, uint256 treasuryBalance) {
        return (totalCollateralDeposited, usdc.balanceOf(address(this)));
    }

    // Admin Functions

    /**
     * @dev Update partner manager reference
     * @param _partnerManager New partner manager address
     */
    function updatePartnerManager(address _partnerManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_partnerManager == address(0)) {
            revert Treasury__ZeroAddressNotAllowed();
        }
        partnerManager = PartnerManager(_partnerManager);
    }

    /**
     * @dev Update asset registry reference
     * @param _assetRegistry New asset registry address
     */
    function updateAssetRegistry(address _assetRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_assetRegistry == address(0)) {
            revert Treasury__ZeroAddressNotAllowed();
        }
        assetRegistry = IAssetRegistry(_assetRegistry);
    }

    /**
     * @dev Update USDC token reference
     * @param _usdc New USDC token address
     */
    function updateUSDC(address _usdc) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_usdc == address(0)) {
            revert Treasury__ZeroAddressNotAllowed();
        }
        usdc = IERC20(_usdc);
    }

    /**
     * @dev Update RoboshareTokens contract reference (for upgrades)
     * @param _roboshareTokens New RoboshareTokens contract address
     */
    function updateRoboshareTokens(address _roboshareTokens) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_roboshareTokens == address(0)) {
            revert Treasury__ZeroAddressNotAllowed();
        }
        roboshareTokens = RoboshareTokens(_roboshareTokens);
    }

    /**
     * @dev Update treasury fee recipient address
     * @param _treasuryFeeRecipient New treasury fee recipient address
     */
    function updateTreasuryFeeRecipient(address _treasuryFeeRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_treasuryFeeRecipient == address(0)) {
            revert Treasury__ZeroAddressNotAllowed();
        }
        treasuryFeeRecipient = _treasuryFeeRecipient;
    }

    // UUPS Upgrade authorization
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }
}
