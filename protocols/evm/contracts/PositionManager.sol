// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
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
}
