// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../Libraries.sol";

/**
 * @title IAssetsRegistry
 * @dev Generic Assets Registry interface for protocol-wide asset management
 * Designed to be implemented by different asset registries (Vehicle, Equipment, Real Estate, etc.)
 * Provides standardized access to asset information and token position management
 */
interface IAssetsRegistry {
    // Asset status enumeration for lifecycle management
    enum AssetStatus { 
        Inactive,   // Asset exists but not operational
        Active,     // Asset is operational and earning
        Suspended,  // Temporarily halted operations
        Archived    // Permanently retired
    }
    
    // Generic asset information structure
    struct AssetInfo {
        uint256 assetId;           // Unique asset identifier
        AssetStatus status;        // Current asset status
        uint256 createdAt;         // Asset registration timestamp
        uint256 updatedAt;         // Last status/metadata update
    }
    
    // Token type enumeration for multi-token assets
    enum TokenType {
        Asset,          // Asset ownership token (e.g., vehicle NFT)
        RevenueShare    // Revenue sharing token (e.g., earnings rights)
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
    function getAssetTokenInfo(uint256 assetId) external view returns (TokenLib.TokenInfo memory);
    function isRevenueShareToken(uint256 tokenId) external view returns (bool);

    /**
     * @dev Position management (called by token contract during transfers)
     * Updates TokenLib positions to track earnings eligibility
     */
    function updateTokenPositions(
        uint256 tokenId,
        address from,
        address to,
        uint256 amount,
        bool checkPenalty
    ) external returns (uint256 penalty);

    /**
     * @dev Batch position updates for gas efficiency
     * Handles multiple token transfers in single transaction
     */
    function updateBatchTokenPositions(
        uint256[] calldata tokenIds,
        address from,
        address to,
        uint256[] calldata amounts,
        bool checkPenalty
    ) external returns (uint256 totalPenalty);

    /**
     * @dev Access control and permissions
     */
    function canUpdatePositions(address caller, uint256 assetId) external view returns (bool);
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
    event AssetRegistered(uint256 indexed assetId, address indexed owner, AssetStatus status);
    event AssetStatusUpdated(uint256 indexed assetId, AssetStatus indexed oldStatus, AssetStatus indexed newStatus);
    event AssetOwnerUpdated(uint256 indexed assetId, address indexed oldOwner, address indexed newOwner);
    event TokenPositionsUpdated(
        uint256 indexed tokenId, 
        address indexed from, 
        address indexed to, 
        uint256 amount, 
        uint256 penalty
    );
    event BatchTokenPositionsUpdated(
        uint256[] tokenIds, 
        address indexed from, 
        address indexed to, 
        uint256[] amounts, 
        uint256 totalPenalty
    );

    /**
     * @dev Registry-specific errors
     */
    error AssetsRegistry__AssetNotFound(uint256 assetId);
    error AssetsRegistry__AssetNotActive(uint256 assetId);
    error AssetsRegistry__UnauthorizedCaller(address caller);
    error AssetsRegistry__InvalidTokenType(TokenType tokenType);
    error AssetsRegistry__TokenNotFound(uint256 tokenId);
    error AssetsRegistry__InvalidAssetStatus(AssetStatus status);
}