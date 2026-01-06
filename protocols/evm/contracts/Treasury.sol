// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IAssetRegistry } from "./interfaces/IAssetRegistry.sol";
import { ITreasury } from "./interfaces/ITreasury.sol";
import { ProtocolLib, TokenLib, CollateralLib, EarningsLib, AssetLib } from "./Libraries.sol";
import { RoboshareTokens } from "./RoboshareTokens.sol";
import { PartnerManager } from "./PartnerManager.sol";
import { RegistryRouter } from "./RegistryRouter.sol";

/**
 * @dev Treasury contract for USDC-based collateral management and earnings distribution.
 */
contract Treasury is Initializable, AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable, ITreasury {
    using CollateralLib for CollateralLib.CollateralInfo;
    using TokenLib for TokenLib.TokenInfo;
    using EarningsLib for EarningsLib.EarningsInfo;
    using SafeERC20 for IERC20;
    using SafeCast for int256;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");
    bytes32 public constant AUTHORIZED_CONTRACT_ROLE = keccak256("AUTHORIZED_CONTRACT_ROLE");
    bytes32 public constant AUTHORIZED_ROUTER_ROLE = keccak256("AUTHORIZED_ROUTER_ROLE");

    // Core contracts
    PartnerManager public partnerManager;
    RoboshareTokens public roboshareTokens;
    RegistryRouter public router;
    IERC20 public usdc;

    // Storage mappings
    mapping(uint256 => CollateralLib.CollateralInfo) public assetCollateral; // Collateral storage - assetId => CollateralInfo
    mapping(uint256 => EarningsLib.EarningsInfo) public assetEarnings; // Earnings tracking - assetId => EarningsInfo
    mapping(uint256 => CollateralLib.AssetSettlement) public assetSettlements; // Settlement info - assetId => AssetSettlement
    mapping(address => uint256) public pendingWithdrawals;

    // Treasury state
    uint256 public totalCollateralDeposited;
    uint256 public totalEarningsDeposited;
    address public treasuryFeeRecipient;

    // Internal Errors (not part of public API)
    error ZeroAddress();
    error EarningsLessThanMinimumFee();
    error NoNewPeriodsToProcess();
    /// Unused (why?)
    error IncorrectCollateralAmount();
    error TransferFailed();
    error NoEarningsToDistribute();
    error NotRouter();

    /**
     * @dev Modifier to restrict access to authorized partners
     */
    modifier onlyAuthorizedPartner() {
        _onlyAuthorizedPartner();
        _;
    }

    function _onlyAuthorizedPartner() internal view {
        if (!partnerManager.isAuthorizedPartner(msg.sender)) {
            revert UnauthorizedPartner();
        }
    }

    /**
     * @dev Initialize Treasury with core contract references
     */
    function initialize(
        address _admin,
        address _roboshareTokens,
        address _partnerManager,
        address _router,
        address _usdc,
        address _treasuryFeeRecipient
    ) public initializer {
        if (
            _admin == address(0) || _roboshareTokens == address(0) || _partnerManager == address(0)
                || _router == address(0) || _usdc == address(0) || _treasuryFeeRecipient == address(0)
        ) {
            revert ZeroAddress();
        }

        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
        _grantRole(TREASURER_ROLE, _admin);
        _grantRole(AUTHORIZED_ROUTER_ROLE, _router);

        roboshareTokens = RoboshareTokens(_roboshareTokens);
        partnerManager = PartnerManager(_partnerManager);
        router = RegistryRouter(_router);
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
            revert NotAssetOwner();
        }

        CollateralLib.CollateralInfo storage collateralInfo = assetCollateral[assetId];

        // Check if collateral is already locked
        if (collateralInfo.isLocked) {
            revert CollateralAlreadyLocked();
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
        onlyRole(AUTHORIZED_ROUTER_ROLE)
        nonReentrant
    {
        // Verify partner is authorized
        if (!partnerManager.isAuthorizedPartner(partner)) {
            revert UnauthorizedPartner();
        }

        // The balanceOf check is sufficient proof of existence, as NFTs are only minted upon registration.
        if (roboshareTokens.balanceOf(partner, assetId) == 0) {
            revert NotAssetOwner();
        }

        CollateralLib.CollateralInfo storage collateralInfo = assetCollateral[assetId];

        // Check if collateral is already locked
        if (collateralInfo.isLocked) {
            revert CollateralAlreadyLocked();
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
            revert NotAssetOwner();
        }

        CollateralLib.CollateralInfo storage collateralInfo = assetCollateral[assetId];
        if (!collateralInfo.isLocked) {
            revert NoCollateralLocked();
        }

        _releaseCollateral(assetId, msg.sender);
    }

    /**
     * @dev Release collateral for a retired asset (called by registry)
     * @param partner The partner address receiving the collateral
     * @param assetId The ID of the asset being retired
     */
    function releaseCollateralFor(address partner, uint256 assetId)
        external
        onlyRole(AUTHORIZED_ROUTER_ROLE)
        nonReentrant
        returns (uint256 releasedCollateral)
    {
        CollateralLib.CollateralInfo storage collateralInfo = assetCollateral[assetId];

        if (collateralInfo.isLocked) {
            releasedCollateral = collateralInfo.totalCollateral;
            _releaseCollateral(assetId, partner);
        }
    }

    function _releaseCollateral(uint256 assetId, address recipient) internal {
        // Ensure no outstanding revenue tokens
        // Registry is responsible for burning tokens before calling retirement
        uint256 revenueTokenId = router.getTokenIdFromAssetId(assetId);
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);

        if (totalSupply > 0) {
            revert OutstandingRevenueTokens();
        }

        uint256 collateralAmount = _clearCollateral(assetId);

        // Add to pending withdrawals
        pendingWithdrawals[recipient] += collateralAmount;

        emit CollateralReleased(assetId, recipient, collateralAmount);
    }

    /**
     * @dev Internal helper to clear collateral state and update global tracking
     */
    function _clearCollateral(uint256 assetId) internal returns (uint256 totalReleased) {
        CollateralLib.CollateralInfo storage info = assetCollateral[assetId];
        totalReleased = info.totalCollateral;

        info.isLocked = false;
        info.baseCollateral = 0;
        info.earningsBuffer = 0;
        info.protocolBuffer = 0;
        info.reservedForLiquidation = 0;
        info.totalCollateral = 0;

        if (totalCollateralDeposited >= totalReleased) {
            totalCollateralDeposited -= totalReleased;
        }
    }

    /**
     * @dev Process withdrawal from pending withdrawals
     */
    function processWithdrawal() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) {
            revert NoPendingWithdrawals();
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
    function recordPendingWithdrawal(address recipient, uint256 amount) external onlyRole(AUTHORIZED_CONTRACT_ROLE) {
        if (amount > 0) {
            pendingWithdrawals[recipient] += amount;
        }
    }

    // Earnings Distribution Functions

    /**
     * @dev Distribute USDC earnings for revenue token holders
     * @param assetId The ID of the asset
     * @param totalRevenue Total revenue generated by the asset (for tracking only)
     * @param investorAmount Amount of USDC to distribute to investors (what partner actually deposits)
     * @param tryAutoRelease If true, attempt to release eligible collateral in the same transaction
     * @return collateralReleased Amount of collateral released (0 if tryAutoRelease=false or not eligible)
     */
    function distributeEarnings(uint256 assetId, uint256 totalRevenue, uint256 investorAmount, bool tryAutoRelease)
        external
        onlyAuthorizedPartner
        nonReentrant
        returns (uint256 collateralReleased)
    {
        if (investorAmount == 0) revert InvalidEarningsAmount();
        if (investorAmount < ProtocolLib.MIN_PROTOCOL_FEE) {
            revert EarningsLessThanMinimumFee();
        }
        if (totalRevenue < investorAmount) {
            revert InvalidEarningsAmount(); // totalRevenue must be >= investorAmount
        }

        // Verify partner owns the asset
        if (roboshareTokens.balanceOf(msg.sender, assetId) == 0) {
            revert NotAssetOwner();
        }

        // Verify asset is still active (not settled/retired)
        AssetLib.AssetStatus status = router.getAssetStatus(assetId);
        if (status != AssetLib.AssetStatus.Active) {
            revert AssetNotActive(assetId, status);
        }

        uint256 revenueTokenId = router.getTokenIdFromAssetId(assetId);
        uint256 tokenTotalSupply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);
        // Note: tokenTotalSupply > 0 is guaranteed for Active assets since
        // assets can only become Active after minting tokens and locking collateral.

        // Get partner's token balance to calculate investor token count
        uint256 partnerTokenBalance = roboshareTokens.balanceOf(msg.sender, revenueTokenId);
        uint256 investorTokenCount = tokenTotalSupply - partnerTokenBalance;

        // If no investor tokens exist, cannot distribute
        if (investorTokenCount == 0) {
            revert NoRevenueTokensIssued();
        }

        // Calculate protocol fee and net earnings (fee only on investor portion)
        uint256 protocolFee = ProtocolLib.calculateProtocolFee(investorAmount);
        uint256 netEarnings = investorAmount - protocolFee;

        // Transfer USDC from partner to treasury (only investor amount)
        usdc.safeTransferFrom(msg.sender, address(this), investorAmount);

        // Initialize earnings tracking if needed
        EarningsLib.EarningsInfo storage earningsInfo = assetEarnings[assetId];
        if (!earningsInfo.isInitialized) {
            EarningsLib.initializeEarningsInfo(earningsInfo);
        }

        // Calculate earnings per investor token (only for investors)
        uint256 earningsPerToken = netEarnings / investorTokenCount;

        // Update earnings info (track total revenue for asset performance metrics)
        earningsInfo.totalEarnings += totalRevenue; // Track full revenue for metrics
        earningsInfo.totalEarningsPerToken += earningsPerToken;
        earningsInfo.currentPeriod++;

        earningsInfo.periods[earningsInfo.currentPeriod] = EarningsLib.EarningsPeriod({
            earningsPerToken: earningsPerToken, timestamp: block.timestamp, totalEarnings: netEarnings
        });

        // Update treasury totals
        totalEarningsDeposited += investorAmount;

        // Add protocol fee to pending withdrawals for treasury fee collection
        if (protocolFee > 0) {
            pendingWithdrawals[treasuryFeeRecipient] += protocolFee;
        }

        emit EarningsDistributed(assetId, msg.sender, totalRevenue, netEarnings, earningsInfo.currentPeriod);

        // Attempt auto-release of collateral if requested
        if (tryAutoRelease) {
            collateralReleased = _tryReleaseCollateral(assetId, msg.sender);
        }
    }

    /**
     * @dev Claim earnings from revenue token holdings.
     * For active assets: calculates earnings from current positions.
     * For settled assets: uses snapshot taken before tokens were burned.
     * @param assetId The ID of the asset
     */
    function claimEarnings(uint256 assetId) external nonReentrant {
        // Verify asset exists
        if (!router.assetExists(assetId)) {
            revert AssetNotFound();
        }

        EarningsLib.EarningsInfo storage earningsInfo = assetEarnings[assetId];
        if (!earningsInfo.isInitialized || earningsInfo.currentPeriod == 0) {
            revert NoEarningsToClaim();
        }

        // Check if asset is settled - if so, use snapshot approach
        AssetLib.AssetStatus status = router.getAssetStatus(assetId);
        bool isSettled = (status == AssetLib.AssetStatus.Retired || status == AssetLib.AssetStatus.Expired);

        uint256 unclaimedAmount;

        if (isSettled) {
            // For settled assets: claim from snapshot (works even after tokens burned)
            unclaimedAmount = EarningsLib.claimSettledEarnings(earningsInfo, msg.sender);
        } else {
            // For active assets: calculate from current positions
            uint256 revenueTokenId = router.getTokenIdFromAssetId(assetId);
            uint256 tokenBalance = roboshareTokens.balanceOf(msg.sender, revenueTokenId);
            if (tokenBalance == 0) {
                revert InsufficientTokenBalance();
            }

            // Get user's positions from RoboshareTokens (single source of truth)
            TokenLib.TokenPosition[] memory positions = roboshareTokens.getUserPositions(revenueTokenId, msg.sender);

            // Calculate position-based earnings using Treasury's claim tracking
            unclaimedAmount = EarningsLib.calculateEarningsForPositions(earningsInfo, msg.sender, positions);

            if (unclaimedAmount > 0) {
                // Update claim periods for all positions
                EarningsLib.updateClaimPeriods(earningsInfo, msg.sender, positions);
            }
        }

        if (unclaimedAmount == 0) {
            revert NoEarningsToClaim();
        }

        // Add to pending withdrawals
        pendingWithdrawals[msg.sender] += unclaimedAmount;

        emit EarningsClaimed(assetId, msg.sender, unclaimedAmount);
    }

    /**
     * @dev Snapshot a holder's unclaimed earnings before burning their tokens.
     * Called by VehicleRegistry during claimSettlement to preserve earnings.
     * @param assetId The ID of the asset
     * @param holder The address of the token holder
     * @param autoClaim If true, adds earnings to pendingWithdrawals immediately
     * @return snapshotAmount Amount of unclaimed earnings snapshotted (and claimed if autoClaim=true)
     */
    function snapshotAndClaimEarnings(uint256 assetId, address holder, bool autoClaim)
        external
        onlyRole(AUTHORIZED_ROUTER_ROLE)
        returns (uint256 snapshotAmount)
    {
        EarningsLib.EarningsInfo storage earningsInfo = assetEarnings[assetId];

        // If no earnings were ever distributed, nothing to snapshot
        if (!earningsInfo.isInitialized || earningsInfo.currentPeriod == 0) {
            return 0;
        }

        // Get holder's positions before they are burned
        uint256 revenueTokenId = router.getTokenIdFromAssetId(assetId);
        TokenLib.TokenPosition[] memory positions = roboshareTokens.getUserPositions(revenueTokenId, holder);

        // Snapshot their unclaimed earnings
        snapshotAmount = EarningsLib.snapshotHolderEarnings(earningsInfo, holder, positions);

        // If autoClaim is true, add to pendingWithdrawals and mark as claimed
        if (autoClaim && snapshotAmount > 0) {
            // Mark as claimed so they can't claim again via claimEarnings
            earningsInfo.hasClaimedSettledEarnings[holder] = true;
            pendingWithdrawals[holder] += snapshotAmount;
            emit EarningsClaimed(assetId, holder, snapshotAmount);
        }

        return snapshotAmount;
    }

    /**
     * @dev Internal helper to attempt collateral release if eligible.
     * Returns 0 if not eligible (instead of reverting), making it safe to call from distributeEarnings.
     * @param assetId The ID of the asset
     * @param partner The partner address to credit released collateral
     * @return releasedAmount Amount of collateral released (0 if not eligible)
     */
    function _tryReleaseCollateral(uint256 assetId, address partner) internal returns (uint256 releasedAmount) {
        CollateralLib.CollateralInfo storage collateralInfo = assetCollateral[assetId];
        EarningsLib.EarningsInfo storage earningsInfo = assetEarnings[assetId];

        // Check eligibility conditions - return 0 if not eligible
        if (!collateralInfo.isLocked) {
            return 0;
        }
        if (!earningsInfo.isInitialized || earningsInfo.currentPeriod == 0) {
            return 0;
        }

        bool hasNewPeriods = earningsInfo.currentPeriod > earningsInfo.lastProcessedPeriod;
        if (!hasNewPeriods) {
            return 0;
        }

        // Calculate time since last processed period for benchmark earnings
        uint256 timeSinceLastEvent = block.timestamp - collateralInfo.lastEventTimestamp;

        // Process buffers across new periods
        {
            uint256 startPeriod = earningsInfo.lastProcessedPeriod;
            uint256 endPeriod = earningsInfo.currentPeriod;

            uint256 aggregatedBenchmarkEarnings =
                EarningsLib.calculateBenchmarkEarnings(collateralInfo.baseCollateral, timeSinceLastEvent);

            uint256 aggregatedNetEarnings = 0;
            for (uint256 i = startPeriod + 1; i <= endPeriod; i++) {
                aggregatedNetEarnings += earningsInfo.periods[i].totalEarnings;
            }

            (int256 earningsResult, uint256 replenishmentAmount) = CollateralLib.processEarningsForBuffers(
                collateralInfo, aggregatedNetEarnings, aggregatedBenchmarkEarnings
            );

            if (earningsResult < 0) {
                uint256 shortfallAmount = (-earningsResult).toUint256();
                emit ShortfallReserved(assetId, shortfallAmount);
            } else if (earningsResult > 0) {
                uint256 excessEarnings = earningsResult.toUint256();
                earningsInfo.cumulativeExcessEarnings += excessEarnings;
            }

            if (replenishmentAmount > 0) {
                emit BufferReplenished(assetId, replenishmentAmount, replenishmentAmount);
            }

            earningsInfo.lastProcessedPeriod = endPeriod;
        }

        emit CollateralBuffersUpdated(assetId, collateralInfo.earningsBuffer, collateralInfo.reservedForLiquidation);

        // Calculate release amount
        releasedAmount = CollateralLib.calculateCollateralRelease(collateralInfo);
        if (releasedAmount == 0) {
            return 0;
        }

        if (releasedAmount > collateralInfo.totalCollateral) {
            releasedAmount = collateralInfo.totalCollateral;
        }

        // Update collateral info
        collateralInfo.baseCollateral -= releasedAmount;
        collateralInfo.totalCollateral -= releasedAmount;
        collateralInfo.lastEventTimestamp = block.timestamp;

        // Update earnings info timestamps
        earningsInfo.lastEventTimestamp = block.timestamp;

        // Update treasury totals
        totalCollateralDeposited -= releasedAmount;

        // Add to pending withdrawals
        pendingWithdrawals[partner] += releasedAmount;

        emit CollateralReleased(assetId, partner, releasedAmount);
    }

    /**
     * @dev Release partial collateral based on depreciation and unprocessed earnings periods.
     * Use this for manual release when not using distributeEarnings with tryAutoRelease=true.
     * @param assetId The ID of the asset
     */
    function releasePartialCollateral(uint256 assetId) external onlyAuthorizedPartner nonReentrant {
        // Verify partner owns the asset
        if (roboshareTokens.balanceOf(msg.sender, assetId) == 0) {
            revert NotAssetOwner();
        }

        CollateralLib.CollateralInfo storage collateralInfo = assetCollateral[assetId];
        EarningsLib.EarningsInfo storage earningsInfo = assetEarnings[assetId];

        // Provide specific error messages for manual calls (better UX than just returning 0)
        if (!collateralInfo.isLocked) {
            revert NoCollateralLocked();
        }
        if (!earningsInfo.isInitialized || earningsInfo.currentPeriod == 0) {
            revert NoPriorEarningsDistribution();
        }

        bool hasNewPeriods = earningsInfo.currentPeriod > earningsInfo.lastProcessedPeriod;
        if (!hasNewPeriods) {
            revert NoNewPeriodsToProcess();
        }

        // Use helper for the actual release logic
        uint256 releaseAmount = _tryReleaseCollateral(assetId, msg.sender);
        if (releaseAmount == 0) {
            revert InsufficientCollateral();
        }
    }

    /**
     * @dev Check asset solvency
     */
    function isAssetSolvent(uint256 assetId) external view override returns (bool) {
        // An asset is solvent if it hasn't been settled AND is not currently under financial distress
        return !assetSettlements[assetId].isSettled && CollateralLib.isSolvent(assetCollateral[assetId]);
    }

    /**
     * @dev Initiate voluntary settlement
     */
    function initiateSettlement(address partner, uint256 assetId, uint256 topUpAmount)
        external
        override
        onlyRole(AUTHORIZED_ROUTER_ROLE)
        returns (uint256 settlementAmount, uint256 settlementPerToken)
    {
        CollateralLib.AssetSettlement storage settlement = assetSettlements[assetId];
        if (settlement.isSettled) {
            revert IAssetRegistry.AssetAlreadySettled(assetId, router.getAssetStatus(assetId));
        }

        // Transfer top-up if any
        if (topUpAmount > 0) {
            usdc.safeTransferFrom(partner, address(this), topUpAmount);
        }

        // Settle asset (Voluntary)
        uint256 partnerRefund;
        (settlementAmount, partnerRefund) = _settleAsset(assetId, topUpAmount, false);

        if (partnerRefund > 0) {
            pendingWithdrawals[partner] += partnerRefund;
        }

        uint256 revenueTokenId = router.getTokenIdFromAssetId(assetId);
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);

        if (totalSupply > 0) {
            settlement.settlementPerToken = settlementAmount / totalSupply;
        }

        settlement.isSettled = true;
        settlement.totalSettlementPool = settlementAmount;

        // Update asset status to Retired
        router.setAssetStatus(assetId, AssetLib.AssetStatus.Retired);

        return (settlementAmount, settlement.settlementPerToken);
    }

    /**
     * @dev Execute forced liquidation
     */
    function executeLiquidation(uint256 assetId)
        external
        override
        onlyRole(AUTHORIZED_ROUTER_ROLE)
        returns (uint256 liquidationAmount, uint256 settlementPerToken)
    {
        CollateralLib.AssetSettlement storage settlement = assetSettlements[assetId];
        if (settlement.isSettled) {
            revert IAssetRegistry.AssetAlreadySettled(assetId, router.getAssetStatus(assetId));
        }

        // Settle asset (Liquidation)
        (liquidationAmount,) = _settleAsset(assetId, 0, true);

        uint256 revenueTokenId = router.getTokenIdFromAssetId(assetId);
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);

        if (totalSupply > 0) {
            settlement.settlementPerToken = liquidationAmount / totalSupply;
        }

        settlement.isSettled = true;
        settlement.totalSettlementPool = liquidationAmount;

        // Update asset status to Expired (liquidation)
        router.setAssetStatus(assetId, AssetLib.AssetStatus.Expired);

        return (liquidationAmount, settlement.settlementPerToken);
    }

    /**
     * @dev Internal settlement logic
     * Moves protocol buffer to fees, clears collateral, returns investor pool amount
     */
    function _settleAsset(uint256 assetId, uint256 additionalAmount, bool isLiquidation)
        internal
        returns (uint256 investorPool, uint256 partnerRefund)
    {
        CollateralLib.CollateralInfo storage info = assetCollateral[assetId];

        // Snapshot values before clearing
        uint256 protocolBuffer = info.protocolBuffer;
        uint256 earningsBuffer = info.earningsBuffer;
        uint256 reservedForLiquidation = info.reservedForLiquidation;
        uint256 baseCollateral = info.baseCollateral;
        uint256 claimable = CollateralLib.getInvestorClaimableCollateral(info);

        // Clear collateral state
        _clearCollateral(assetId);

        // Check for maturity
        uint256 revenueTokenId = router.getTokenIdFromAssetId(assetId);
        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(revenueTokenId);
        bool isMatured = block.timestamp >= maturityDate;

        if (!isLiquidation && isMatured) {
            // Voluntary settlement after maturity: Refund earnings AND protocol buffer to partner
            partnerRefund = earningsBuffer + protocolBuffer;
            // Investor pool gets base + reserved (earnings buffer excluded)
            investorPool = baseCollateral + reservedForLiquidation + additionalAmount;
        } else {
            // Liquidation OR Not Matured: Protocol Buffer goes to Treasury
            if (protocolBuffer > 0) {
                pendingWithdrawals[treasuryFeeRecipient] += protocolBuffer;
            }

            if (isMatured) {
                // Liquidation after maturity: Partner refund (earnings buffer) is calculated but likely ignored by caller
                partnerRefund = earningsBuffer;
                investorPool = baseCollateral + reservedForLiquidation + additionalAmount;
            } else {
                // Standard settlement / Liquidation before maturity
                investorPool = claimable + additionalAmount;
                partnerRefund = 0;
            }
        }
    }

    /**
     * @dev Process settlement claim (called by Registry via Router)
     * Transfers USDC for burned tokens
     */
    function processSettlementClaim(address recipient, uint256 assetId, uint256 amount)
        external
        override
        onlyRole(AUTHORIZED_ROUTER_ROLE)
        returns (uint256 claimedAmount)
    {
        CollateralLib.AssetSettlement storage settlement = assetSettlements[assetId];
        if (!settlement.isSettled) {
            revert IAssetRegistry.AssetNotSettled(assetId, router.getAssetStatus(assetId));
        }

        if (amount == 0) {
            return 0;
        }

        // Calculate claim
        claimedAmount = amount * settlement.settlementPerToken;

        // Transfer USDC
        if (claimedAmount > 0) {
            usdc.safeTransfer(recipient, claimedAmount);
        }

        emit SettlementClaimed(assetId, recipient, claimedAmount);
    }

    // View Functions

    /**
     * @dev Get collateral requirement for specific revenue token parameters
     * @param revenueTokenPrice Price per revenue share token in USDC
     * @param tokenSupply Total number of revenue share tokens
     * @return Total collateral requirement in USDC
     */
    function getTotalCollateralRequirement(uint256 revenueTokenPrice, uint256 tokenSupply)
        external
        pure
        returns (uint256)
    {
        (,,, uint256 totalCollateral) = CollateralLib.calculateCollateralRequirements(
            revenueTokenPrice, tokenSupply, ProtocolLib.QUARTERLY_INTERVAL
        );
        return totalCollateral;
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

    /**
     * @dev Get the minimum protocol fee for earnings distribution
     * @return Minimum protocol fee in USDC (6 decimals)
     */
    function getMinProtocolFee() external pure returns (uint256) {
        return ProtocolLib.MIN_PROTOCOL_FEE;
    }

    // Admin Functions

    /**
     * @dev Update partner manager reference
     * @param _partnerManager New partner manager address
     */
    function updatePartnerManager(address _partnerManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_partnerManager == address(0)) {
            revert ZeroAddress();
        }
        address oldAddress = address(partnerManager);
        partnerManager = PartnerManager(_partnerManager);
        emit PartnerManagerUpdated(oldAddress, _partnerManager);
    }

    /**
     * @dev Update USDC token reference
     * @param _usdc New USDC token address
     */
    function updateUSDC(address _usdc) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_usdc == address(0)) {
            revert ZeroAddress();
        }
        address oldAddress = address(usdc);
        usdc = IERC20(_usdc);
        emit UsdcUpdated(oldAddress, _usdc);
    }

    /**
     * @dev Update RoboshareTokens contract reference (for upgrades)
     * @param _roboshareTokens New RoboshareTokens contract address
     */
    function updateRoboshareTokens(address _roboshareTokens) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_roboshareTokens == address(0)) {
            revert ZeroAddress();
        }
        address oldAddress = address(roboshareTokens);
        roboshareTokens = RoboshareTokens(_roboshareTokens);
        emit RoboshareTokensUpdated(oldAddress, _roboshareTokens);
    }

    /**
     * @dev Updates the router contract address.
     * Only callable by an admin.
     * @param _newRouter The address of the new router contract.
     */
    function updateRouter(address _newRouter) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_newRouter == address(0)) {
            revert ZeroAddress();
        }
        _revokeRole(AUTHORIZED_ROUTER_ROLE, address(router));
        router = RegistryRouter(_newRouter);
        _grantRole(AUTHORIZED_ROUTER_ROLE, _newRouter);
        emit RouterUpdated(_newRouter);
    }

    /**
     * @dev Update treasury fee recipient address
     * @param _treasuryFeeRecipient New treasury fee recipient address
     */
    function updateTreasuryFeeRecipient(address _treasuryFeeRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_treasuryFeeRecipient == address(0)) {
            revert ZeroAddress();
        }
        address oldAddress = treasuryFeeRecipient;
        treasuryFeeRecipient = _treasuryFeeRecipient;
        emit TreasuryFeeRecipientUpdated(oldAddress, _treasuryFeeRecipient);
    }

    // UUPS Upgrade authorization
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }
}
