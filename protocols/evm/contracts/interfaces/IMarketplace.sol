// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IMarketplace
 * @dev Minimal interface for Marketplace contract, used by asset registries for createListingFor
 */
interface IMarketplace {
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
}
