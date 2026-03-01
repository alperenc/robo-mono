// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IMarketplace
 * @dev Minimal interface for Marketplace contract, used by authorized orchestrators where needed.
 */
interface IMarketplace {
    struct PrimaryPool {
        uint256 tokenId;
        address partner;
        uint256 pricePerToken;
        uint256 maxSupply;
        bool immediateProceeds;
        bool protectionEnabled;
        bool isPaused;
        bool isClosed;
        uint256 createdAt;
        uint256 pausedAt;
        uint256 closedAt;
    }

    struct Listing {
        uint256 listingId;
        uint256 tokenId;
        uint256 amount;
        uint256 soldAmount;
        uint256 pricePerToken;
        address seller;
        uint256 expiresAt;
        bool isActive;
        uint256 createdAt;
        bool buyerPaysFee;
        uint256 earlySalePenalty;
        bool isPrimary;
    }

    function createPrimaryPoolFor(
        address partner,
        uint256 tokenId,
        uint256 pricePerToken,
        uint256 maxSupply,
        bool immediateProceeds,
        bool protectionEnabled
    ) external;

    function isAssetMarketOperational(uint256 assetId) external view returns (bool);

    function tokenEscrow(uint256 tokenId) external view returns (uint256);
}
