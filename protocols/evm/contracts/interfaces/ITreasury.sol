// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ITreasury
 * @dev Interface for the Treasury contract
 */
interface ITreasury {
    error OutstandingRevenueTokens();

    event CollateralReleased(uint256 indexed assetId, address indexed recipient, uint256 amount);
    event WithdrawalProcessed(address indexed recipient, uint256 amount);
    event CollateralLocked(uint256 indexed assetId, address indexed partner, uint256 amount);
    event ShortfallReserved(uint256 indexed assetId, uint256 amount);
    event BufferReplenished(uint256 indexed assetId, uint256 amount, uint256 fromReserved);
    event CollateralBuffersUpdated(
        uint256 indexed assetId, uint256 newEarningsBuffer, uint256 newReservedForLiquidation
    );
    event EarningsDistributed(uint256 indexed assetId, address indexed partner, uint256 amount, uint256 period);
    event EarningsClaimed(uint256 indexed assetId, address indexed holder, uint256 amount);
    event SettlementClaimed(uint256 indexed assetId, address indexed holder, uint256 amount);
    event RouterUpdated(address indexed newRouter);

    function releaseCollateralFor(address partner, uint256 assetId) external returns (uint256 releasedCollateral);

    function lockCollateral(uint256 assetId, uint256 revenueTokenPrice, uint256 tokenSupply) external;

    function lockCollateralFor(address partner, uint256 assetId, uint256 revenueTokenPrice, uint256 tokenSupply)
        external;

    function releaseCollateral(uint256 assetId) external;

    function initiateSettlement(address partner, uint256 assetId, uint256 topUpAmount)
        external
        returns (uint256 settlementAmount, uint256 settlementPerToken);

    function executeLiquidation(uint256 assetId)
        external
        returns (uint256 liquidationAmount, uint256 settlementPerToken);

    function claimSettlement(uint256 assetId) external returns (uint256 claimedAmount);

    function isAssetSolvent(uint256 assetId) external view returns (bool);

    function distributeEarnings(uint256 assetId, uint256 amount) external;

    function claimEarnings(uint256 assetId) external;

    function releasePartialCollateral(uint256 assetId) external;

    function getTotalCollateralRequirement(uint256 revenueTokenPrice, uint256 tokenSupply)
        external
        pure
        returns (uint256);

    function getAssetCollateralInfo(uint256 assetId)
        external
        view
        returns (uint256 baseCollateral, uint256 totalCollateral, bool isLocked, uint256 lockedAt, uint256 lockDuration);

    function getPendingWithdrawal(address account) external view returns (uint256);

    function getTreasuryStats() external view returns (uint256 totalDeposited, uint256 treasuryBalance);

    function updateRouter(address _newRouter) external;

    function updatePartnerManager(address _partnerManager) external;

    function updateUSDC(address _usdc) external;

    function updateRoboshareTokens(address _roboshareTokens) external;

    function updateTreasuryFeeRecipient(address _treasuryFeeRecipient) external;
}
