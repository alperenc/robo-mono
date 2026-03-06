// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IMarketplace
 * @dev Minimal Marketplace interface used for cross-contract orchestration.
 */
interface IMarketplace {
    function createPrimaryPoolFor(
        address partner,
        uint256 tokenId,
        uint256 pricePerToken,
        uint256 maxSupply,
        bool immediateProceeds,
        bool protectionEnabled
    ) external;

    function getPrimaryPoolProtectionEnabled(uint256 tokenId) external view returns (bool);
}
