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
     * @dev Asset registration and token minting
     */
    function registerAsset(bytes calldata data) external returns (uint256 assetId);

    function mintRevenueTokens(uint256 assetId, uint256 supply, uint256 price) external returns (uint256 tokenId);

    function registerAssetAndMintTokens(bytes calldata data, uint256 supply, uint256 price)
        external
        returns (uint256 assetId, uint256 tokenId);

    /**
     * @dev Asset Lifecycle
     */
    function retireAsset(uint256 assetId) external;

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

    /**
     * @dev Shared Errors
     */
    error AssetNotFound(uint256 assetId);
    error NotAuthorized();
}
