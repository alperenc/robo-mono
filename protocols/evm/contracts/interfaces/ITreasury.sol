// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../Libraries.sol";

/**
 * @title ITreasury
 * @dev Treasury interface for position management and token tracking
 * Used by asset registries to delegate TokenLib operations
 */
interface ITreasury {

    /**
     * @dev Update token positions during transfers
     * @param assetId The asset ID
     * @param from Source address (address(0) for minting)
     * @param to Destination address (address(0) for burning)
     * @param amount Number of tokens transferred
     * @param checkPenalty Whether to calculate early sale penalties
     * @return penalty Penalty amount if applicable
     */
    function updateAssetTokenPositions(
        uint256 assetId,
        address from,
        address to,
        uint256 amount,
        bool checkPenalty
    ) external returns (uint256 penalty);

    /**
     * @dev Check if asset token info is initialized
     * @param assetId The asset ID
     * @return Whether token tracking is set up for this asset
     */
    function isAssetTokenInfoInitialized(uint256 assetId) external view returns (bool);
}