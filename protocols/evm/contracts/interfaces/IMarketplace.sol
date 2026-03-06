// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IMarketplace
 * @dev Minimal Marketplace interface used for cross-contract orchestration.
 */
interface IMarketplace {
    function createPrimaryPoolFor(address partner, uint256 tokenId, uint256 pricePerToken) external;
    function closePrimaryPool(uint256 tokenId) external;
}
