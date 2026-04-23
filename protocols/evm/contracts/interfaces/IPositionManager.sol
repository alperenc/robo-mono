// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPositionManager {
    function beforeRevenueTokenUpdate(address from, address to, uint256 tokenId, uint256 amount) external;
}
