// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
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
    mapping(uint256 => CollateralLib.SettlementInfo) public assetSettlements; // Settlement info - assetId => SettlementInfo
    mapping(address => uint256) public pendingWithdrawals;

    // Treasury state
    uint256 public totalCollateralDeposited;
    uint256 public totalEarningsDeposited;
    address public treasuryFeeRecipient;

    // Internal Errors (not part of public API)
    error ZeroAddress();
    error InvalidUSDCContract(address token);
    error UnsupportedUSDCDecimals(uint8 decimals);

    /**
     * @dev Modifier to restrict access to authorized partners
     */
    modifier onlyAuthorizedPartner() {
        _onlyAuthorizedPartner();
        _;
    }

    function _onlyAuthorizedPartner() internal view {
        if (!partnerManager.isAuthorizedPartner(msg.sender)) {
            revert PartnerManager.UnauthorizedPartner();
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
        _validateUSDCContract(_usdc);
        usdc = IERC20(_usdc);
        treasuryFeeRecipient = _treasuryFeeRecipient;
    }

    // Collateral Locking Functions

    /**
     * @dev Fund protection buffers for an asset (Marketplace flow).
     * @param partner The partner who owns the asset
     * @param assetId The ID of the asset to fund buffers for
     * @param baseAmount Base amount used to size buffers (investor proceeds for this listing)
     */
    function fundBuffersFor(address partner, uint256 assetId, uint256 baseAmount)
        external
        onlyRole(AUTHORIZED_CONTRACT_ROLE)
        nonReentrant
    {
        if (!partnerManager.isAuthorizedPartner(partner)) {
            revert PartnerManager.UnauthorizedPartner();
        }
        if (!router.assetExists(assetId)) {
            revert AssetNotFound();
        }
        if (roboshareTokens.balanceOf(partner, assetId) == 0) {
            revert NotAssetOwner();
        }
        _fundBuffersFor(partner, assetId, baseAmount);
    }

    /**
     * @dev Credits investor principal into the pool's base liquidity.
     * @param assetId The ID of the asset
     * @param amount Principal amount to credit
     */
    function creditBaseLiquidity(uint256 assetId, uint256 amount)
        external
        onlyRole(AUTHORIZED_CONTRACT_ROLE)
        nonReentrant
    {
        if (amount == 0) {
            return;
        }
        _creditBaseCollateral(assetId, amount);

        emit ITreasury.BaseLiquidityCredited(assetId, amount);
    }

    function _creditBaseCollateral(uint256 assetId, uint256 amount) internal {
        CollateralLib.CollateralInfo storage collateralInfo = assetCollateral[assetId];

        collateralInfo.baseCollateral += amount;
        collateralInfo.initialBaseCollateral += amount;
        collateralInfo.totalCollateral += amount;
        totalCollateralDeposited += amount;

        if (collateralInfo.lockedAt == 0) {
            collateralInfo.lockedAt = block.timestamp;
        }
        collateralInfo.lastEventTimestamp = block.timestamp;
    }

    function _fundBuffersFor(address partner, uint256 assetId, uint256 baseAmount) internal {
        if (baseAmount == 0) {
            revert CollateralLib.InvalidCollateralAmount();
        }

        CollateralLib.CollateralInfo storage collateralInfo = assetCollateral[assetId];
        EarningsLib.EarningsInfo storage earningsInfo = assetEarnings[assetId];

        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);
        uint256 targetYieldBP = roboshareTokens.getTargetYieldBP(revenueTokenId);

        (, uint256 requiredEarningsBuffer, uint256 requiredProtocolBuffer,) =
            CollateralLib.calculateCollateralRequirements(baseAmount, ProtocolLib.QUARTERLY_INTERVAL, targetYieldBP);

        uint256 requiredBufferTotal = requiredEarningsBuffer + requiredProtocolBuffer;

        if (!CollateralLib.isInitialized(collateralInfo)) {
            CollateralLib.initializeCollateralInfo(collateralInfo, 0, requiredEarningsBuffer, requiredProtocolBuffer);
        } else {
            collateralInfo.earningsBuffer += requiredEarningsBuffer;
            collateralInfo.protocolBuffer += requiredProtocolBuffer;
            collateralInfo.totalCollateral += requiredBufferTotal;
            collateralInfo.isLocked = true;
            if (collateralInfo.lockedAt == 0) {
                collateralInfo.lockedAt = block.timestamp;
            }
        }
        collateralInfo.lastEventTimestamp = block.timestamp;
        if (earningsInfo.lastEventTimestamp == 0) {
            earningsInfo.lastEventTimestamp = block.timestamp;
        }

        // Transfer USDC from partner to treasury (requires prior approval)
        usdc.safeTransferFrom(partner, address(this), requiredBufferTotal);

        totalCollateralDeposited += requiredBufferTotal;

        emit CollateralLocked(assetId, partner, requiredBufferTotal);

        _maybePromoteToEarning(assetId, true);
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

        _releaseCollateralFor(msg.sender, assetId);
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
            _releaseCollateralFor(partner, assetId);
        }
    }

    function _releaseCollateralFor(address recipient, uint256 assetId) internal {
        // Ensure no outstanding revenue tokens
        // Registry is responsible for burning tokens before calling retirement
        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);
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
        info.initialBaseCollateral = 0;
        info.baseCollateral = 0;
        info.earningsBuffer = 0;
        info.protocolBuffer = 0;
        info.reservedForLiquidation = 0;
        info.totalCollateral = 0;

        if (totalCollateralDeposited >= totalReleased) {
            totalCollateralDeposited -= totalReleased;
        } else {
            totalReleased = totalCollateralDeposited;
            totalCollateralDeposited = 0;
        }
    }

    /**
     * @dev Process withdrawal from pending withdrawals
     */
    function processWithdrawal() external nonReentrant {
        uint256 amount = _processWithdrawalFor(msg.sender);
        if (amount == 0) {
            revert NoPendingWithdrawals();
        }
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

    /**
     * @dev Process withdrawal on behalf of a user (for convenience functions)
     * @param account The account to withdraw for
     * @return amount Amount withdrawn
     */
    function processWithdrawalFor(address account)
        external
        onlyRole(AUTHORIZED_CONTRACT_ROLE)
        nonReentrant
        returns (uint256 amount)
    {
        amount = _processWithdrawalFor(account);
    }

    function processPrimaryPoolPurchase(
        address buyer,
        uint256 tokenId,
        uint256 amount,
        address partner,
        uint256 grossPrincipal,
        uint256 protocolFee,
        bool immediateProceeds,
        bool protectionEnabled
    )
        external
        onlyRole(AUTHORIZED_CONTRACT_ROLE)
        nonReentrant
        returns (uint256 partnerProceeds, uint256 protectionFunding)
    {
        if (!partnerManager.isAuthorizedPartner(partner)) {
            revert PartnerManager.UnauthorizedPartner();
        }

        uint256 assetId = TokenLib.getAssetIdFromTokenId(tokenId);
        if (!router.assetExists(assetId)) {
            revert AssetNotFound();
        }
        if (roboshareTokens.balanceOf(partner, assetId) == 0) {
            revert NotAssetOwner();
        }

        _creditBaseCollateral(assetId, grossPrincipal);
        CollateralLib.CollateralInfo storage collateralInfo = assetCollateral[assetId];

        if (protocolFee > 0) {
            pendingWithdrawals[treasuryFeeRecipient] += protocolFee;
        }

        bool canRelease = _maybePromoteToEarning(assetId, protectionEnabled);
        if (immediateProceeds && canRelease) {
            collateralInfo.baseCollateral -= grossPrincipal;
            collateralInfo.totalCollateral -= grossPrincipal;
            pendingWithdrawals[partner] += grossPrincipal;
            partnerProceeds = grossPrincipal;
        }

        router.mintRevenueTokensForPrimaryPool(buyer, tokenId, amount);
        protectionFunding = 0;
    }

    function getPrimaryInvestorLiquidity(uint256 assetId) external view returns (uint256) {
        return assetCollateral[assetId].baseCollateral;
    }

    function previewPrimaryRedemptionPayout(uint256 assetId, uint256 burnAmount, uint256 circulatingSupply)
        external
        view
        returns (uint256 payout)
    {
        if (burnAmount == 0 || circulatingSupply == 0) {
            return 0;
        }
        uint256 investorLiquidity = assetCollateral[assetId].baseCollateral;
        payout = Math.mulDiv(burnAmount, investorLiquidity, circulatingSupply);
    }

    function processPrimaryRedemption(
        address holder,
        uint256 assetId,
        uint256 burnAmount,
        uint256 circulatingSupply,
        uint256 minPayout
    ) external onlyRole(AUTHORIZED_CONTRACT_ROLE) nonReentrant returns (uint256 payout) {
        if (!router.assetExists(assetId)) {
            revert AssetNotFound();
        }
        AssetLib.AssetStatus status = router.getAssetStatus(assetId);
        if (!_isOperationalStatus(status)) {
            revert AssetNotOperational(assetId, status);
        }
        if (burnAmount == 0 || circulatingSupply == 0) {
            revert InsufficientPrimaryLiquidity();
        }

        uint256 tokenId = TokenLib.getTokenIdFromAssetId(assetId);
        if (roboshareTokens.balanceOf(holder, tokenId) < burnAmount) {
            revert InsufficientTokenBalance();
        }

        // Preserve unclaimed earnings before burn to prevent earnings double-dipping.
        _snapshotAndClaimEarnings(assetId, holder, false);

        uint256 investorLiquidity = assetCollateral[assetId].baseCollateral;
        payout = Math.mulDiv(burnAmount, investorLiquidity, circulatingSupply);
        if (payout == 0 || payout > investorLiquidity) {
            revert InsufficientPrimaryLiquidity();
        }
        if (payout < minPayout) {
            revert SlippageExceeded();
        }

        router.burnRevenueTokensForPrimaryRedemption(holder, tokenId, burnAmount);

        assetCollateral[assetId].baseCollateral -= payout;
        assetCollateral[assetId].totalCollateral -= payout;
        totalCollateralDeposited = totalCollateralDeposited >= payout ? totalCollateralDeposited - payout : 0;
        usdc.safeTransfer(holder, payout);
    }

    // ============================================
    // Convenience Withdrawal Functions
    // ============================================

    /**
     * @dev Release partial collateral and withdraw in one transaction.
     * Combines releasePartialCollateral() + processWithdrawal() for better UX.
     * @param assetId The ID of the asset
     * @return withdrawn Amount of USDC withdrawn
     */
    function releaseAndWithdrawCollateral(uint256 assetId)
        external
        onlyAuthorizedPartner
        nonReentrant
        returns (uint256 withdrawn)
    {
        // Use same logic as releasePartialCollateral
        _releasePartialCollateralFor(assetId, msg.sender);

        // Withdraw immediately
        withdrawn = _processWithdrawalFor(msg.sender);
    }

    /**
     * @dev Claim earnings and withdraw in one transaction.
     * Combines claimEarnings() + processWithdrawal() for better UX.
     * @param assetId The ID of the asset
     * @return withdrawn Amount of USDC withdrawn
     */
    function claimAndWithdrawEarnings(uint256 assetId) external nonReentrant returns (uint256 withdrawn) {
        // Use same logic as claimEarnings
        _claimEarningsFor(msg.sender, assetId);

        // Withdraw immediately
        withdrawn = _processWithdrawalFor(msg.sender);
    }

    /**
     * @dev Internal: process withdrawal for a specific account
     * @param account The account to withdraw for
     * @return amount Amount withdrawn
     */
    function _processWithdrawalFor(address account) internal returns (uint256 amount) {
        amount = pendingWithdrawals[account];
        if (amount > 0) {
            pendingWithdrawals[account] = 0;
            usdc.safeTransfer(account, amount);
            emit WithdrawalProcessed(account, amount);
        }
    }

    /**
     * @dev Internal: release partial collateral for a partner
     * Reverts if not eligible
     */
    function _releasePartialCollateralFor(uint256 assetId, address partner) internal {
        // Verify partner owns the asset
        if (roboshareTokens.balanceOf(partner, assetId) == 0) {
            revert NotAssetOwner();
        }

        _tryReleaseCollateral(assetId, partner, false);
    }

    /**
     * @dev Internal: claim earnings for a holder
     * Reverts if no earnings to claim
     */
    function _claimEarningsFor(address holder, uint256 assetId) internal {
        if (!router.assetExists(assetId)) {
            revert AssetNotFound();
        }

        EarningsLib.EarningsInfo storage earningsInfo = assetEarnings[assetId];
        if (!earningsInfo.isInitialized || earningsInfo.currentPeriod == 0) {
            revert NoEarningsToClaim();
        }

        AssetLib.AssetStatus status = router.getAssetStatus(assetId);
        bool isSettled = _isSettledStatus(status);

        uint256 unclaimedAmount;

        if (isSettled) {
            unclaimedAmount = EarningsLib.claimSettledEarnings(earningsInfo, holder);
        } else {
            if (roboshareTokens.balanceOf(holder, assetId) > 0) {
                revert NoEarningsToClaim();
            }
            uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);
            uint256 tokenBalance = roboshareTokens.balanceOf(holder, revenueTokenId);
            if (tokenBalance == 0) {
                revert InsufficientTokenBalance();
            }

            TokenLib.TokenPosition[] memory positions = roboshareTokens.getUserPositions(revenueTokenId, holder);

            unclaimedAmount = EarningsLib.calculateEarningsForPositions(earningsInfo, holder, positions);

            if (unclaimedAmount > 0) {
                EarningsLib.updateClaimPeriods(earningsInfo, holder, positions);
            }
        }

        if (unclaimedAmount == 0) {
            revert NoEarningsToClaim();
        }

        pendingWithdrawals[holder] += unclaimedAmount;
        emit EarningsClaimed(assetId, holder, unclaimedAmount);
    }

    // Earnings Distribution Functions

    /**
     * @dev Distribute USDC earnings for revenue token holders
     * @param assetId The ID of the asset
     * @param totalRevenue Total revenue generated by the asset (used to compute investor share)
     * @param tryAutoRelease If true, attempt to release eligible collateral in the same transaction
     * @return collateralReleased Amount of collateral released (0 if tryAutoRelease=false or not eligible)
     */
    function distributeEarnings(uint256 assetId, uint256 totalRevenue, bool tryAutoRelease)
        external
        onlyAuthorizedPartner
        nonReentrant
        returns (uint256 collateralReleased)
    {
        if (totalRevenue == 0) revert InvalidEarningsAmount();

        // Verify partner owns the asset
        if (roboshareTokens.balanceOf(msg.sender, assetId) == 0) {
            revert NotAssetOwner();
        }

        // Verify asset is still active (not settled/retired)
        AssetLib.AssetStatus status = router.getAssetStatus(assetId);
        if (status != AssetLib.AssetStatus.Earning) {
            revert AssetNotActive(assetId, status);
        }

        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);
        uint256 tokenTotalSupply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);
        // Note: tokenTotalSupply > 0 is guaranteed for Active assets since
        // assets can only become Active after minting tokens and locking collateral.

        uint256 partnerTokenBalance = roboshareTokens.balanceOf(msg.sender, revenueTokenId);
        uint256 investorSupply = tokenTotalSupply > partnerTokenBalance ? tokenTotalSupply - partnerTokenBalance : 0;

        // If no investor tokens exist (all outstanding tokens held by partner), cannot distribute
        if (investorSupply == 0) {
            revert NoInvestors();
        }

        uint256 revenueShareBP = roboshareTokens.getRevenueShareBP(revenueTokenId);
        uint256 cap = (totalRevenue * revenueShareBP) / ProtocolLib.BP_PRECISION;
        uint256 soldShare = (totalRevenue * investorSupply) / tokenTotalSupply;
        uint256 investorAmount = soldShare < cap ? soldShare : cap;

        if (investorAmount < ProtocolLib.MIN_PROTOCOL_FEE) {
            revert EarningsLessThanMinimumFee();
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
        uint256 earningsPerToken = netEarnings / investorSupply;

        // Update earnings info
        earningsInfo.totalRevenue += totalRevenue; // Track full revenue for metrics
        earningsInfo.totalEarnings += netEarnings; // Track net earnings for distribution history
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
            collateralReleased = _tryReleaseCollateral(assetId, msg.sender, true);
        }
    }

    /**
     * @dev Claim earnings from revenue token holdings.
     * For active assets: calculates earnings from current positions.
     * For settled assets: uses snapshot taken before tokens were burned.
     * @param assetId The ID of the asset
     */
    function claimEarnings(uint256 assetId) external nonReentrant {
        _claimEarningsFor(msg.sender, assetId);
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
        return _snapshotAndClaimEarnings(assetId, holder, autoClaim);
    }

    function _snapshotAndClaimEarnings(uint256 assetId, address holder, bool autoClaim)
        internal
        returns (uint256 snapshotAmount)
    {
        EarningsLib.EarningsInfo storage earningsInfo = assetEarnings[assetId];

        // If no earnings were ever distributed, nothing to snapshot
        if (!earningsInfo.isInitialized || earningsInfo.currentPeriod == 0) {
            return 0;
        }

        // Get holder's positions before they are burned
        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);
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

    function _maybePromoteToEarning(uint256 assetId, bool protectionEnabled)
        internal
        returns (bool hasSufficientBuffers)
    {
        hasSufficientBuffers = _hasSufficientBuffers(assetId, protectionEnabled);
        if (router.getAssetStatus(assetId) == AssetLib.AssetStatus.Active && hasSufficientBuffers) {
            router.setAssetStatus(assetId, AssetLib.AssetStatus.Earning);
        }
    }

    function _hasSufficientBuffers(uint256 assetId, bool protectionEnabled) internal view returns (bool) {
        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);
        uint256 targetYieldBP = roboshareTokens.getTargetYieldBP(revenueTokenId);
        uint256 baseAmount = assetCollateral[assetId].baseCollateral;
        (, uint256 requiredEarningsBuffer, uint256 requiredProtocolBuffer,) =
            CollateralLib.calculateCollateralRequirements(baseAmount, ProtocolLib.QUARTERLY_INTERVAL, targetYieldBP);

        CollateralLib.CollateralInfo storage collateralInfo = assetCollateral[assetId];
        bool protocolCovered = collateralInfo.protocolBuffer >= requiredProtocolBuffer;
        bool protectionCovered = !protectionEnabled || collateralInfo.earningsBuffer >= requiredEarningsBuffer;
        return protocolCovered && protectionCovered;
    }

    /**
     * @dev Internal helper to attempt collateral release if eligible.
     * @param assetId The ID of the asset
     * @param partner The partner address to credit released collateral
     * @param allowSkip If true, return 0 when ineligible (used by auto-release paths).
     *                  If false, revert with the specific ineligibility reason.
     * @return releasedAmount Amount of collateral released (0 if skipped)
     */
    function _tryReleaseCollateral(uint256 assetId, address partner, bool allowSkip)
        internal
        returns (uint256 releasedAmount)
    {
        CollateralLib.CollateralInfo storage collateralInfo = assetCollateral[assetId];
        EarningsLib.EarningsInfo storage earningsInfo = assetEarnings[assetId];
        CollateralLib.ReleaseCalculation memory calc = _calculateReleasePreview(assetId, false);
        if (calc.status != CollateralLib.ReleaseEligibility.Eligible) {
            if (allowSkip) {
                return 0;
            }
            if (calc.status == CollateralLib.ReleaseEligibility.NoCollateralLocked) {
                revert NoCollateralLocked();
            }
            if (calc.status == CollateralLib.ReleaseEligibility.NoPriorEarnings) {
                revert NoPriorEarningsDistribution();
            }
            revert NoNewEarningsPeriods();
        }

        if (calc.shortfallAmount > 0) {
            emit ShortfallReserved(assetId, calc.shortfallAmount);
        } else if (calc.excessEarnings > 0) {
            earningsInfo.cumulativeExcessEarnings += calc.excessEarnings;
        }

        if (calc.replenishmentAmount > 0) {
            emit BufferReplenished(assetId, calc.replenishmentAmount, calc.replenishmentAmount);
        }

        // Apply buffer updates
        collateralInfo.earningsBuffer = calc.collateral.earningsBuffer;
        collateralInfo.protocolBuffer = calc.collateral.protocolBuffer;
        collateralInfo.reservedForLiquidation = calc.collateral.reservedForLiquidation;
        collateralInfo.totalCollateral = calc.collateral.totalCollateral;

        emit CollateralBuffersUpdated(assetId, collateralInfo.earningsBuffer, collateralInfo.reservedForLiquidation);

        // Update timestamps to mark that these periods and their time duration have been processed
        collateralInfo.lastEventTimestamp = block.timestamp;
        earningsInfo.lastEventTimestamp = block.timestamp;
        earningsInfo.lastProcessedPeriod = calc.newLastProcessedPeriod;

        if (calc.grossRelease == 0) {
            return 0;
        }

        // Update collateral info
        collateralInfo.baseCollateral -= calc.grossRelease;
        collateralInfo.totalCollateral -= calc.grossRelease;

        // Update treasury totals
        totalCollateralDeposited -= calc.grossRelease;

        // Add to pending withdrawals
        pendingWithdrawals[partner] += calc.partnerRelease;
        if (calc.protocolFee > 0) {
            pendingWithdrawals[treasuryFeeRecipient] += calc.protocolFee;
        }

        emit CollateralReleased(assetId, partner, calc.partnerRelease);

        releasedAmount = calc.partnerRelease;
    }

    /**
     * @dev Release partial collateral based on depreciation and unprocessed earnings periods.
     * Use this for manual release when not using distributeEarnings with tryAutoRelease=true.
     * @param assetId The ID of the asset
     */
    function releasePartialCollateral(uint256 assetId) external onlyAuthorizedPartner nonReentrant {
        _releasePartialCollateralFor(assetId, msg.sender);
    }

    /**
     * @dev Check asset solvency
     * @notice Returns raw stored collateral solvency and does not simulate missed-shortfall accrual.
     */
    function isAssetSolvent(uint256 assetId) external view override returns (bool) {
        // An asset is solvent if it hasn't been settled AND is not currently under financial distress
        return !assetSettlements[assetId].isSettled && CollateralLib.isSolvent(assetCollateral[assetId]);
    }

    /**
     * @dev Preview liquidation eligibility using simulated missed-shortfall accrual.
     */
    function previewLiquidationEligibility(uint256 assetId)
        external
        view
        override
        returns (bool eligible, uint8 reason)
    {
        CollateralLib.SettlementInfo storage settlement = assetSettlements[assetId];
        if (settlement.isSettled) {
            return (false, 2);
        }

        CollateralLib.CollateralInfo memory simulatedCollateral = assetCollateral[assetId];
        EarningsLib.EarningsInfo storage earningsInfo = assetEarnings[assetId];
        if (simulatedCollateral.isLocked && earningsInfo.lastEventTimestamp > 0) {
            uint256 elapsed = block.timestamp - earningsInfo.lastEventTimestamp;
            if (elapsed > 0) {
                uint256 revenueTokenIdForYield = TokenLib.getTokenIdFromAssetId(assetId);
                uint256 targetYieldBP = roboshareTokens.getTargetYieldBP(revenueTokenIdForYield);
                uint256 benchmarkEarnings =
                    EarningsLib.calculateEarnings(simulatedCollateral.initialBaseCollateral, elapsed, targetYieldBP);
                simulatedCollateral =
                    CollateralLib.previewCollateralAfterMissedEarningsShortfall(simulatedCollateral, benchmarkEarnings);
            }
        }

        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);
        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(revenueTokenId);
        bool isMatured = block.timestamp >= maturityDate;
        bool isSolvent = CollateralLib.isSolventMemory(simulatedCollateral);

        if (isMatured) {
            return (true, 0);
        }
        if (!isSolvent) {
            return (true, 1);
        }

        return (false, 3);
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
        CollateralLib.SettlementInfo storage settlement = assetSettlements[assetId];
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

        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);
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
        CollateralLib.SettlementInfo storage settlement = assetSettlements[assetId];
        if (settlement.isSettled) {
            revert IAssetRegistry.AssetAlreadySettled(assetId, router.getAssetStatus(assetId));
        }

        _applyMissedEarningsShortfall(assetId);

        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);
        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(revenueTokenId);
        bool isMatured = block.timestamp >= maturityDate;
        bool isSolvent = CollateralLib.isSolvent(assetCollateral[assetId]);

        if (!isMatured && isSolvent) {
            revert IAssetRegistry.AssetNotEligibleForLiquidation(assetId);
        }

        // Settle asset (Liquidation)
        (liquidationAmount,) = _settleAsset(assetId, 0, true);

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

    function _applyMissedEarningsShortfall(uint256 assetId) internal {
        CollateralLib.CollateralInfo storage collateralInfo = assetCollateral[assetId];
        EarningsLib.EarningsInfo storage earningsInfo = assetEarnings[assetId];

        if (!collateralInfo.isLocked) {
            return;
        }

        if (earningsInfo.lastEventTimestamp == 0) {
            return;
        }

        uint256 elapsed = block.timestamp - earningsInfo.lastEventTimestamp;
        if (elapsed == 0) {
            return;
        }

        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);
        uint256 targetYieldBP = roboshareTokens.getTargetYieldBP(revenueTokenId);
        uint256 benchmarkEarnings =
            EarningsLib.calculateEarnings(collateralInfo.initialBaseCollateral, elapsed, targetYieldBP);
        (CollateralLib.CollateralInfo memory updated, uint256 shortfallAmount,,) =
            CollateralLib.applyRealizedVsBenchmarkToCollateral(collateralInfo, 0, benchmarkEarnings);
        collateralInfo.earningsBuffer = updated.earningsBuffer;
        collateralInfo.protocolBuffer = updated.protocolBuffer;
        collateralInfo.reservedForLiquidation = updated.reservedForLiquidation;
        collateralInfo.totalCollateral = updated.totalCollateral;
        if (shortfallAmount > 0) {
            emit ShortfallReserved(assetId, shortfallAmount);
        }

        emit CollateralBuffersUpdated(assetId, collateralInfo.earningsBuffer, collateralInfo.reservedForLiquidation);

        collateralInfo.lastEventTimestamp = block.timestamp;
        earningsInfo.lastEventTimestamp = block.timestamp;
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
        uint256 claimable = info.baseCollateral + info.reservedForLiquidation;

        // Clear collateral state
        _clearCollateral(assetId);

        // Check for maturity
        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);
        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(revenueTokenId);
        bool isMatured = block.timestamp >= maturityDate;

        if (!isLiquidation && isMatured) {
            // Voluntary settlement after maturity: Refund earnings AND protocol buffer to partner
            partnerRefund = earningsBuffer + protocolBuffer;
            // Investor pool gets base + reserved (earnings buffer excluded)
            investorPool = claimable + additionalAmount;
        } else {
            // Liquidation OR Not Matured: Protocol Buffer goes to Treasury
            if (protocolBuffer > 0) {
                pendingWithdrawals[treasuryFeeRecipient] += protocolBuffer;
            }

            if (isMatured) {
                // Liquidation after maturity: Partner refund (earnings buffer) is calculated but likely ignored by caller
                partnerRefund = earningsBuffer;
                investorPool = claimable + additionalAmount;
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
        CollateralLib.SettlementInfo storage settlement = assetSettlements[assetId];
        if (!settlement.isSettled) {
            revert IAssetRegistry.AssetNotSettled(assetId, router.getAssetStatus(assetId));
        }

        if (amount == 0) {
            return 0;
        }

        // Calculate claim
        claimedAmount = amount * settlement.settlementPerToken;

        // Add to pending withdrawals (consistent withdrawal pattern)
        if (claimedAmount > 0) {
            pendingWithdrawals[recipient] += claimedAmount;
        }

        emit SettlementClaimed(assetId, recipient, claimedAmount);
    }

    // View Functions

    /**
     * @dev Get total buffer requirement for a given base amount and yield.
     * @param baseAmount Base amount used for buffer sizing (USDC)
     * @param yieldBP Yield in basis points
     * @return Total buffer requirement in USDC
     */
    function getTotalBufferRequirement(uint256 baseAmount, uint256 yieldBP) external pure returns (uint256) {
        (, uint256 earningsBuffer, uint256 protocolBuffer,) =
            CollateralLib.calculateCollateralRequirements(baseAmount, ProtocolLib.QUARTERLY_INTERVAL, yieldBP);
        return earningsBuffer + protocolBuffer;
    }

    /**
     * @dev Get collateral info for an asset
     * @param assetId The ID of the asset to check
     * @return Collateral info struct
     */
    function getAssetCollateralInfo(uint256 assetId) external view returns (CollateralLib.CollateralInfo memory) {
        return assetCollateral[assetId];
    }

    /**
     * @dev Preview how much collateral would be released if a release were attempted now.
     *      Returns the partner-facing amount after protocol fee.
     * @param assetId The ID of the asset to check
     * @return releasedAmount Estimated partner payout from a release attempt (0 if not eligible)
     */
    function previewCollateralRelease(uint256 assetId, bool assumeNewPeriod)
        external
        view
        returns (uint256 releasedAmount)
    {
        CollateralLib.ReleaseCalculation memory calc = _calculateReleasePreview(assetId, assumeNewPeriod);
        if (calc.status != CollateralLib.ReleaseEligibility.Eligible) {
            return 0;
        }
        return calc.partnerRelease;
    }

    function _calculateReleasePreview(uint256 assetId, bool assumeNewPeriod)
        internal
        view
        returns (CollateralLib.ReleaseCalculation memory calc)
    {
        CollateralLib.CollateralInfo memory collateralInfo = assetCollateral[assetId];
        EarningsLib.EarningsInfo storage earningsInfo = assetEarnings[assetId];
        uint256 benchmarkEarnings;
        uint256 realizedEarnings;
        if (
            collateralInfo.isLocked && earningsInfo.isInitialized && earningsInfo.currentPeriod > 0
                && earningsInfo.currentPeriod > earningsInfo.lastProcessedPeriod
        ) {
            uint256 timeSinceLastEvent = block.timestamp - collateralInfo.lastEventTimestamp;
            uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);
            uint256 targetYieldBP = roboshareTokens.getTargetYieldBP(revenueTokenId);
            benchmarkEarnings =
                EarningsLib.calculateEarnings(collateralInfo.initialBaseCollateral, timeSinceLastEvent, targetYieldBP);
            realizedEarnings = EarningsLib.sumRealizedEarnings(
                earningsInfo, earningsInfo.lastProcessedPeriod, earningsInfo.currentPeriod
            );
        }

        return CollateralLib.calculateReleasePreview(
            collateralInfo,
            assumeNewPeriod,
            earningsInfo.isInitialized,
            earningsInfo.currentPeriod,
            earningsInfo.lastProcessedPeriod,
            realizedEarnings,
            benchmarkEarnings
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
     * @dev Preview claimable settlement amount for a holder.
     * Returns 0 when asset is not settled or holder has no settlement-eligible tokens.
     * @param assetId The ID of the asset
     * @param holder The address to preview for
     */
    function previewSettlementClaim(uint256 assetId, address holder) external view returns (uint256) {
        if (!router.assetExists(assetId)) {
            revert AssetNotFound();
        }

        CollateralLib.SettlementInfo storage settlement = assetSettlements[assetId];
        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);
        uint256 tokenBalance = roboshareTokens.balanceOf(holder, revenueTokenId);
        if (!settlement.isSettled || tokenBalance == 0) {
            return 0;
        }

        return tokenBalance * settlement.settlementPerToken;
    }

    /**
     * @dev Preview claimable earnings for a holder without changing state.
     * Returns 0 when the holder has no claimable earnings.
     * @param assetId The ID of the asset
     * @param holder The address to preview for
     */
    function previewClaimEarnings(uint256 assetId, address holder) external view returns (uint256) {
        if (!router.assetExists(assetId)) {
            revert AssetNotFound();
        }

        EarningsLib.EarningsInfo storage earningsInfo = assetEarnings[assetId];
        if (!earningsInfo.isInitialized || earningsInfo.currentPeriod == 0) {
            return 0;
        }

        AssetLib.AssetStatus status = router.getAssetStatus(assetId);
        bool isSettled = _isSettledStatus(status);

        if (isSettled) {
            return EarningsLib.previewSettledEarnings(earningsInfo, holder);
        }

        if (roboshareTokens.balanceOf(holder, assetId) > 0) {
            return 0;
        }

        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);
        if (roboshareTokens.balanceOf(holder, revenueTokenId) == 0) {
            return 0;
        }

        TokenLib.TokenPosition[] memory positions = roboshareTokens.getUserPositions(revenueTokenId, holder);
        return EarningsLib.previewEarningsForHolder(earningsInfo, holder, positions);
    }

    /**
     * @dev Get treasury statistics
     * @return totalDeposited Total collateral deposited
     * @return treasuryBalance Current USDC balance
     */
    function getTreasuryStats() external view returns (uint256 totalDeposited, uint256 treasuryBalance) {
        return (totalCollateralDeposited, usdc.balanceOf(address(this)));
    }

    function getProtocolConfig()
        external
        pure
        returns (
            uint256 bpPrecision,
            uint256 benchmarkYieldBP,
            uint256 protocolFeeBP,
            uint256 earlySalePenaltyBP,
            uint256 depreciationRateBP,
            uint256 minProtocolFee,
            uint256 minEarlySalePenalty
        )
    {
        return _getProtocolConfigValues();
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
        _validateUSDCContract(_usdc);
        address oldAddress = address(usdc);
        usdc = IERC20(_usdc);
        emit UsdcUpdated(oldAddress, _usdc);
    }

    /**
     * @dev Validate that a token address is a USDC-compatible ERC20 (6 decimals).
     */
    function _validateUSDCContract(address token) internal view {
        // Ensure IERC20 interface surface is callable.
        try IERC20(token).totalSupply() returns (uint256) { }
        catch {
            revert InvalidUSDCContract(token);
        }

        uint8 tokenDecimals;
        try IERC20Metadata(token).decimals() returns (uint8 d) {
            tokenDecimals = d;
        } catch {
            revert InvalidUSDCContract(token);
        }

        if (tokenDecimals != 6) {
            revert UnsupportedUSDCDecimals(tokenDecimals);
        }
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

    function _getProtocolConfigValues()
        internal
        pure
        returns (
            uint256 bpPrecision,
            uint256 benchmarkYieldBP,
            uint256 protocolFeeBP,
            uint256 earlySalePenaltyBP,
            uint256 depreciationRateBP,
            uint256 minProtocolFee,
            uint256 minEarlySalePenalty
        )
    {
        return (
            ProtocolLib.BP_PRECISION,
            ProtocolLib.BENCHMARK_YIELD_BP,
            ProtocolLib.PROTOCOL_FEE_BP,
            ProtocolLib.EARLY_SALE_PENALTY_BP,
            ProtocolLib.DEPRECIATION_RATE_BP,
            ProtocolLib.MIN_PROTOCOL_FEE,
            ProtocolLib.MIN_EARLY_SALE_PENALTY
        );
    }

    function _isOperationalStatus(AssetLib.AssetStatus status) internal pure returns (bool) {
        return status == AssetLib.AssetStatus.Active || status == AssetLib.AssetStatus.Earning;
    }

    function _isSettledStatus(AssetLib.AssetStatus status) internal pure returns (bool) {
        return status == AssetLib.AssetStatus.Retired || status == AssetLib.AssetStatus.Expired;
    }

    // UUPS Upgrade authorization
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }
}
