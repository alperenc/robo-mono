// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IAssetRegistry } from "./interfaces/IAssetRegistry.sol";
import { ITreasury } from "./interfaces/ITreasury.sol";
import { AssetLib, TokenLib } from "./Libraries.sol";
import { RoboshareTokens } from "./RoboshareTokens.sol";

error RegistryRouter__ZeroAddress();
error RegistryRouter__RegistryNotFoundForAsset(uint256 assetId);
error RegistryRouter__DirectCallNotAllowed();
error RegistryRouter__RegistryNotBoundToAsset();
error RegistryRouter__TokenNotFound(uint256 tokenId);
error RegistryRouter__TreasuryNotSet();

/**
 * @title RegistryRouter
 * @dev Central router for all asset registries in the Roboshare Protocol
 * Routes asset-specific calls to the appropriate registry based on asset ID
 * Manages the global asset ID counter via RoboshareTokens
 */
contract RegistryRouter is Initializable, AccessControlUpgradeable, UUPSUpgradeable, IAssetRegistry {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant REGISTRY_ADMIN_ROLE = keccak256("REGISTRY_ADMIN_ROLE");
    bytes32 public constant AUTHORIZED_REGISTRY_ROLE = keccak256("AUTHORIZED_REGISTRY_ROLE");

    // Core contracts
    RoboshareTokens public roboshareTokens;
    address public treasury;

    // Registry management
    mapping(uint256 => address) public assetIdToRegistry;

    // Events
    event AssetBoundToRegistry(uint256 indexed assetId, address indexed registry);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _admin, address _roboshareTokens) public initializer {
        if (_admin == address(0) || _roboshareTokens == address(0)) {
            revert RegistryRouter__ZeroAddress();
        }

        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
        _grantRole(REGISTRY_ADMIN_ROLE, _admin);

        // Set REGISTRY_ADMIN_ROLE as the admin of AUTHORIZED_REGISTRY_ROLE
        // This allows registry managers to grant/revoke the authorized registry role
        _setRoleAdmin(AUTHORIZED_REGISTRY_ROLE, REGISTRY_ADMIN_ROLE);

        roboshareTokens = RoboshareTokens(_roboshareTokens);
    }

    /**
     * @dev Set the Treasury address
     */
    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_treasury == address(0)) revert RegistryRouter__ZeroAddress();
        treasury = _treasury;
    }

    /**
     * @dev Bind an asset ID to a registry. Must be called by an authorized registry.
     */
    function bindAsset(uint256 assetId) external onlyRole(AUTHORIZED_REGISTRY_ROLE) {
        _bindAsset(assetId, msg.sender);
    }

    /**
     * @dev Internal helper to bind asset to registry
     */
    function _bindAsset(uint256 assetId, address registry) internal {
        assetIdToRegistry[assetId] = registry;
        emit AssetBoundToRegistry(assetId, registry);
    }

    /**
     * @dev Reserve a new token ID pair from RoboshareTokens.
     * Callable by authorized registries to get a new ID.
     */
    function reserveNextTokenIdPair()
        external
        onlyRole(AUTHORIZED_REGISTRY_ROLE)
        returns (uint256 assetId, uint256 revenueTokenId)
    {
        // Router must have MINTER_ROLE on RoboshareTokens
        (assetId, revenueTokenId) = roboshareTokens.reserveNextTokenIdPair();

        // Automatically bind
        _bindAsset(assetId, msg.sender);
    }

    // IAssetRegistry Implementation (Routing)

    /**
     * @dev Register asset (generic).
     * Note: Specific registries should use their own typed register functions and call bindAsset/reserveNextTokenIdPair.
     * This function is here for interface compliance but might not be the primary entry point.
     */
    function registerAsset(bytes calldata) external pure override returns (uint256) {
        // If called directly, we don't know which registry to use unless encoded in data or we have a default.
        // For now, we revert as this should be called on specific registries.
        revert RegistryRouter__DirectCallNotAllowed();
    }

    function mintRevenueTokens(uint256 assetId, uint256 supply, uint256 price)
        external
        override
        returns (uint256 tokenId)
    {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryRouter__RegistryNotFoundForAsset(assetId);
        }
        return IAssetRegistry(registry).mintRevenueTokens(assetId, supply, price);
    }

    function registerAssetAndMintTokens(bytes calldata, uint256, uint256)
        external
        pure
        override
        returns (uint256, uint256)
    {
        revert RegistryRouter__DirectCallNotAllowed();
    }

    function assetExists(uint256 assetId) external view override returns (bool) {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) return false;
        return IAssetRegistry(registry).assetExists(assetId);
    }

    function getAssetInfo(uint256 assetId) external view override returns (AssetLib.AssetInfo memory) {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryRouter__RegistryNotFoundForAsset(assetId);
        }
        return IAssetRegistry(registry).getAssetInfo(assetId);
    }

    function getAssetStatus(uint256 assetId) external view override returns (AssetLib.AssetStatus) {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryRouter__RegistryNotFoundForAsset(assetId);
        }
        return IAssetRegistry(registry).getAssetStatus(assetId);
    }

    function setAssetStatus(uint256 assetId, AssetLib.AssetStatus status) external override {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryRouter__RegistryNotFoundForAsset(assetId);
        }
        // Router doesn't enforce access control here, the specific registry should.
        // However, usually only Treasury calls this.
        IAssetRegistry(registry).setAssetStatus(assetId, status);
    }

    function burnRevenueTokens(uint256 assetId, uint256 amount) external override {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryRouter__RegistryNotFoundForAsset(assetId);
        }
        IAssetRegistry(registry).burnRevenueTokens(assetId, amount);
    }

    function retireAsset(uint256 assetId) external override {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryRouter__RegistryNotFoundForAsset(assetId);
        }
        IAssetRegistry(registry).retireAsset(assetId);
    }

    function retireAssetAndBurnTokens(uint256 assetId) external override {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryRouter__RegistryNotFoundForAsset(assetId);
        }
        IAssetRegistry(registry).retireAssetAndBurnTokens(assetId);
    }

    /**
     * @dev Forward retirement signal from Registry to Treasury.
     * Callable only by authorized registries.
     */
    function releaseCollateralFor(address partner, uint256 assetId)
        external
        onlyRole(AUTHORIZED_REGISTRY_ROLE)
        returns (uint256 releasedCollateral)
    {
        // Verify this registry owns the asset
        if (assetIdToRegistry[assetId] != msg.sender) {
            revert RegistryRouter__RegistryNotBoundToAsset();
        }

        // Call Treasury
        if (treasury == address(0)) {
            revert RegistryRouter__TreasuryNotSet();
        }

        return ITreasury(treasury).releaseCollateralFor(partner, assetId);
    }

    /**
     * @dev Forward collateral lock request from Registry to Treasury.
     * Callable only by authorized registries.
     */
    function lockCollateralFor(address partner, uint256 assetId, uint256 amount, uint256 supply)
        external
        onlyRole(AUTHORIZED_REGISTRY_ROLE)
    {
        // Verify this registry owns the asset
        if (assetIdToRegistry[assetId] != msg.sender) {
            revert RegistryRouter__RegistryNotBoundToAsset();
        }

        // Call Treasury
        if (treasury == address(0)) {
            revert RegistryRouter__TreasuryNotSet();
        }

        ITreasury(treasury).lockCollateralFor(partner, assetId, amount, supply);
    }

    function getAssetIdFromTokenId(uint256 tokenId) external pure override returns (uint256) {
        // Standard logic: revenue token ID - 1 = asset ID
        if (!TokenLib.isRevenueToken(tokenId)) {
            revert RegistryRouter__TokenNotFound(tokenId);
        }
        return tokenId - 1;
    }

    function getTokenIdFromAssetId(uint256 assetId) external pure override returns (uint256) {
        // Standard logic: asset ID + 1 = revenue token ID
        if (TokenLib.isRevenueToken(assetId)) {
            revert AssetNotFound(assetId);
        }
        return assetId + 1;
    }

    function isAuthorizedForAsset(address account, uint256 assetId) external view override returns (bool) {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryRouter__RegistryNotFoundForAsset(assetId);
        }
        return IAssetRegistry(registry).isAuthorizedForAsset(account, assetId);
    }

    function getRegistryForAsset(uint256 assetId) external view override returns (address) {
        return assetIdToRegistry[assetId];
    }

    function getRegistryType() external pure override returns (string memory) {
        return "RegistryRouter";
    }

    function getRegistryVersion() external pure override returns (uint256) {
        return 1;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }
}
