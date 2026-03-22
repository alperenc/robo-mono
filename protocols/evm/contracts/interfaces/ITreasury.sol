// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { AssetLib } from "../Libraries.sol";

/**
 * @title ITreasury
 * @dev Interface for the Treasury contract
 */
interface ITreasury {
    /**
     * @dev Events for cross-contract communication and indexing.
     * Ordered to match Treasury execution flow: collateral, earnings/settlement, then admin updates.
     */
    event CollateralLocked(uint256 indexed assetId, address indexed partner, uint256 amount);
    event BaseLiquidityCredited(uint256 indexed assetId, uint256 amount);
    event CollateralReleased(uint256 indexed assetId, address indexed recipient, uint256 amount);
    event WithdrawalProcessed(address indexed recipient, uint256 amount);
    event ShortfallReserved(uint256 indexed assetId, uint256 amount);
    event BufferReplenished(uint256 indexed assetId, uint256 amount, uint256 fromReserved);
    event CollateralBuffersUpdated(
        uint256 indexed assetId, uint256 newEarningsBuffer, uint256 newReservedForLiquidation
    );
    event ImmediateProceedsReleased(uint256 indexed assetId, address indexed partner, uint256 amount);
    event SettlementClaimed(uint256 indexed assetId, address indexed holder, uint256 amount);
    event EarningsManagerUpdated(address indexed oldAddress, address indexed newAddress);
    event PartnerManagerUpdated(address indexed oldAddress, address indexed newAddress);
    event UsdcUpdated(address indexed oldAddress, address indexed newAddress);
    event RoboshareTokensUpdated(address indexed oldAddress, address indexed newAddress);
    event RouterUpdated(address indexed newRouter);
    event TreasuryFeeRecipientUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @dev Shared errors ordered by the main Treasury execution paths.
     */
    error AssetNotFound();
    error NotAssetOwner();
    error NoCollateralLocked();
    error OutstandingRevenueTokens();
    error NoPendingWithdrawals();
    error InvalidEarningsAmount();
    error AssetNotActive(uint256 assetId, AssetLib.AssetStatus currentStatus);
    error AssetNotOperational(uint256 assetId, AssetLib.AssetStatus status);
    error NoInvestors();
    error EarningsLessThanMinimumFee();
    error NoEarningsToClaim();
    error NoPriorEarningsDistribution();
    error NoNewEarningsPeriods();
    error NoEarningsToDistribute();
    error NoUnclaimedEarnings();
    error InsufficientTokenBalance();
    error InsufficientPrimaryLiquidity();
    error SlippageExceeded();
    error EarningsManagerNotSet();
    error AssetNotSettled(uint256 assetId, AssetLib.AssetStatus currentStatus);
    error AssetNotOperationalForSettlement(uint256 assetId, AssetLib.AssetStatus currentStatus);
    error AssetNotOperationalForLiquidation(uint256 assetId, AssetLib.AssetStatus currentStatus);
    error AssetNotEligibleForLiquidation(uint256 assetId);
    error CollateralAlreadyLocked();
    error InsufficientCollateral();
    error NotRouter();

    function assetCollateral(uint256 assetId)
        external
        view
        returns (
            uint256 initialBaseCollateral,
            uint256 baseCollateral,
            uint256 earningsBuffer,
            uint256 protocolBuffer,
            uint256 totalCollateral,
            bool isLocked,
            uint256 lockedAt,
            uint256 lastEventTimestamp,
            uint256 reservedForLiquidation,
            uint256 liquidationThreshold,
            uint256 createdAt,
            uint256 coveredBaseCollateral,
            uint256 outstandingImmediateProceedsBase
        );

    function enableProceeds(uint256 assetId) external;
    function creditBaseLiquidity(uint256 assetId, uint256 amount) external;
    function releaseCollateral(uint256 assetId) external;
    function releaseCollateralFor(address partner, uint256 assetId) external returns (uint256 releasedCollateral);
    function processWithdrawal() external;
    function recordPendingWithdrawal(address recipient, uint256 amount) external;
    function processPrimaryPoolPurchaseFor(
        address buyer,
        uint256 tokenId,
        uint256 amount,
        address partner,
        uint256 grossPrincipal,
        uint256 protocolFee,
        bool protectionEnabled
    ) external;
    function processPrimaryRedemptionFor(address holder, uint256 assetId, uint256 burnAmount, uint256 minPayout)
        external
        returns (uint256 payout);
    function releasePartialCollateral(uint256 assetId) external;
    function isAssetSolvent(uint256 assetId) external view returns (bool);
    /**
     * @dev Preview whether an asset is currently eligible for liquidation using simulated missed-shortfall accrual.
     * @return eligible True if liquidation would be allowed
     * @return reason Encoded reason: 0=EligibleByMaturity, 1=EligibleByInsolvency, 2=AlreadySettled, 3=NotEligible
     */
    function previewLiquidationEligibility(uint256 assetId) external view returns (bool eligible, uint8 reason);
    function initiateSettlement(address partner, uint256 assetId, uint256 topUpAmount)
        external
        returns (uint256 settlementAmount, uint256 settlementPerToken);
    function executeLiquidation(uint256 assetId)
        external
        returns (uint256 liquidationAmount, uint256 settlementPerToken);
    function processSettlementClaimFor(address recipient, uint256 assetId, uint256 amount)
        external
        returns (uint256 claimedAmount);
    function creditEarningsWithdrawal(address account, uint256 amount) external;
    function processEarningsDistributionEffects(
        address partner,
        uint256 assetId,
        uint256 investorAmount,
        uint256 protocolFee,
        bool tryAutoRelease
    ) external returns (uint256 collateralReleased);
    function treasuryFeeRecipient() external view returns (address);
    function previewCollateralRelease(uint256 assetId, bool assumeNewPeriod)
        external
        view
        returns (uint256 releasedAmount);
    function previewSettlementClaim(uint256 assetId, address holder) external view returns (uint256);
    function setEarningsManager(address _earningsManager) external;
    function updatePartnerManager(address _partnerManager) external;
    function updateUSDC(address _usdc) external;
    function updateRoboshareTokens(address _roboshareTokens) external;
    function updateRouter(address _newRouter) external;
    function updateTreasuryFeeRecipient(address _treasuryFeeRecipient) external;
}
