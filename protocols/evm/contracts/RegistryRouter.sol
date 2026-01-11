// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IAssetRegistry } from "./interfaces/IAssetRegistry.sol";
import { ITreasury } from "./interfaces/ITreasury.sol";
import { IMarketplace } from "./interfaces/IMarketplace.sol";
import { AssetLib, TokenLib } from "./Libraries.sol";
import { RoboshareTokens } from "./RoboshareTokens.sol";

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
    address public marketplace;

    // Registry management
    mapping(uint256 => address) public assetIdToRegistry;

    // Errors
    error ZeroAddress();
    error DirectCallNotAllowed();
    error RegistryNotFoundForAsset(uint256 assetId);
    error RegistryNotBoundToAsset();
    error TreasuryNotSet();
    error TokenNotFound(uint256 tokenId);

    // Events
    event AssetBoundToRegistry(uint256 indexed assetId, address indexed registry);
    event RoboshareTokensUpdated(address indexed oldAddress, address indexed newAddress);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _admin, address _roboshareTokens) public initializer {
        if (_admin == address(0) || _roboshareTokens == address(0)) {
            revert ZeroAddress();
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
        if (_treasury == address(0)) revert ZeroAddress();
        treasury = _treasury;
    }

    /**
     * @dev Set the Marketplace address
     */
    function setMarketplace(address _marketplace) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_marketplace == address(0)) revert ZeroAddress();
        marketplace = _marketplace;
    }

    /**
     * @dev Create a listing on behalf of a seller. Can only be called by authorized registries.
     * Routes to marketplace.createListingFor for registries implementing registerAssetMintAndList.
     * @param seller The address of the seller (partner)
     * @param tokenId The revenue share token ID
     * @param amount Number of tokens to list
     * @param pricePerToken Price per token in USDC
     * @param duration Listing duration in seconds
     * @param buyerPaysFee If true, buyer pays protocol fee
     */
    function createListingFor(
        address seller,
        uint256 tokenId,
        uint256 amount,
        uint256 pricePerToken,
        uint256 duration,
        bool buyerPaysFee
    ) external onlyRole(AUTHORIZED_REGISTRY_ROLE) returns (uint256 listingId) {
        if (marketplace == address(0)) revert ZeroAddress();
        return
            IMarketplace(marketplace).createListingFor(seller, tokenId, amount, pricePerToken, duration, buyerPaysFee);
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
        revert DirectCallNotAllowed();
    }

    function mintRevenueTokens(uint256 assetId, uint256 supply, uint256 price, uint256 maturityDate)
        external
        override
        returns (uint256 tokenId)
    {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFoundForAsset(assetId);
        }
        return IAssetRegistry(registry).mintRevenueTokens(assetId, supply, price, maturityDate);
    }

    function registerAssetAndMintTokens(bytes calldata, uint256, uint256, uint256)
        external
        pure
        override
        returns (uint256, uint256)
    {
        revert DirectCallNotAllowed();
    }

    function registerAssetMintAndList(bytes calldata, uint256, uint256, uint256, uint256, bool)
        external
        pure
        override
        returns (uint256, uint256, uint256)
    {
        revert DirectCallNotAllowed();
    }

    function assetExists(uint256 assetId) external view override returns (bool) {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) return false;
        return IAssetRegistry(registry).assetExists(assetId);
    }

    function getAssetInfo(uint256 assetId) external view override returns (AssetLib.AssetInfo memory) {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFoundForAsset(assetId);
        }
        return IAssetRegistry(registry).getAssetInfo(assetId);
    }

    function getAssetStatus(uint256 assetId) external view override returns (AssetLib.AssetStatus) {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFoundForAsset(assetId);
        }
        return IAssetRegistry(registry).getAssetStatus(assetId);
    }

    function setAssetStatus(uint256 assetId, AssetLib.AssetStatus status) external override {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFoundForAsset(assetId);
        }
        // Router doesn't enforce access control here, the specific registry should.
        // However, usually only Treasury calls this.
        IAssetRegistry(registry).setAssetStatus(assetId, status);
    }

    /**
     * @dev Forward settlement initialization from Registry to Treasury.
     * Callable only by authorized registries.
     */
    function initiateSettlement(address partner, uint256 assetId, uint256 topUpAmount)
        external
        onlyRole(AUTHORIZED_REGISTRY_ROLE)
        returns (uint256 settlementAmount, uint256 settlementPerToken)
    {
        // Verify this registry owns the asset
        if (assetIdToRegistry[assetId] != msg.sender) {
            revert RegistryNotBoundToAsset();
        }

        if (treasury == address(0)) {
            revert TreasuryNotSet();
        }

        return ITreasury(treasury).initiateSettlement(partner, assetId, topUpAmount);
    }

    /**
     * @dev Forward liquidation execution from Registry to Treasury.
     * Callable only by authorized registries.
     */
    function executeLiquidation(uint256 assetId)
        external
        onlyRole(AUTHORIZED_REGISTRY_ROLE)
        returns (uint256 liquidationAmount, uint256 settlementPerToken)
    {
        // Verify this registry owns the asset
        if (assetIdToRegistry[assetId] != msg.sender) {
            revert RegistryNotBoundToAsset();
        }

        if (treasury == address(0)) {
            revert TreasuryNotSet();
        }

        return ITreasury(treasury).executeLiquidation(assetId);
    }

    /**
     * @dev Check asset solvency via Treasury.
     */
    /**
     * @dev Forward settlement claim processing from Registry to Treasury.
     * Callable only by authorized registries.
     */
    function processSettlementClaim(address recipient, uint256 assetId, uint256 amount)
        external
        onlyRole(AUTHORIZED_REGISTRY_ROLE)
        returns (uint256 claimedAmount)
    {
        // Verify this registry owns the asset
        if (assetIdToRegistry[assetId] != msg.sender) {
            revert RegistryNotBoundToAsset();
        }

        if (treasury == address(0)) {
            revert TreasuryNotSet();
        }

        return ITreasury(treasury).processSettlementClaim(recipient, assetId, amount);
    }

    /**
     * @dev Forward earnings snapshot (and optionally claim) request from Registry to Treasury.
     * Called before burning tokens to preserve unclaimed earnings.
     * Callable only by authorized registries.
     */
    function snapshotAndClaimEarnings(uint256 assetId, address holder, bool autoClaim)
        external
        onlyRole(AUTHORIZED_REGISTRY_ROLE)
        returns (uint256 snapshotAmount)
    {
        // Verify this registry owns the asset
        if (assetIdToRegistry[assetId] != msg.sender) {
            revert RegistryNotBoundToAsset();
        }

        if (treasury == address(0)) {
            revert TreasuryNotSet();
        }

        return ITreasury(treasury).snapshotAndClaimEarnings(assetId, holder, autoClaim);
    }

    function isAssetSolvent(uint256 assetId) external view returns (bool) {
        if (treasury == address(0)) {
            revert TreasuryNotSet();
        }
        return ITreasury(treasury).isAssetSolvent(assetId);
    }

    function settleAsset(uint256 assetId, uint256 topUpAmount) external override {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFoundForAsset(assetId);
        }
        IAssetRegistry(registry).settleAsset(assetId, topUpAmount);
    }

    function liquidateAsset(uint256 assetId) external override {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFoundForAsset(assetId);
        }
        IAssetRegistry(registry).liquidateAsset(assetId);
    }

    function claimSettlement(uint256 assetId, bool autoClaimEarnings)
        external
        override
        returns (uint256 claimedAmount, uint256 earningsClaimed)
    {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFoundForAsset(assetId);
        }
        return IAssetRegistry(registry).claimSettlement(assetId, autoClaimEarnings);
    }

    function burnRevenueTokens(uint256 assetId, uint256 amount) external override {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFoundForAsset(assetId);
        }
        IAssetRegistry(registry).burnRevenueTokens(assetId, amount);
    }

    function retireAsset(uint256 assetId) external override {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFoundForAsset(assetId);
        }
        IAssetRegistry(registry).retireAsset(assetId);
    }

    function retireAssetAndBurnTokens(uint256 assetId) external override {
        address registry = assetIdToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFoundForAsset(assetId);
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
            revert RegistryNotBoundToAsset();
        }

        // Call Treasury
        if (treasury == address(0)) {
            revert TreasuryNotSet();
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
            revert RegistryNotBoundToAsset();
        }

        // Call Treasury
        if (treasury == address(0)) {
            revert TreasuryNotSet();
        }

        ITreasury(treasury).lockCollateralFor(partner, assetId, amount, supply);
    }

    function getAssetIdFromTokenId(uint256 tokenId) external pure override returns (uint256) {
        // Standard logic: revenue token ID - 1 = asset ID
        if (!TokenLib.isRevenueToken(tokenId)) {
            revert TokenNotFound(tokenId);
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
            revert RegistryNotFoundForAsset(assetId);
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

    /**
     * @dev Update RoboshareTokens contract reference
     * @param _roboshareTokens New RoboshareTokens contract address
     */
    function updateRoboshareTokens(address _roboshareTokens) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_roboshareTokens == address(0)) {
            revert ZeroAddress();
        }
        address oldAddress = address(roboshareTokens);
        roboshareTokens = RoboshareTokens(_roboshareTokens);
        emit RoboshareTokensUpdated(oldAddress, _roboshareTokens);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }
}
