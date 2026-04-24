// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { TokenLib } from "../Libraries.sol";

/**
 * @title IPositionManager
 * @notice Canonical manager boundary for position, lock, redemption, and settlement state.
 * @dev Redemption and settlement are intentionally kept in this same manager for the split refactor.
 *
 * Boundary decisions frozen for downstream rewiring:
 * - RoboshareTokens remains the ERC1155 balance, supply, and token metadata surface.
 * - Asset registries remain responsible for protocol-critical asset lifecycle state.
 * - Treasury remains the cash, collateral, earnings-effect, and withdrawal-credit layer.
 * - PositionManager owns holder positions, listing locks, redemption epochs, and settlement claim state.
 */
interface IPositionManager {
    enum PositionMutationType {
        Mint,
        Burn,
        TransferIn,
        TransferOut,
        Lock,
        Unlock,
        Redemption,
        SettlementClaim
    }

    struct PositionMutation {
        uint256 assetId;
        uint256 tokenId;
        address account;
        uint256 amount;
        uint256 auxValue;
        PositionMutationType mutationType;
        bytes32 reason;
    }

    event PositionManagerInitialized(
        address indexed admin,
        address indexed registryRouter,
        address indexed roboshareTokens,
        address partnerManager,
        address marketplace,
        address treasury,
        address usdc
    );

    event RegistryRouterUpdated(address indexed oldAddress, address indexed newAddress);
    event RoboshareTokensUpdated(address indexed oldAddress, address indexed newAddress);
    event PartnerManagerUpdated(address indexed oldAddress, address indexed newAddress);
    event MarketplaceUpdated(address indexed oldAddress, address indexed newAddress);
    event TreasuryUpdated(address indexed oldAddress, address indexed newAddress);
    event UsdcUpdated(address indexed oldAddress, address indexed newAddress);

    event PositionMutated(
        uint256 indexed assetId,
        uint256 indexed tokenId,
        address indexed account,
        uint256 amount,
        uint256 auxValue,
        PositionMutationType mutationType,
        bytes32 reason
    );

    event ListingLocked(address indexed holder, uint256 indexed revenueTokenId, uint256 amount);
    event ListingUnlocked(address indexed holder, uint256 indexed revenueTokenId, uint256 amount);
    event LockedTransferSettled(
        address indexed from, address indexed to, uint256 indexed revenueTokenId, uint256 amount
    );
    event SalePenaltyBooked(
        uint256 indexed listingId, address indexed seller, uint256 indexed revenueTokenId, uint256 amount
    );

    event PositionLockUpdated(
        uint256 indexed assetId, uint256 indexed tokenId, address indexed account, uint256 lockUntil, bytes32 reason
    );

    event RedemptionEpochUpdated(
        uint256 indexed tokenId, uint256 indexed epochId, uint256 redeemableSupply, bytes32 reason
    );

    event SettlementConfigured(
        uint256 indexed assetId,
        uint256 indexed epochId,
        uint256 settlementAmount,
        uint256 settlementPerToken,
        bytes32 reason
    );

    event SettlementClaimRecorded(
        uint256 indexed assetId,
        uint256 indexed tokenId,
        address indexed account,
        uint256 burnAmount,
        uint256 payout,
        bytes32 reason
    );

    error ZeroAddress();
    error NotRevenueToken();
    error InvalidAmount();
    error InsufficientUnlockedBalance();
    error InsufficientLockedBalance();
    error UnsupportedPositionMutation(PositionMutationType mutationType);

    function initialize(
        address admin,
        address registryRouter,
        address roboshareTokens,
        address partnerManager,
        address marketplace,
        address treasury,
        address usdc
    ) external;

    function UPGRADER_ROLE() external view returns (bytes32);
    function POSITION_ADMIN_ROLE() external view returns (bytes32);
    function AUTHORIZED_ROUTER_ROLE() external view returns (bytes32);
    function AUTHORIZED_MARKETPLACE_ROLE() external view returns (bytes32);
    function AUTHORIZED_TREASURY_ROLE() external view returns (bytes32);

    function registryRouter() external view returns (address);
    function roboshareTokens() external view returns (address);
    function partnerManager() external view returns (address);
    function marketplace() external view returns (address);
    function treasury() external view returns (address);
    function usdc() external view returns (address);

    function updateRegistryRouter(address newRegistryRouter) external;
    function updateRoboshareTokens(address newRoboshareTokens) external;
    function updatePartnerManager(address newPartnerManager) external;
    function updateMarketplace(address newMarketplace) external;
    function updateTreasury(address newTreasury) external;
    function updateUsdc(address newUsdc) external;

    function recordPositionMutation(PositionMutation calldata mutation) external;

    function getUserPositions(uint256 revenueTokenId, address holder)
        external
        view
        returns (TokenLib.TokenPosition[] memory positions);

    function getLockedAmount(address holder, uint256 revenueTokenId) external view returns (uint256);

    function getAvailableAmount(address holder, uint256 revenueTokenId, uint256 totalBalance)
        external
        view
        returns (uint256);

    function lockForListing(address holder, uint256 revenueTokenId, uint256 amount) external;

    function unlockForListing(address holder, uint256 revenueTokenId, uint256 amount) external;

    function settleLockedTransfer(address from, address to, uint256 revenueTokenId, uint256 amount) external;

    function bookSalePenalty(uint256 listingId, address seller, uint256 revenueTokenId, uint256 amount) external;

    function clearSalePenalty(uint256 listingId) external;

    function getSalePenalty(uint256 listingId) external view returns (uint256);

    function recordPositionLock(uint256 assetId, uint256 tokenId, address account, uint256 lockUntil, bytes32 reason)
        external;

    function recordRedemptionEpoch(uint256 tokenId, uint256 epochId, uint256 redeemableSupply, bytes32 reason) external;

    function recordSettlement(
        uint256 assetId,
        uint256 epochId,
        uint256 settlementAmount,
        uint256 settlementPerToken,
        bytes32 reason
    ) external;

    function recordSettlementClaim(
        uint256 assetId,
        uint256 tokenId,
        address account,
        uint256 burnAmount,
        uint256 payout,
        bytes32 reason
    ) external;
}
