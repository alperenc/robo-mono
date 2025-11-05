// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./Libraries.sol";

error RoboshareTokens__NotRevenueToken();

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
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    uint256 private _tokenIdCounter;

    // Position tracking for revenue share tokens
    mapping(uint256 => TokenLib.TokenInfo) private tokenPositions;

    // Events
    event BatchTokensMinted(address indexed to, uint256[] ids, uint256[] amounts);
    event TokensBurned(address indexed from, uint256 id, uint256 amount);
    event PositionsUpdated(uint256 indexed tokenId, address indexed from, address indexed to, uint256 amount);

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
        _grantRole(UPGRADER_ROLE, defaultAdmin);

        _tokenIdCounter = 1; // Start from 1, 0 reserved for special use
    }

    /**
     * @dev Mint tokens to specified address
     * @param to Address to mint tokens to
     * @param id Token ID to mint
     * @param amount Amount of tokens to mint
     * @param data Additional data
     */
    function mint(address to, uint256 id, uint256 amount, bytes memory data) public onlyRole(MINTER_ROLE) {
        _mint(to, id, amount, data);
    }

    /**
     * @dev Batch mint multiple tokens
     * @param to Address to mint tokens to
     * @param ids Array of token IDs
     * @param amounts Array of amounts to mint
     * @param data Additional data
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyRole(MINTER_ROLE)
    {
        _mintBatch(to, ids, amounts, data);
        emit BatchTokensMinted(to, ids, amounts);
    }

    /**
     * @dev Burn tokens from specified address
     * @param from Address to burn tokens from
     * @param id Token ID to burn
     * @param amount Amount of tokens to burn
     */
    function burn(address from, uint256 id, uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(from, id, amount);
        emit TokensBurned(from, id, amount);
    }

    /**
     * @dev Burn multiple tokens from specified address
     * @param from Address to burn tokens from
     * @param ids Array of token IDs to burn
     * @param amounts Array of amounts to burn
     */
    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) public onlyRole(BURNER_ROLE) {
        _burnBatch(from, ids, amounts);

        for (uint256 i = 0; i < ids.length; i++) {
            emit TokensBurned(from, ids[i], amounts[i]);
        }
    }

    /**
     * @dev Get next available token ID
     */
    function getNextTokenId() external view returns (uint256) {
        return _tokenIdCounter;
    }

    /**
     * @dev Increment and return next token ID
     * Only callable by minters to ensure proper ID management
     */
    function getAndIncrementTokenId() external onlyRole(MINTER_ROLE) returns (uint256) {
        uint256 currentId = _tokenIdCounter;
        _tokenIdCounter++;
        return currentId;
    }

    /**
     * @dev Set URI for all token types
     * @param newuri New URI for tokens
     */
    function setURI(string memory newuri) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _setURI(newuri);
    }

    /**
     * @dev Get total supply tracked in positions for a token
     * @param tokenId Token ID to get supply for
     * @return totalSupply Total supply tracked in positions
     */
    function getTokenTotalSupply(uint256 tokenId) external view returns (uint256) {
        return tokenPositions[tokenId].totalSupply;
    }

    /**
     * @dev Get user balance from position tracking (should match balanceOf)
     * @param user User address
     * @param tokenId Token ID
     * @return balance User's balance from positions
     */
    function getPositionBalance(address user, uint256 tokenId) external view returns (uint256 balance) {
        return TokenLib.getBalance(tokenPositions[tokenId], user);
    }

    /**
     * @dev Check if a token ID is a revenue share token (even numbers)
     * @param tokenId Token ID to check
     * @return isRevenueToken True if token is revenue share token
     */
    function isRevenueToken(uint256 tokenId) public pure returns (bool) {
        return tokenId % 2 == 0;
    }

    /**
     * @dev Get user's token positions for earnings calculations
     * @param tokenId Revenue share token ID
     * @param holder Address of the token holder
     * @return positions Array of user's positions
     */
    function getUserPositions(uint256 tokenId, address holder)
        external
        view
        returns (TokenLib.TokenPosition[] memory positions)
    {
        if (!isRevenueToken(tokenId)) {
            revert RoboshareTokens__NotRevenueToken();
        }
        TokenLib.TokenInfo storage info = tokenPositions[tokenId];
        uint256 length = info.positions[holder].length;
        positions = new TokenLib.TokenPosition[](length);

        for (uint256 i = 0; i < length; i++) {
            positions[i] = info.positions[holder][i];
        }

        return positions;
    }

    /**
     * @dev Override _update to implement automatic position tracking
     * Called on all mints, burns, and transfers
     */
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal override {
        // Call parent implementation first
        super._update(from, to, ids, values);

        // Update positions for revenue share tokens
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 tokenId = ids[i];
            uint256 amount = values[i];

            // Only track revenue share tokens (even IDs)
            if (isRevenueToken(tokenId)) {
                _updateTokenPositions(from, to, tokenId, amount);
                emit PositionsUpdated(tokenId, from, to, amount);
            }
        }
    }

    /**
     * @dev Internal function to update token positions using FIFO logic
     * @param from Address transferring from (address(0) for mints)
     * @param to Address transferring to (address(0) for burns)
     * @param tokenId Token ID being transferred
     * @param amount Amount being transferred
     */
    function _updateTokenPositions(address from, address to, uint256 tokenId, uint256 amount) internal {
        TokenLib.TokenInfo storage tokenInfo = tokenPositions[tokenId];

        if (from == address(0)) {
            // Minting - add position to receiver
            TokenLib.addPosition(tokenInfo, to, amount);
        } else if (to == address(0)) {
            // Burning - remove position from sender
            // Note: We don't apply penalties on burns, only on sales to other users
            TokenLib.removePosition(tokenInfo, from, amount, false);
        } else {
            // Transfer between users - remove from sender, add to receiver
            // No penalty for user-to-user transfers
            TokenLib.removePosition(tokenInfo, from, amount, false);
            TokenLib.addPosition(tokenInfo, to, amount);
        }
    }

    /**
     * @dev Required override for UUPS upgrades
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    /**
     * @dev Override supportsInterface to include all inherited interfaces
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155Upgradeable, ERC1155HolderUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
