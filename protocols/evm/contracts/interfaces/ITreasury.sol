// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { AssetLib, CollateralLib } from "../Libraries.sol";

/**
 * @title ITreasury
 * @dev Interface for the Treasury contract
 */
interface ITreasury {
    /**
     * @dev Events for cross-contract communication and indexing
     */
    event CollateralReleased(uint256 indexed assetId, address indexed recipient, uint256 amount);
    event WithdrawalProcessed(address indexed recipient, uint256 amount);
    event CollateralLocked(uint256 indexed assetId, address indexed partner, uint256 amount);
    event BaseEscrowCredited(uint256 indexed assetId, uint256 amount);
    event ShortfallReserved(uint256 indexed assetId, uint256 amount);
    event BufferReplenished(uint256 indexed assetId, uint256 amount, uint256 fromReserved);
    event CollateralBuffersUpdated(
        uint256 indexed assetId, uint256 newEarningsBuffer, uint256 newReservedForLiquidation
    );
    event EarningsDistributed(
        uint256 indexed assetId, address indexed partner, uint256 totalRevenue, uint256 investorEarnings, uint256 period
    );
    event EarningsClaimed(uint256 indexed assetId, address indexed holder, uint256 amount);
    event SettlementClaimed(uint256 indexed assetId, address indexed holder, uint256 amount);
    event RouterUpdated(address indexed newRouter);
    event PartnerManagerUpdated(address indexed oldAddress, address indexed newAddress);
    event UsdcUpdated(address indexed oldAddress, address indexed newAddress);
    event RoboshareTokensUpdated(address indexed oldAddress, address indexed newAddress);
    event TreasuryFeeRecipientUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @dev Shared Errors
     */
    error OutstandingRevenueTokens();
    error NoCollateralLocked();
    error CollateralAlreadyLocked();
    error InsufficientCollateral();
    error NoPendingWithdrawals();
    error AssetNotFound();
    error NotAssetOwner();
    error InvalidEarningsAmount();
    error NoEarningsToClaim();
    error NoInvestors();
    error NoPriorEarningsDistribution();
    error InsufficientTokenBalance();
    error AssetNotActive(uint256 assetId, AssetLib.AssetStatus currentStatus);
    error AssetNotOperational(uint256 assetId, AssetLib.AssetStatus status);
    error EarningsLessThanMinimumFee();
    error NoNewEarningsPeriods();
    error NoEarningsToDistribute();
    error NotRouter();
    error AssetNotSettled(uint256 assetId, AssetLib.AssetStatus currentStatus);
    error AssetNotOperationalForLiquidation(uint256 assetId, AssetLib.AssetStatus currentStatus);
    error AssetNotEligibleForLiquidation(uint256 assetId);
    error AssetNotOperationalForSettlement(uint256 assetId, AssetLib.AssetStatus currentStatus);
    error NoUnclaimedEarnings();

    function releaseCollateral(uint256 assetId) external;
    function releaseCollateralFor(address partner, uint256 assetId) external returns (uint256 releasedCollateral);
    function fundBuffersFor(address partner, uint256 assetId, uint256 baseAmount) external;
    function initiateSettlement(address partner, uint256 assetId, uint256 topUpAmount)
        external
        returns (uint256 settlementAmount, uint256 settlementPerToken);
    function executeLiquidation(uint256 assetId)
        external
        returns (uint256 liquidationAmount, uint256 settlementPerToken);
    function processSettlementClaim(address recipient, uint256 assetId, uint256 amount)
        external
        returns (uint256 claimedAmount);
    /**
     * @dev Preview whether an asset is currently eligible for liquidation using simulated missed-shortfall accrual.
     * @return eligible True if liquidation would be allowed
     * @return reason Encoded reason: 0=EligibleByMaturity, 1=EligibleByInsolvency, 2=AlreadySettled, 3=NotEligible
     */
    function previewLiquidationEligibility(uint256 assetId) external view returns (bool eligible, uint8 reason);
    function isAssetSolvent(uint256 assetId) external view returns (bool);
    function distributeEarnings(uint256 assetId, uint256 totalRevenue, bool tryAutoRelease)
        external
        returns (uint256 collateralReleased);
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
        );
    function getMarketProjectionConstants()
        external
        pure
        returns (uint256 benchmarkYieldBP, uint256 depreciationRateBP, uint256 bpPrecision);
    function claimEarnings(uint256 assetId) external;
    function snapshotAndClaimEarnings(uint256 assetId, address holder, bool autoClaim)
        external
        returns (uint256 snapshotAmount);
    function releasePartialCollateral(uint256 assetId) external;
    function releaseAndWithdrawCollateral(uint256 assetId) external returns (uint256 withdrawn);
    function claimAndWithdrawEarnings(uint256 assetId) external returns (uint256 withdrawn);
    function creditBaseEscrow(uint256 assetId, uint256 amount) external;
    function recordPendingWithdrawal(address recipient, uint256 amount) external;
    function processWithdrawalFor(address account) external returns (uint256 amount);
    function treasuryFeeRecipient() external view returns (address);
    function getTotalBufferRequirement(uint256 baseAmount, uint256 yieldBP) external pure returns (uint256);
    function getAssetCollateralInfo(uint256 assetId) external view returns (CollateralLib.CollateralInfo memory);
    function previewCollateralRelease(uint256 assetId, bool assumeNewPeriod)
        external
        view
        returns (uint256 releasedAmount);
    function getPendingWithdrawal(address account) external view returns (uint256);
    function previewClaimEarnings(uint256 assetId, address holder) external view returns (uint256);
    function previewSettlementClaim(uint256 assetId, address holder) external view returns (uint256);
    function getTreasuryStats() external view returns (uint256 totalDeposited, uint256 treasuryBalance);
    function updateRouter(address _newRouter) external;
    function updatePartnerManager(address _partnerManager) external;
    function updateUSDC(address _usdc) external;
    function updateRoboshareTokens(address _roboshareTokens) external;
    function updateTreasuryFeeRecipient(address _treasuryFeeRecipient) external;
}
