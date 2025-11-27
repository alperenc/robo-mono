// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ProtocolLib, TokenLib } from "./Libraries.sol";

error RoboshareTokens__NotRevenueToken();
error RoboshareTokens__RevenueTokenInfoAlreadySet();
error RoboshareTokens__InsufficientBalance();

/**
 * @title RoboshareTokens
 * @dev ERC1155 token contract with automatic position tracking for Roboshare protocol
 * Handles revenue sharing rights as fungible tokens with FIFO position tracking
 */
contract RoboshareTokens is
    Initializable,
    ERC1155Upgradeable,
    ERC1155HolderUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    // Token ID counter
    uint256 private _tokenIdCounter;

    // Stores TokenInfo structs for each token ID, which includes position tracking
    mapping(uint256 => TokenLib.TokenInfo) private _revenueTokenInfos;

    // Events
    event RevenueTokenPositionsUpdated(
        uint256 indexed revenueTokenId, address indexed from, address indexed to, uint256 amount
    );
    event RevenueTokenInfoSet(uint256 indexed revenueTokenId, uint256 price, uint256 supply);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin) public initializer {
        __ERC1155_init("");
        __ERC1155Holder_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, defaultAdmin);
        _grantRole(BURNER_ROLE, defaultAdmin);
        _grantRole(URI_SETTER_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, defaultAdmin);

        _tokenIdCounter = 1; // Start from 1, 0 reserved.
    }

    /**
     * @dev Reserves a unique pair of token IDs for a new asset.
     * The asset ID will be an odd number, and the revenue token ID will be the next even number.
     * Only callable by accounts with the MINTER_ROLE (i.e., an Asset Registry).
     * @return assetId The unique ID for the new asset.
     * @return revenueTokenId The unique ID for the asset's corresponding revenue token.
     */
    function reserveNextTokenIdPair()
        external
        onlyRole(MINTER_ROLE)
        returns (uint256 assetId, uint256 revenueTokenId)
    {
        assetId = _tokenIdCounter;
        revenueTokenId = _tokenIdCounter + 1;
        _tokenIdCounter += 2;
    }

    /**
     * @dev Initializes the economic info for a new revenue token.
     * Must be called by a minter (i.e., an Asset Registry) BEFORE minting the new revenue token.
     * @param revenueTokenId The ID of the revenue token.
     * @param supply The total supply of the revenue token.
     * @param price The initial price per token.
     */
    function setRevenueTokenInfo(uint256 revenueTokenId, uint256 price, uint256 supply)
        external
        onlyRole(MINTER_ROLE)
    {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert RoboshareTokens__NotRevenueToken();
        }
        TokenLib.TokenInfo storage tokenInfo = _revenueTokenInfos[revenueTokenId];
        if (tokenInfo.tokenId != 0) {
            revert RoboshareTokens__RevenueTokenInfoAlreadySet();
        }

        TokenLib.initializeTokenInfo(
            tokenInfo,
            revenueTokenId,
            price,
            ProtocolLib.MONTHLY_INTERVAL // Default holding period
        );
        emit RevenueTokenInfoSet(revenueTokenId, price, supply);
    }

    /**
     * @dev Sets the base URI for all token types. Requires URI_SETTER_ROLE.
     * @param newuri The new URI for tokens.
     */
    function setURI(string memory newuri) external onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
    }

    /**
     * @dev Mint tokens to specified address. Requires MINTER_ROLE.
     * @param to The address to mint tokens to.
     * @param id The ID of the token to mint.
     * @param amount The amount of tokens to mint.
     * @param data Additional data to be passed to the ERC1155 hook.
     */
    function mint(address to, uint256 id, uint256 amount, bytes memory data) external onlyRole(MINTER_ROLE) {
        _mint(to, id, amount, data);
    }

    /**
     * @dev Mints a batch of tokens. Requires MINTER_ROLE.
     * @param to The address to mint tokens to.
     * @param ids An array of token IDs to mint.
     * @param amounts An array of amounts corresponding to each token ID.
     * @param data Additional data to be passed to the ERC1155 hook.
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        external
        onlyRole(MINTER_ROLE)
    {
        _mintBatch(to, ids, amounts, data);
    }

    /**
     * @dev Burns tokens from a specified address. Requires BURNER_ROLE.
     * @param from The address to burn tokens from.
     * @param id The ID of the token to burn.
     * @param amount The amount of tokens to burn.
     */
    function burn(address from, uint256 id, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, id, amount);
    }

    /**
     * @dev Burns a batch of tokens from a specified address. Requires BURNER_ROLE.
     * @param from The address to burn tokens from.
     * @param ids An array of token IDs to burn.
     * @param amounts An array of amounts corresponding to each token ID.
     */
    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) external onlyRole(BURNER_ROLE) {
        _burnBatch(from, ids, amounts);
    }

    /**
     * @dev Gets the next available asset ID that would be assigned.
     * @return The next available token ID.
     */
    function getNextTokenId() external view returns (uint256) {
        return _tokenIdCounter;
    }

    /**
     * @dev Gets the total supply tracked in positions for a specific token ID.
     * @param revenueTokenId The ID of the token.
     * @return The total supply tracked in positions.
     */
    function getRevenueTokenSupply(uint256 revenueTokenId) external view returns (uint256) {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert RoboshareTokens__NotRevenueToken();
        }
        return _revenueTokenInfos[revenueTokenId].tokenSupply;
    }

    /**
     * @dev Gets the price for a specific revenue token ID.
     * @param revenueTokenId The ID of the revenue token.
     * @return The price per token.
     */
    function getTokenPrice(uint256 revenueTokenId) external view returns (uint256) {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert RoboshareTokens__NotRevenueToken();
        }
        return _revenueTokenInfos[revenueTokenId].tokenPrice;
    }

    /**
     * @dev Gets a user's token positions for earnings calculations.
     * @param revenueTokenId The revenue token ID.
     * @param holder The address of the token holder.
     * @return positions An array of the user's token positions.
     */
    function getUserPositions(uint256 revenueTokenId, address holder)
        external
        view
        returns (TokenLib.TokenPosition[] memory positions)
    {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert RoboshareTokens__NotRevenueToken();
        }
        TokenLib.TokenInfo storage info = _revenueTokenInfos[revenueTokenId];
        uint256 length = info.positions[holder].length;
        positions = new TokenLib.TokenPosition[](length);

        for (uint256 i = 0; i < length; i++) {
            positions[i] = info.positions[holder][i];
        }

        return positions;
    }

    /**
     * @dev Calculates the early sale penalty for a given amount of tokens without modifying state.
     * This function is intended to be called by the Marketplace contract before a sale.
     * @param seller The address of the seller.
     * @param revenueTokenId The ID of the revenue token being sold.
     * @param amount The amount of tokens being sold.
     * @return penaltyAmount The calculated early sale penalty.
     */
    function getSalesPenalty(address seller, uint256 revenueTokenId, uint256 amount)
        external
        view
        returns (uint256 penaltyAmount)
    {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert RoboshareTokens__NotRevenueToken();
        }

        // Check balance before proceeding
        if (balanceOf(seller, revenueTokenId) < amount) {
            revert RoboshareTokens__InsufficientBalance();
        }

        // If the seller is the current owner of the corresponding Asset NFT, they are exempt from the penalty.
        // The assetId is always tokenId - 1 for revenue tokens.
        uint256 assetId = revenueTokenId - 1;
        if (balanceOf(seller, assetId) > 0) {
            penaltyAmount = 0;
        } else {
            // Otherwise, calculate the penalty based on token positions
            penaltyAmount = TokenLib.calculateSalesPenalty(_revenueTokenInfos[revenueTokenId], seller, amount);
        }
    }

    /**
     * @dev Override supportsInterface to include all inherited interfaces.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, ERC1155HolderUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Overrides _update to implement automatic position tracking for revenue tokens.
     * Called on all mints, burns, and transfers.
     */
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal override {
        // Call parent implementation first
        super._update(from, to, ids, values);

        // Update positions for revenue share tokens
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 tokenId = ids[i];
            uint256 amount = values[i];

            // Only track revenue share tokens (even IDs)
            if (TokenLib.isRevenueToken(tokenId)) {
                TokenLib.TokenInfo storage tokenInfo = _revenueTokenInfos[tokenId];

                // Update total supply
                if (from == address(0)) {
                    tokenInfo.tokenSupply += amount;
                } else if (to == address(0)) {
                    tokenInfo.tokenSupply -= amount;
                }

                _updateRevenueTokenPositions(tokenId, from, to, amount);
                emit RevenueTokenPositionsUpdated(tokenId, from, to, amount);
            }
        }
    }

    /**
     * @dev Required override for UUPS upgrades.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    /**
     * @dev Internal function to update token positions using FIFO logic.
     * @param from The address transferring from (address(0) for mints).
     * @param to The address transferring to (address(0) for burns).
     * @param revenueTokenId The token ID being transferred.
     * @param amount The amount being transferred.
     */
    function _updateRevenueTokenPositions(uint256 revenueTokenId, address from, address to, uint256 amount) internal {
        TokenLib.TokenInfo storage tokenInfo = _revenueTokenInfos[revenueTokenId];

        if (from == address(0)) {
            // Minting - add position to receiver
            TokenLib.addPosition(tokenInfo, to, amount);
        } else if (to == address(0)) {
            // Burning - remove position from sender
            TokenLib.removePosition(tokenInfo, from, amount);
        } else {
            // Transfer between users - remove from sender, add to receiver
            TokenLib.removePosition(tokenInfo, from, amount);
            TokenLib.addPosition(tokenInfo, to, amount);
        }
    }
}
