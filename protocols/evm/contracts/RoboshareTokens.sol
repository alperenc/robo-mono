// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {
    ERC1155HolderUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ProtocolLib, TokenLib } from "./Libraries.sol";

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
    bytes32 public constant AUTHORIZED_CONTRACT_ROLE = keccak256("AUTHORIZED_CONTRACT_ROLE");

    // Errors
    error ZeroAddress();
    error NotRevenueToken();
    error RevenueTokenInfoAlreadySet();
    error InvalidLockAmount();
    error InsufficientUnlockedBalance();
    error InsufficientLockedBalance();

    // Events
    event RevenueTokenPositionsUpdated(
        uint256 indexed revenueTokenId, address indexed from, address indexed to, uint256 amount
    );
    event RevenueTokenInfoSet(
        uint256 indexed revenueTokenId,
        uint256 price,
        uint256 supply,
        uint256 maxSupply,
        uint256 maturityDate,
        bool immediateProceeds,
        bool protectionEnabled
    );
    event RevenueTokenLocked(uint256 indexed revenueTokenId, address indexed holder, uint256 amount);
    event RevenueTokenUnlocked(uint256 indexed revenueTokenId, address indexed holder, uint256 amount);
    event PrimaryRedemptionStateUpdated(
        uint256 indexed revenueTokenId, uint256 redemptionEpoch, uint256 epochSupply, uint256 backedPrincipal
    );

    // Token state
    uint256 private _tokenIdCounter;
    mapping(uint256 => TokenLib.TokenInfo) private _revenueTokenInfos;
    mapping(address => mapping(uint256 => uint256)) private _lockedRevenueTokenAmounts;
    bool private _currentEpochBurnActive;
    address private _currentEpochBurnHolder;
    uint256 private _currentEpochBurnTokenId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin) public initializer {
        if (defaultAdmin == address(0)) revert ZeroAddress();
        __ERC1155_init("");
        __ERC1155Holder_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, defaultAdmin);
        _grantRole(BURNER_ROLE, defaultAdmin);
        _grantRole(URI_SETTER_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, defaultAdmin);
        _grantRole(AUTHORIZED_CONTRACT_ROLE, defaultAdmin);

        _tokenIdCounter = 1; // Start from 1, 0 reserved.
    }

    /**
     * @dev Reserves a unique pair of token IDs for a new asset.
     * The asset ID will be an odd number, and the revenue token ID will be the next even number.
     * Only callable by accounts with the MINTER_ROLE (i.e., an Asset Registry).
     * @return assetId The unique ID for the new asset.
     * @return revenueTokenId The unique ID for the asset's corresponding revenue token.
     */
    function reserveNextTokenIdPair() external onlyRole(MINTER_ROLE) returns (uint256 assetId, uint256 revenueTokenId) {
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
     * @param maturityDate The date by which the revenue commitment ends.
     */
    function setRevenueTokenInfo(
        uint256 revenueTokenId,
        uint256 price,
        uint256 supply,
        uint256 maxSupply,
        uint256 maturityDate,
        uint256 revenueShareBP,
        uint256 targetYieldBP,
        bool immediateProceeds,
        bool protectionEnabled
    ) external onlyRole(MINTER_ROLE) {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }
        TokenLib.TokenInfo storage tokenInfo = _revenueTokenInfos[revenueTokenId];
        if (tokenInfo.tokenId != 0) {
            revert RevenueTokenInfoAlreadySet();
        }

        TokenLib.initializeTokenInfo(
            tokenInfo,
            revenueTokenId,
            price,
            maxSupply,
            ProtocolLib.MONTHLY_INTERVAL, // Default holding period
            maturityDate,
            revenueShareBP,
            targetYieldBP,
            immediateProceeds,
            protectionEnabled
        );
        emit RevenueTokenInfoSet(
            revenueTokenId, price, supply, maxSupply, maturityDate, immediateProceeds, protectionEnabled
        );
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
     * @dev Sets the base URI for all token types. Requires URI_SETTER_ROLE.
     * @param newuri The new URI for tokens.
     */
    function setURI(string memory newuri) external onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
    }

    /**
     * @dev Gets the next available asset ID that would be assigned.
     * @return The next available token ID.
     */
    function getNextTokenId() external view returns (uint256) {
        return _tokenIdCounter;
    }

    /**
     * @dev Get asset ID from token ID
     */
    function getAssetIdFromTokenId(uint256 tokenId) external pure returns (uint256) {
        return TokenLib.getAssetIdFromTokenId(tokenId);
    }

    /**
     * @dev Get token ID from asset ID
     */
    function getTokenIdFromAssetId(uint256 assetId) external pure returns (uint256) {
        return TokenLib.getTokenIdFromAssetId(assetId);
    }

    /**
     * @dev Gets the total supply tracked in positions for a specific token ID.
     * @param revenueTokenId The ID of the token.
     * @return The total supply tracked in positions.
     */
    function getRevenueTokenSupply(uint256 revenueTokenId) external view returns (uint256) {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
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
            revert NotRevenueToken();
        }
        return _revenueTokenInfos[revenueTokenId].tokenPrice;
    }

    /**
     * @dev Gets the maturity date for a specific revenue token ID.
     * @param revenueTokenId The ID of the revenue token.
     * @return The maturity date timestamp.
     */
    function getTokenMaturityDate(uint256 revenueTokenId) external view returns (uint256) {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }
        return _revenueTokenInfos[revenueTokenId].maturityDate;
    }

    /**
     * @dev Gets the revenue share cap (basis points) for a revenue token.
     */
    function getRevenueShareBP(uint256 revenueTokenId) external view returns (uint256) {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }
        return _revenueTokenInfos[revenueTokenId].revenueShareBP;
    }

    /**
     * @dev Gets the target yield (basis points) for buffer benchmarks.
     */
    function getTargetYieldBP(uint256 revenueTokenId) external view returns (uint256) {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }
        return _revenueTokenInfos[revenueTokenId].targetYieldBP;
    }

    function getRevenueTokenMaxSupply(uint256 revenueTokenId) external view returns (uint256) {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }
        return _revenueTokenInfos[revenueTokenId].maxSupply;
    }

    function getRevenueTokenImmediateProceedsEnabled(uint256 revenueTokenId) external view returns (bool) {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }
        return _revenueTokenInfos[revenueTokenId].immediateProceeds;
    }

    function getRevenueTokenProtectionEnabled(uint256 revenueTokenId) external view returns (bool) {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }
        return _revenueTokenInfos[revenueTokenId].protectionEnabled;
    }

    function getLockedAmount(address holder, uint256 revenueTokenId) external view returns (uint256) {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }
        return _lockedRevenueTokenAmounts[holder][revenueTokenId];
    }

    function lockForListing(address holder, uint256 revenueTokenId, uint256 amount)
        external
        onlyRole(AUTHORIZED_CONTRACT_ROLE)
    {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }
        if (amount == 0) revert InvalidLockAmount();

        uint256 balance = balanceOf(holder, revenueTokenId);
        uint256 lockedAmount = _lockedRevenueTokenAmounts[holder][revenueTokenId];
        if (balance < lockedAmount + amount) revert InsufficientUnlockedBalance();

        _lockedRevenueTokenAmounts[holder][revenueTokenId] = lockedAmount + amount;
        emit RevenueTokenLocked(revenueTokenId, holder, amount);
    }

    function unlockForListing(address holder, uint256 revenueTokenId, uint256 amount)
        external
        onlyRole(AUTHORIZED_CONTRACT_ROLE)
    {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }
        if (amount == 0) revert InvalidLockAmount();

        uint256 lockedAmount = _lockedRevenueTokenAmounts[holder][revenueTokenId];
        if (lockedAmount < amount) revert InsufficientLockedBalance();

        _lockedRevenueTokenAmounts[holder][revenueTokenId] = lockedAmount - amount;
        emit RevenueTokenUnlocked(revenueTokenId, holder, amount);
    }

    function burnCurrentEpochForPrimaryRedemption(address holder, uint256 revenueTokenId, uint256 amount)
        external
        onlyRole(BURNER_ROLE)
    {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }
        if (amount == 0) revert InvalidLockAmount();

        _currentEpochBurnActive = true;
        _currentEpochBurnHolder = holder;
        _currentEpochBurnTokenId = revenueTokenId;

        _burn(holder, revenueTokenId, amount);

        _currentEpochBurnActive = false;
        _currentEpochBurnHolder = address(0);
        _currentEpochBurnTokenId = 0;
    }

    function recordImmediateProceedsRelease(uint256 revenueTokenId, uint256 releasedAmount)
        external
        onlyRole(BURNER_ROLE)
    {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }
        if (releasedAmount == 0) return;

        TokenLib.TokenInfo storage tokenInfo = _revenueTokenInfos[revenueTokenId];
        uint256 backedPrincipal = tokenInfo.currentRedemptionBackedPrincipal;
        if (backedPrincipal == 0) return;

        tokenInfo.currentRedemptionBackedPrincipal =
            releasedAmount >= backedPrincipal ? 0 : backedPrincipal - releasedAmount;

        _rollRedemptionEpochIfExhausted(tokenInfo);

        emit PrimaryRedemptionStateUpdated(
            revenueTokenId,
            tokenInfo.currentRedemptionEpoch,
            tokenInfo.currentRedemptionEpochSupply,
            tokenInfo.currentRedemptionBackedPrincipal
        );
    }

    function recordPrimaryRedemptionPayout(uint256 revenueTokenId, uint256 payoutAmount)
        external
        onlyRole(BURNER_ROLE)
    {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }
        if (payoutAmount == 0) return;

        TokenLib.TokenInfo storage tokenInfo = _revenueTokenInfos[revenueTokenId];
        uint256 backedPrincipal = tokenInfo.currentRedemptionBackedPrincipal;
        tokenInfo.currentRedemptionBackedPrincipal =
            payoutAmount >= backedPrincipal ? 0 : backedPrincipal - payoutAmount;

        _rollRedemptionEpochIfExhausted(tokenInfo);

        emit PrimaryRedemptionStateUpdated(
            revenueTokenId,
            tokenInfo.currentRedemptionEpoch,
            tokenInfo.currentRedemptionEpochSupply,
            tokenInfo.currentRedemptionBackedPrincipal
        );
    }

    function transferLockedForListing(
        address from,
        address to,
        uint256 revenueTokenId,
        uint256 amount,
        bytes memory data
    ) external onlyRole(AUTHORIZED_CONTRACT_ROLE) {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }
        if (amount == 0) revert InvalidLockAmount();

        uint256 lockedAmount = _lockedRevenueTokenAmounts[from][revenueTokenId];
        if (lockedAmount < amount) revert InsufficientLockedBalance();
        _lockedRevenueTokenAmounts[from][revenueTokenId] = lockedAmount - amount;

        _safeTransferFrom(from, to, revenueTokenId, amount, data);
        emit RevenueTokenUnlocked(revenueTokenId, from, amount);
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
            revert NotRevenueToken();
        }
        TokenLib.TokenInfo storage info = _revenueTokenInfos[revenueTokenId];
        TokenLib.PositionQueue storage queue = info.positions[holder];

        uint256 size = queue.tail - queue.head;
        positions = new TokenLib.TokenPosition[](size);

        for (uint256 i = 0; i < size; i++) {
            positions[i] = queue.items[queue.head + i];
        }

        return positions;
    }

    function getPrimaryRedemptionEligibleBalance(address holder, uint256 revenueTokenId)
        external
        view
        returns (uint256)
    {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }

        TokenLib.TokenInfo storage info = _revenueTokenInfos[revenueTokenId];
        TokenLib.PositionQueue storage queue = info.positions[holder];
        uint256 currentEpoch = info.currentRedemptionEpoch;
        uint256 eligibleBalance = 0;

        for (uint256 i = queue.head; i < queue.tail; i++) {
            TokenLib.TokenPosition storage position = queue.items[i];
            if (position.amount > 0 && position.redemptionEpoch == currentEpoch) {
                eligibleBalance += position.amount;
            }
        }

        return eligibleBalance;
    }

    function getCurrentPrimaryRedemptionEpochSupply(uint256 revenueTokenId) external view returns (uint256) {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }
        return _revenueTokenInfos[revenueTokenId].currentRedemptionEpochSupply;
    }

    function getCurrentPrimaryRedemptionBackedPrincipal(uint256 revenueTokenId) external view returns (uint256) {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }
        return _revenueTokenInfos[revenueTokenId].currentRedemptionBackedPrincipal;
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
            revert NotRevenueToken();
        }

        // If the seller is the current owner of the corresponding Asset NFT, they are exempt from the penalty.
        uint256 assetId = TokenLib.getAssetIdFromTokenId(revenueTokenId);
        if (balanceOf(seller, assetId) > 0) {
            penaltyAmount = 0;
        } else {
            // Otherwise, calculate the penalty based on token positions
            penaltyAmount = TokenLib.calculateSalesPenalty(_revenueTokenInfos[revenueTokenId], seller, amount);
        }
    }

    /**
     * @dev Overrides _update to implement automatic position tracking for revenue tokens.
     * Called on all mints, burns, and transfers.
     */
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal override {
        // Disallow transferring/burning listed (locked) revenue tokens through normal token paths.
        // Marketplace listing fills unlock before transfer via transferLockedForListing().
        if (from != address(0)) {
            for (uint256 i = 0; i < ids.length; i++) {
                uint256 tokenId = ids[i];
                uint256 amount = values[i];
                if (!TokenLib.isRevenueToken(tokenId)) continue;

                uint256 cumulative = amount;
                for (uint256 j = 0; j < i; j++) {
                    if (ids[j] == tokenId) {
                        cumulative += values[j];
                    }
                }

                uint256 lockedAmount = _lockedRevenueTokenAmounts[from][tokenId];
                uint256 available = balanceOf(from, tokenId) - lockedAmount;
                if (cumulative > available) revert InsufficientUnlockedBalance();
            }
        }

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
     * @dev Internal function to update token positions using FIFO logic.
     * @param from The address transferring from (address(0) for mints).
     * @param to The address transferring to (address(0) for burns).
     * @param revenueTokenId The token ID being transferred.
     * @param amount The amount being transferred.
     */
    function _updateRevenueTokenPositions(uint256 revenueTokenId, address from, address to, uint256 amount) internal {
        TokenLib.TokenInfo storage tokenInfo = _revenueTokenInfos[revenueTokenId];

        if (from == address(0)) {
            // Minting - add position to receiver in the current redemption tranche.
            TokenLib.addPosition(tokenInfo, to, amount);
            tokenInfo.currentRedemptionEpochSupply += amount;
            tokenInfo.currentRedemptionBackedPrincipal += amount * tokenInfo.tokenPrice;
            emit PrimaryRedemptionStateUpdated(
                revenueTokenId,
                tokenInfo.currentRedemptionEpoch,
                tokenInfo.currentRedemptionEpochSupply,
                tokenInfo.currentRedemptionBackedPrincipal
            );
        } else if (to == address(0)) {
            if (
                _currentEpochBurnActive && from == _currentEpochBurnHolder && revenueTokenId == _currentEpochBurnTokenId
            ) {
                _burnCurrentEpochPositions(tokenInfo, from, amount);
            } else {
                _burnPositionsFifo(tokenInfo, from, amount);
            }
        } else {
            _transferPositionsFifo(tokenInfo, from, to, amount);
        }
    }

    function _appendPositionWithEpoch(TokenLib.TokenInfo storage info, address holder, uint256 amount, uint256 epoch)
        private
    {
        TokenLib.PositionQueue storage queue = info.positions[holder];
        uint256 id = queue.tail;
        queue.items[id] = TokenLib.TokenPosition({
            uid: id,
            tokenId: info.tokenId,
            amount: amount,
            acquiredAt: block.timestamp,
            soldAt: 0,
            redemptionEpoch: epoch
        });
        queue.tail++;
    }

    function _rollRedemptionEpochIfExhausted(TokenLib.TokenInfo storage info) private {
        if (info.currentRedemptionEpochSupply > 0 && info.currentRedemptionBackedPrincipal > 0) {
            return;
        }

        info.currentRedemptionEpoch++;
        info.currentRedemptionEpochSupply = 0;
        info.currentRedemptionBackedPrincipal = 0;
    }

    function _transferPositionsFifo(TokenLib.TokenInfo storage info, address from, address to, uint256 amount) private {
        TokenLib.PositionQueue storage queue = info.positions[from];
        uint256 remaining = amount;

        for (uint256 i = queue.head; i < queue.tail && remaining > 0; i++) {
            TokenLib.TokenPosition storage pos = queue.items[i];
            if (pos.amount == 0) continue;

            uint256 toMove = remaining > pos.amount ? pos.amount : remaining;
            uint256 epoch = pos.redemptionEpoch;

            pos.amount -= toMove;
            if (pos.amount == 0) {
                pos.soldAt = block.timestamp;
            }

            _appendPositionWithEpoch(info, to, toMove, epoch);
            remaining -= toMove;
        }

        if (remaining > 0) {
            revert TokenLib.InsufficientTokenBalance();
        }
    }

    function _burnPositionsFifo(TokenLib.TokenInfo storage info, address holder, uint256 amount) private {
        TokenLib.PositionQueue storage queue = info.positions[holder];
        uint256 remaining = amount;
        uint256 currentEpoch = info.currentRedemptionEpoch;
        uint256 burnedFromCurrentEpoch = 0;

        for (uint256 i = queue.head; i < queue.tail && remaining > 0; i++) {
            TokenLib.TokenPosition storage pos = queue.items[i];
            if (pos.amount == 0) continue;

            uint256 toBurn = remaining > pos.amount ? pos.amount : remaining;
            if (pos.redemptionEpoch == currentEpoch) {
                burnedFromCurrentEpoch += toBurn;
            }

            pos.amount -= toBurn;
            if (pos.amount == 0) {
                pos.soldAt = block.timestamp;
            }
            remaining -= toBurn;
        }

        if (remaining > 0) {
            revert TokenLib.InsufficientTokenBalance();
        }

        if (burnedFromCurrentEpoch > 0) {
            info.currentRedemptionEpochSupply -= burnedFromCurrentEpoch;
            emit PrimaryRedemptionStateUpdated(
                info.tokenId,
                info.currentRedemptionEpoch,
                info.currentRedemptionEpochSupply,
                info.currentRedemptionBackedPrincipal
            );
        }
    }

    function _burnCurrentEpochPositions(TokenLib.TokenInfo storage info, address holder, uint256 amount) private {
        TokenLib.PositionQueue storage queue = info.positions[holder];
        uint256 remaining = amount;
        uint256 currentEpoch = info.currentRedemptionEpoch;

        for (uint256 i = queue.head; i < queue.tail && remaining > 0; i++) {
            TokenLib.TokenPosition storage pos = queue.items[i];
            if (pos.amount == 0 || pos.redemptionEpoch != currentEpoch) continue;

            uint256 toBurn = remaining > pos.amount ? pos.amount : remaining;
            pos.amount -= toBurn;
            if (pos.amount == 0) {
                pos.soldAt = block.timestamp;
            }
            remaining -= toBurn;
        }

        if (remaining > 0) {
            revert TokenLib.InsufficientTokenBalance();
        }

        info.currentRedemptionEpochSupply -= amount;
        emit PrimaryRedemptionStateUpdated(
            info.tokenId,
            info.currentRedemptionEpoch,
            info.currentRedemptionEpochSupply,
            info.currentRedemptionBackedPrincipal
        );
    }

    /**
     * @dev Required override for UUPS upgrades.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }
}
