// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { TokenLib } from "./Libraries.sol";
import { IPositionManager } from "./interfaces/IPositionManager.sol";

/**
 * @title PositionManager
 * @notice Upgradeable boundary contract for position, lock, redemption-epoch, and settlement state.
 * @dev This scaffold intentionally keeps redemption and settlement responsibilities in the same manager.
 */
contract PositionManager is Initializable, AccessControlUpgradeable, UUPSUpgradeable, IPositionManager {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant POSITION_ADMIN_ROLE = keccak256("POSITION_ADMIN_ROLE");
    bytes32 public constant AUTHORIZED_ROUTER_ROLE = keccak256("AUTHORIZED_ROUTER_ROLE");
    bytes32 public constant AUTHORIZED_MARKETPLACE_ROLE = keccak256("AUTHORIZED_MARKETPLACE_ROLE");
    bytes32 public constant AUTHORIZED_TREASURY_ROLE = keccak256("AUTHORIZED_TREASURY_ROLE");

    address public registryRouter;
    address public roboshareTokens;
    address public partnerManager;
    address public marketplace;
    address public treasury;
    address public usdc;

    mapping(uint256 => TokenLib.TokenInfo) private _revenueTokenInfos;
    mapping(address => mapping(uint256 => uint256)) private _lockedAmounts;
    mapping(uint256 => uint256) private _listingSalePenalties;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address admin,
        address _registryRouter,
        address _roboshareTokens,
        address _partnerManager,
        address _marketplace,
        address _treasury,
        address _usdc
    ) external initializer {
        if (
            admin == address(0) || _registryRouter == address(0) || _roboshareTokens == address(0)
                || _partnerManager == address(0) || _marketplace == address(0) || _treasury == address(0)
                || _usdc == address(0)
        ) {
            revert ZeroAddress();
        }

        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
        _grantRole(POSITION_ADMIN_ROLE, admin);
        _setRoleAdmin(AUTHORIZED_ROUTER_ROLE, POSITION_ADMIN_ROLE);
        _setRoleAdmin(AUTHORIZED_MARKETPLACE_ROLE, POSITION_ADMIN_ROLE);
        _setRoleAdmin(AUTHORIZED_TREASURY_ROLE, POSITION_ADMIN_ROLE);
        _grantRole(AUTHORIZED_ROUTER_ROLE, _registryRouter);
        _grantRole(AUTHORIZED_MARKETPLACE_ROLE, _marketplace);
        _grantRole(AUTHORIZED_TREASURY_ROLE, _treasury);

        registryRouter = _registryRouter;
        roboshareTokens = _roboshareTokens;
        partnerManager = _partnerManager;
        marketplace = _marketplace;
        treasury = _treasury;
        usdc = _usdc;

        emit PositionManagerInitialized(
            admin, _registryRouter, _roboshareTokens, _partnerManager, _marketplace, _treasury, _usdc
        );
    }

    function updateRegistryRouter(address newRegistryRouter) external onlyRole(POSITION_ADMIN_ROLE) {
        if (newRegistryRouter == address(0)) {
            revert ZeroAddress();
        }

        address oldRegistryRouter = registryRouter;
        if (oldRegistryRouter != address(0)) {
            _revokeRole(AUTHORIZED_ROUTER_ROLE, oldRegistryRouter);
        }

        registryRouter = newRegistryRouter;
        _grantRole(AUTHORIZED_ROUTER_ROLE, newRegistryRouter);
        emit RegistryRouterUpdated(oldRegistryRouter, newRegistryRouter);
    }

    function updateRoboshareTokens(address newRoboshareTokens) external onlyRole(POSITION_ADMIN_ROLE) {
        if (newRoboshareTokens == address(0)) {
            revert ZeroAddress();
        }

        address oldRoboshareTokens = roboshareTokens;
        roboshareTokens = newRoboshareTokens;
        emit RoboshareTokensUpdated(oldRoboshareTokens, newRoboshareTokens);
    }

    function updatePartnerManager(address newPartnerManager) external onlyRole(POSITION_ADMIN_ROLE) {
        if (newPartnerManager == address(0)) {
            revert ZeroAddress();
        }

        address oldPartnerManager = partnerManager;
        partnerManager = newPartnerManager;
        emit PartnerManagerUpdated(oldPartnerManager, newPartnerManager);
    }

    function updateMarketplace(address newMarketplace) external onlyRole(POSITION_ADMIN_ROLE) {
        if (newMarketplace == address(0)) {
            revert ZeroAddress();
        }

        address oldMarketplace = marketplace;
        if (oldMarketplace != address(0)) {
            _revokeRole(AUTHORIZED_MARKETPLACE_ROLE, oldMarketplace);
        }

        marketplace = newMarketplace;
        _grantRole(AUTHORIZED_MARKETPLACE_ROLE, newMarketplace);
        emit MarketplaceUpdated(oldMarketplace, newMarketplace);
    }

    function updateTreasury(address newTreasury) external onlyRole(POSITION_ADMIN_ROLE) {
        if (newTreasury == address(0)) {
            revert ZeroAddress();
        }

        address oldTreasury = treasury;
        if (oldTreasury != address(0)) {
            _revokeRole(AUTHORIZED_TREASURY_ROLE, oldTreasury);
        }

        treasury = newTreasury;
        _grantRole(AUTHORIZED_TREASURY_ROLE, newTreasury);
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    function updateUsdc(address newUsdc) external onlyRole(POSITION_ADMIN_ROLE) {
        if (newUsdc == address(0)) {
            revert ZeroAddress();
        }

        address oldUsdc = usdc;
        usdc = newUsdc;
        emit UsdcUpdated(oldUsdc, newUsdc);
    }

    function recordPositionMutation(PositionMutation calldata mutation) external onlyRole(AUTHORIZED_MARKETPLACE_ROLE) {
        if (!TokenLib.isRevenueToken(mutation.tokenId)) {
            revert NotRevenueToken();
        }

        TokenLib.TokenInfo storage tokenInfo = _revenueTokenInfos[mutation.tokenId];
        if (tokenInfo.tokenId == 0) {
            tokenInfo.tokenId = mutation.tokenId;
        }

        if (mutation.mutationType == PositionMutationType.Mint) {
            tokenInfo.tokenSupply += mutation.amount;
            TokenLib.addPosition(tokenInfo, mutation.account, mutation.amount);
        } else if (mutation.mutationType == PositionMutationType.Burn) {
            tokenInfo.tokenSupply -= mutation.amount;
            TokenLib.removePosition(tokenInfo, mutation.account, mutation.amount);
        } else {
            revert UnsupportedPositionMutation(mutation.mutationType);
        }

        emit PositionMutated(
            mutation.assetId,
            mutation.tokenId,
            mutation.account,
            mutation.amount,
            mutation.auxValue,
            mutation.mutationType,
            mutation.reason
        );
    }

    function getUserPositions(uint256 revenueTokenId, address holder)
        external
        view
        returns (TokenLib.TokenPosition[] memory positions)
    {
        _requireRevenueToken(revenueTokenId);

        TokenLib.PositionQueue storage queue = _revenueTokenInfos[revenueTokenId].positions[holder];
        uint256 size = queue.tail - queue.head;
        positions = new TokenLib.TokenPosition[](size);

        for (uint256 i = 0; i < size; i++) {
            positions[i] = queue.items[queue.head + i];
        }
    }

    function getLockedAmount(address holder, uint256 revenueTokenId) external view returns (uint256) {
        _requireRevenueToken(revenueTokenId);
        return _lockedAmounts[holder][revenueTokenId];
    }

    function getAvailableAmount(address holder, uint256 revenueTokenId, uint256 totalBalance)
        external
        view
        returns (uint256)
    {
        _requireRevenueToken(revenueTokenId);

        uint256 lockedAmount = _lockedAmounts[holder][revenueTokenId];
        if (lockedAmount >= totalBalance) {
            return 0;
        }
        return totalBalance - lockedAmount;
    }

    function lockForListing(address holder, uint256 revenueTokenId, uint256 amount)
        external
        onlyRole(AUTHORIZED_MARKETPLACE_ROLE)
    {
        _requireRevenueToken(revenueTokenId);
        if (amount == 0) revert InvalidAmount();

        uint256 lockedAmount = _lockedAmounts[holder][revenueTokenId];
        uint256 totalBalance = IERC1155(roboshareTokens).balanceOf(holder, revenueTokenId);
        if (totalBalance < lockedAmount + amount) revert InsufficientUnlockedBalance();

        _lockedAmounts[holder][revenueTokenId] = lockedAmount + amount;
        emit ListingLocked(holder, revenueTokenId, amount);
    }

    function unlockForListing(address holder, uint256 revenueTokenId, uint256 amount)
        external
        onlyRole(AUTHORIZED_MARKETPLACE_ROLE)
    {
        _requireRevenueToken(revenueTokenId);
        if (amount == 0) revert InvalidAmount();

        uint256 lockedAmount = _lockedAmounts[holder][revenueTokenId];
        if (lockedAmount < amount) revert InsufficientLockedBalance();

        _lockedAmounts[holder][revenueTokenId] = lockedAmount - amount;
        emit ListingUnlocked(holder, revenueTokenId, amount);
    }

    function settleLockedTransfer(address from, address to, uint256 revenueTokenId, uint256 amount)
        external
        onlyRole(AUTHORIZED_MARKETPLACE_ROLE)
    {
        _requireRevenueToken(revenueTokenId);
        if (amount == 0) revert InvalidAmount();

        uint256 lockedAmount = _lockedAmounts[from][revenueTokenId];
        if (lockedAmount < amount) revert InsufficientLockedBalance();

        _lockedAmounts[from][revenueTokenId] = lockedAmount - amount;
        emit ListingUnlocked(from, revenueTokenId, amount);
        emit LockedTransferSettled(from, to, revenueTokenId, amount);
    }

    function bookSalePenalty(uint256 listingId, address seller, uint256 revenueTokenId, uint256 amount)
        external
        onlyRole(AUTHORIZED_MARKETPLACE_ROLE)
    {
        _requireRevenueToken(revenueTokenId);

        _listingSalePenalties[listingId] = amount;
        emit SalePenaltyBooked(listingId, seller, revenueTokenId, amount);
    }

    function clearSalePenalty(uint256 listingId) external onlyRole(AUTHORIZED_MARKETPLACE_ROLE) {
        delete _listingSalePenalties[listingId];
    }

    function getSalePenalty(uint256 listingId) external view returns (uint256) {
        return _listingSalePenalties[listingId];
    }

    function recordPositionLock(uint256 assetId, uint256 tokenId, address account, uint256 lockUntil, bytes32 reason)
        external
        onlyRole(AUTHORIZED_ROUTER_ROLE)
    {
        emit PositionLockUpdated(assetId, tokenId, account, lockUntil, reason);
    }

    function recordRedemptionEpoch(uint256 tokenId, uint256 epochId, uint256 redeemableSupply, bytes32 reason)
        external
        onlyRole(AUTHORIZED_TREASURY_ROLE)
    {
        emit RedemptionEpochUpdated(tokenId, epochId, redeemableSupply, reason);
    }

    function recordSettlement(
        uint256 assetId,
        uint256 epochId,
        uint256 settlementAmount,
        uint256 settlementPerToken,
        bytes32 reason
    ) external onlyRole(AUTHORIZED_TREASURY_ROLE) {
        emit SettlementConfigured(assetId, epochId, settlementAmount, settlementPerToken, reason);
    }

    function recordSettlementClaim(
        uint256 assetId,
        uint256 tokenId,
        address account,
        uint256 burnAmount,
        uint256 payout,
        bytes32 reason
    ) external onlyRole(AUTHORIZED_TREASURY_ROLE) {
        emit SettlementClaimRecorded(assetId, tokenId, account, burnAmount, payout, reason);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    function _requireRevenueToken(uint256 revenueTokenId) internal pure {
        if (!TokenLib.isRevenueToken(revenueTokenId)) {
            revert NotRevenueToken();
        }
    }
}
