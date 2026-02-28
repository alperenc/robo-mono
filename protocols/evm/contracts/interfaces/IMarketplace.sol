// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IMarketplace
 * @dev Minimal interface for Marketplace contract, used by asset registries for createListingFor
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

    /**
     * @dev Create a listing on behalf of a seller (for authorized contracts like VehicleRegistry)
     * @param seller The address of the seller
     * @param tokenId The revenue share token ID
     * @param amount Number of tokens to list
     * @param pricePerToken Price per token in USDC
     * @param duration Listing duration in seconds
     * @param buyerPaysFee If true, buyer pays protocol fee
     */
    function createListingFor(
        address seller,
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerToken,
        uint256 duration,
        bool buyerPaysFee
    ) external returns (uint256 listingId);

    function createPrimaryPoolFor(
        address partner,
        uint256 tokenId,
        uint256 pricePerToken,
        uint256 maxSupply,
        bool immediateProceeds,
        bool protectionEnabled
    ) external;

    function isAssetEligibleForListing(uint256 assetId) external view returns (bool);

    function tokenEscrow(uint256 tokenId) external view returns (uint256);
}
