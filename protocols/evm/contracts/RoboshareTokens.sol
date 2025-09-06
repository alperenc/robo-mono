// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title RoboshareTokens
 * @dev Pure ERC1155 token contract for Roboshare protocol
 * Handles vehicle shares as fungible tokens within each vehicle type
 */
contract RoboshareTokens is
    Initializable,
    ERC1155Upgradeable,
    ERC1155HolderUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    uint256 private _tokenIdCounter;

    // Events
    event BatchTokensMinted(address indexed to, uint256[] ids, uint256[] amounts);
    event TokensBurned(address indexed from, uint256 id, uint256 amount);

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
