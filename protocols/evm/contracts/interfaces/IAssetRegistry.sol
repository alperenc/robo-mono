// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../Libraries.sol";

/**
 * @title IAssetRegistry
 * @dev Generic Asset Registry interface for protocol-wide asset management
 * Designed to be implemented by different asset registries (Vehicle, Equipment, Real Estate, etc.)
 * Provides standardized access to asset information and token position management
 */
interface IAssetRegistry {
    // Generic asset information structure
    struct AssetInfo {
        uint256 assetId; // Unique asset identifier
        AssetsLib.AssetStatus status; // Current asset status
        uint256 createdAt; // Asset registration timestamp
        uint256 updatedAt; // Last status/metadata update
    }

    // Token type enumeration for multi-token assets
    enum TokenType {
        Asset, // Asset ownership token (e.g., vehicle NFT)
        Revenue // Revenue sharing token (e.g., earnings rights)

    }

    /**
     * @dev Asset existence and validation
     */
    function assetExists(uint256 assetId) external view returns (bool);
    function getAssetInfo(uint256 assetId) external view returns (AssetInfo memory);
    function isAssetActive(uint256 assetId) external view returns (bool);

    /**
     * @dev Token mapping and relationships
     * Each asset can have multiple token types (ownership, revenue share, etc.)
     */
    function getAssetIdFromTokenId(uint256 tokenId) external view returns (uint256);
    function getTokenIdFromAssetId(uint256 assetId, TokenType tokenType) external view returns (uint256);
    function isRevenueToken(uint256 tokenId) external view returns (bool);

    /**
     * @dev Access control and permissions
     */
    function isAuthorizedForAsset(address account, uint256 assetId) external view returns (bool);

    /**
     * @dev Registry metadata and capabilities
     * Allows introspection and feature discovery
     */
    function getRegistryType() external pure returns (string memory);
    function getRegistryVersion() external pure returns (uint256);
    function getSupportedTokenTypes() external pure returns (TokenType[] memory);

    /**
     * @dev Events for cross-contract communication and indexing
     */
    event AssetRegistered(uint256 indexed assetId, address indexed owner, AssetsLib.AssetStatus status);
    event AssetStatusUpdated(
        uint256 indexed assetId, AssetsLib.AssetStatus indexed oldStatus, AssetsLib.AssetStatus indexed newStatus
    );
    event AssetOwnerUpdated(uint256 indexed assetId, address indexed oldOwner, address indexed newOwner);

    /**
     * @dev Registry-specific errors
     */
    error AssetRegistry__AssetNotFound(uint256 assetId);
    error AssetRegistry__AssetNotActive(uint256 assetId);
    error AssetRegistry__UnauthorizedCaller(address caller);
    error AssetRegistry__InvalidTokenType(TokenType tokenType);
    error AssetRegistry__TokenNotFound(uint256 tokenId);
    error AssetRegistry__InvalidAssetStatus(AssetsLib.AssetStatus status);
}
