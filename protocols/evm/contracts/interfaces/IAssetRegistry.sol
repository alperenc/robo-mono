// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { AssetLib } from "../Libraries.sol";

/**
 * @title IAssetRegistry
 * @dev Generic Asset Registry interface for protocol-wide asset management
 * Designed to be implemented by different asset registries (Vehicle, Equipment, Real Estate, etc.)
 * Provides standardized access to asset information and token position management
 */
interface IAssetRegistry {
    /**
     * @dev Events for cross-contract communication and indexing
     */
    event AssetRegistered(uint256 indexed assetId, address indexed owner, AssetLib.AssetStatus status);
    event AssetStatusUpdated(
        uint256 indexed assetId, AssetLib.AssetStatus indexed oldStatus, AssetLib.AssetStatus indexed newStatus
    );
    event AssetRetired(
        uint256 indexed assetId, address indexed partner, uint256 burnedTokens, uint256 releasedCollateral
    );
    event AssetSettled(
        uint256 indexed assetId, address indexed partner, uint256 settlementAmount, uint256 settlementPerToken
    );
    event AssetExpired(uint256 indexed assetId, uint256 liquidationAmount, uint256 settlementPerToken);
    event SettlementClaimed(uint256 indexed assetId, address indexed holder, uint256 amount, uint256 payout);

    /**
     * @dev Shared Errors
     */
    error NotAssetOwner();
    error AssetNotFound(uint256 assetId);
    error AssetNotActive(uint256 assetId, AssetLib.AssetStatus currentStatus);
    error RevenueTokensNotMinted(uint256 assetId);

    error AssetNotEligibleForLiquidation(uint256 assetId);
    error AssetNotSettled(uint256 assetId, AssetLib.AssetStatus currentStatus);
    error AssetAlreadySettled(uint256 assetId, AssetLib.AssetStatus currentStatus);
    error InsufficientTokenBalance(uint256 tokenId, uint256 required, uint256 available);

    /**
     * @dev Asset registration and token minting
     */
    function registerAsset(bytes calldata data) external returns (uint256 assetId);
    function mintRevenueTokens(uint256 assetId, uint256 supply, uint256 price, uint256 maturityDate)
        external
        returns (uint256 tokenId);
    function registerAssetAndMintTokens(bytes calldata data, uint256 supply, uint256 price, uint256 maturityDate)
        external
        returns (uint256 assetId, uint256 tokenId);
    function registerAssetMintAndList(
        bytes calldata data,
        uint256 supply,
        uint256 price,
        uint256 maturityDate,
        uint256 listingDuration,
        bool buyerPaysFee
    ) external returns (uint256 assetId, uint256 revenueTokenId, uint256 listingId);

    /**
     * @dev Asset Lifecycle
     */
    function retireAsset(uint256 assetId) external;
    function settleAsset(uint256 assetId, uint256 topUpAmount) external;
    function liquidateAsset(uint256 assetId) external;
    function claimSettlement(uint256 assetId, bool autoClaimEarnings)
        external
        returns (uint256 claimedAmount, uint256 earningsClaimed);
    function burnRevenueTokens(uint256 assetId, uint256 amount) external;
    function retireAssetAndBurnTokens(uint256 assetId) external;

    /**
     * @dev State management
     */
    function setAssetStatus(uint256 assetId, AssetLib.AssetStatus status) external;

    /**
     * @dev Asset existence and validation
     */
    function assetExists(uint256 assetId) external view returns (bool);
    function getAssetInfo(uint256 assetId) external view returns (AssetLib.AssetInfo memory);
    function getAssetStatus(uint256 assetId) external view returns (AssetLib.AssetStatus);

    /**
     * @dev Token mapping and relationships
     * Each asset can have multiple token types (ownership, revenue share, etc.)
     */
    function getAssetIdFromTokenId(uint256 tokenId) external view returns (uint256);
    function getTokenIdFromAssetId(uint256 assetId) external view returns (uint256);

    /**
     * @dev Access control and permissions
     */
    function isAuthorizedForAsset(address account, uint256 assetId) external view returns (bool);
    function getRegistryForAsset(uint256 assetId) external view returns (address);

    /**
     * @dev Registry metadata and capabilities
     * Allows introspection and feature discovery
     */
    function getRegistryType() external pure returns (string memory);
    function getRegistryVersion() external pure returns (uint256);
}
