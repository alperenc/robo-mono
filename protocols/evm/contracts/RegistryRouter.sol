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
import { PartnerManager } from "./PartnerManager.sol";

/**
 * @title RegistryRouter
 * @dev Central router for all asset registries in the Roboshare Protocol
 * Routes asset-specific calls to the appropriate registry based on asset ID
 * Manages the global asset ID counter via RoboshareTokens
 * Also routes Treasury and Marketplace operations on behalf of asset registries
 */
contract RegistryRouter is Initializable, AccessControlUpgradeable, UUPSUpgradeable, IAssetRegistry {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant REGISTRY_ADMIN_ROLE = keccak256("REGISTRY_ADMIN_ROLE");
    bytes32 public constant AUTHORIZED_REGISTRY_ROLE = keccak256("AUTHORIZED_REGISTRY_ROLE");

    // Core contracts
    RoboshareTokens public roboshareTokens;
    PartnerManager public partnerManager;
    address public treasury;
    address public marketplace;

    // Registry management
    mapping(uint256 => address) public idToRegistry;

    // Errors
    error ZeroAddress();
    error DirectCallNotAllowed();
    error RegistryNotFound(uint256 id);
    error RegistryNotBoundToAsset();
    error TreasuryNotSet();
    error MarketplaceNotSet();
    error NotTreasury();
    error NotMarketplace();

    // Events
    event IdBoundToRegistry(uint256 indexed id, address indexed registry);
    event RoboshareTokensUpdated(address indexed oldAddress, address indexed newAddress);
    event PartnerManagerUpdated(address indexed oldAddress, address indexed newAddress);
    event RevenueTokensMinted(
        uint256 indexed assetId,
        uint256 indexed revenueTokenId,
        address indexed partner,
        uint256 assetValue,
        uint256 supply
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _admin, address _roboshareTokens, address _partnerManager) public initializer {
        if (_admin == address(0) || _roboshareTokens == address(0) || _partnerManager == address(0)) {
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
        partnerManager = PartnerManager(_partnerManager);
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

    function _onlyAuthorizedPartner() internal view {
        if (!partnerManager.isAuthorizedPartner(msg.sender)) {
            revert PartnerManager.UnauthorizedPartner();
        }
    }

    modifier onlyAuthorizedPartner() {
        _onlyAuthorizedPartner();
        _;
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
        if (marketplace == address(0)) revert MarketplaceNotSet();
        return
            IMarketplace(marketplace).createListingFor(seller, tokenId, amount, pricePerToken, duration, buyerPaysFee);
    }

    /**
     * @dev Internal helper to bind ID to registry
     */
    function _bindId(uint256 id, address registry) internal {
        idToRegistry[id] = registry;
        emit IdBoundToRegistry(id, registry);
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

        // Automatically bind both IDs to the caller registry
        _bindId(assetId, msg.sender);
        _bindId(revenueTokenId, msg.sender);
    }

    // IAssetRegistry Implementation (Routing)

    /**
     * @dev Register asset (generic).
     * Note: Specific registries should use their own typed register functions and call bindAsset/reserveNextTokenIdPair.
     * This function is here for interface compliance but might not be the primary entry point.
     */
    function registerAsset(bytes calldata, uint256) external pure override returns (uint256) {
        // If called directly, we don't know which registry to use unless encoded in data or we have a default.
        // For now, we revert as this should be called on specific registries.
        revert DirectCallNotAllowed();
    }

    function mintRevenueTokensAndList(
        uint256 assetId,
        uint256 tokenPrice,
        uint256 maturityDate,
        uint256 revenueShareBP,
        uint256 targetYieldBP,
        uint256 listingDuration,
        bool buyerPaysFee
    ) external override onlyAuthorizedPartner returns (uint256 tokenId, uint256 supply, uint256 listingId) {
        return _mintRevenueTokensAndListFor(
            msg.sender, assetId, tokenPrice, maturityDate, revenueShareBP, targetYieldBP, listingDuration, buyerPaysFee
        );
    }

    /**
     * @dev Registry-only wrapper to mint revenue tokens and list on behalf of a partner.
     */
    function mintRevenueTokensAndListFor(
        address partner,
        uint256 assetId,
        uint256 tokenPrice,
        uint256 maturityDate,
        uint256 revenueShareBP,
        uint256 targetYieldBP,
        uint256 listingDuration,
        bool buyerPaysFee
    ) external onlyRole(AUTHORIZED_REGISTRY_ROLE) returns (uint256 tokenId, uint256 supply, uint256 listingId) {
        return _mintRevenueTokensAndListFor(
            partner, assetId, tokenPrice, maturityDate, revenueShareBP, targetYieldBP, listingDuration, buyerPaysFee
        );
    }

    /**
     * @dev Shared mint + list flow used by direct callers and registry wrappers.
     */
    function _mintRevenueTokensAndListFor(
        address partner,
        uint256 assetId,
        uint256 tokenPrice,
        uint256 maturityDate,
        uint256 revenueShareBP,
        uint256 targetYieldBP,
        uint256 listingDuration,
        bool buyerPaysFee
    ) internal returns (uint256 tokenId, uint256 supply, uint256 listingId) {
        address registry = idToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFound(assetId);
        }

        (tokenId, supply) = IAssetRegistry(registry).previewMintRevenueTokens(assetId, partner, tokenPrice);

        roboshareTokens.setRevenueTokenInfo(tokenId, tokenPrice, supply, maturityDate, revenueShareBP, targetYieldBP);
        _mintRevenueTokensToEscrow(registry, tokenId, supply);
        emit RevenueTokensMinted(assetId, tokenId, partner, supply * tokenPrice, supply);

        IAssetRegistry(registry).setAssetStatus(assetId, AssetLib.AssetStatus.Active);

        listingId = IMarketplace(marketplace)
            .createListingFor(partner, tokenId, supply, tokenPrice, listingDuration, buyerPaysFee);
    }

    function previewMintRevenueTokens(uint256 assetId, address partner, uint256 tokenPrice)
        external
        view
        override
        returns (uint256 tokenId, uint256 supply)
    {
        address registry = idToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFound(assetId);
        }
        return IAssetRegistry(registry).previewMintRevenueTokens(assetId, partner, tokenPrice);
    }

    function registerAssetMintAndList(bytes calldata, uint256, uint256, uint256, uint256, uint256, uint256, bool)
        external
        pure
        override
        returns (uint256, uint256, uint256, uint256)
    {
        revert DirectCallNotAllowed();
    }

    function assetExists(uint256 assetId) external view override returns (bool) {
        address registry = idToRegistry[assetId];
        if (registry == address(0)) return false;
        return IAssetRegistry(registry).assetExists(assetId);
    }

    function getAssetInfo(uint256 assetId) external view override returns (AssetLib.AssetInfo memory) {
        address registry = idToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFound(assetId);
        }
        return IAssetRegistry(registry).getAssetInfo(assetId);
    }

    function getAssetStatus(uint256 assetId) external view override returns (AssetLib.AssetStatus) {
        address registry = idToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFound(assetId);
        }
        return IAssetRegistry(registry).getAssetStatus(assetId);
    }

    function setAssetStatus(uint256 assetId, AssetLib.AssetStatus status) external override {
        if (msg.sender != treasury) {
            revert NotTreasury();
        }
        address registry = idToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFound(assetId);
        }
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
        if (idToRegistry[assetId] != msg.sender) {
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
        if (idToRegistry[assetId] != msg.sender) {
            revert RegistryNotBoundToAsset();
        }

        if (treasury == address(0)) {
            revert TreasuryNotSet();
        }

        return ITreasury(treasury).executeLiquidation(assetId);
    }

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
        if (idToRegistry[assetId] != msg.sender) {
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
        if (idToRegistry[assetId] != msg.sender) {
            revert RegistryNotBoundToAsset();
        }

        if (treasury == address(0)) {
            revert TreasuryNotSet();
        }

        return ITreasury(treasury).snapshotAndClaimEarnings(assetId, holder, autoClaim);
    }

    /**
     * @dev Check asset solvency via Treasury.
     */
    function isAssetSolvent(uint256 assetId) external view returns (bool) {
        if (treasury == address(0)) {
            revert TreasuryNotSet();
        }
        return ITreasury(treasury).isAssetSolvent(assetId);
    }

    function settleAsset(uint256 assetId, uint256 topUpAmount) external override {
        address registry = idToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFound(assetId);
        }
        IAssetRegistry(registry).settleAsset(assetId, topUpAmount);
    }

    function liquidateAsset(uint256 assetId) external override {
        address registry = idToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFound(assetId);
        }
        IAssetRegistry(registry).liquidateAsset(assetId);
    }

    function claimSettlement(uint256 assetId, bool autoClaimEarnings)
        external
        override
        returns (uint256 claimedAmount, uint256 earningsClaimed)
    {
        address registry = idToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFound(assetId);
        }
        return IAssetRegistry(registry).claimSettlement(assetId, autoClaimEarnings);
    }

    function burnRevenueTokens(uint256 assetId, uint256 amount) external override {
        address registry = idToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFound(assetId);
        }
        IAssetRegistry(registry).burnRevenueTokens(assetId, amount);
    }

    function retireAsset(uint256 assetId) external override {
        address registry = idToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFound(assetId);
        }
        IAssetRegistry(registry).retireAsset(assetId);
    }

    function retireAssetAndBurnTokens(uint256 assetId) external override {
        address registry = idToRegistry[assetId];
        if (registry == address(0)) {
            revert RegistryNotFound(assetId);
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
        if (idToRegistry[assetId] != msg.sender) {
            revert RegistryNotBoundToAsset();
        }

        // Call Treasury
        if (treasury == address(0)) {
            revert TreasuryNotSet();
        }

        return ITreasury(treasury).releaseCollateralFor(partner, assetId);
    }

    /**
     * @dev Clear unsold escrow for a tokenId (called by registry at settlement).
     */
    function clearTokenEscrow(uint256 assetId) external onlyRole(AUTHORIZED_REGISTRY_ROLE) returns (uint256 amount) {
        // Verify this registry owns the asset
        if (idToRegistry[assetId] != msg.sender) {
            revert RegistryNotBoundToAsset();
        }
        if (marketplace == address(0)) {
            revert MarketplaceNotSet();
        }

        uint256 tokenId = TokenLib.getTokenIdFromAssetId(assetId);
        amount = IMarketplace(marketplace).clearTokenEscrow(tokenId);
    }

    function creditTokenEscrow(uint256 assetId, uint256 amount) external onlyRole(AUTHORIZED_REGISTRY_ROLE) {
        if (idToRegistry[assetId] != msg.sender) {
            revert RegistryNotBoundToAsset();
        }
        if (marketplace == address(0)) {
            revert MarketplaceNotSet();
        }

        uint256 tokenId = TokenLib.getTokenIdFromAssetId(assetId);
        IMarketplace(marketplace).creditTokenEscrow(tokenId, amount);
    }

    /**
     * @dev Record sold supply for primary listings (called by Marketplace after a listing ends).
     * Allows multiple listings per asset owner; sold supply accumulates.
     */
    function recordSoldSupply(uint256 revenueTokenId, uint256 soldAmount) external {
        if (msg.sender != marketplace) {
            revert NotMarketplace();
        }
        if (idToRegistry[revenueTokenId] == address(0)) {
            revert RegistryNotFound(revenueTokenId);
        }
        if (soldAmount == 0) {
            return;
        }
        roboshareTokens.increaseSoldSupply(revenueTokenId, soldAmount);
    }

    function _mintRevenueTokensToEscrow(address registry, uint256 revenueTokenId, uint256 amount) internal {
        if (idToRegistry[revenueTokenId] != registry) {
            revert RegistryNotBoundToAsset();
        }
        if (marketplace == address(0)) {
            revert MarketplaceNotSet();
        }
        roboshareTokens.mint(marketplace, revenueTokenId, amount, "");
        IMarketplace(marketplace).creditTokenEscrow(revenueTokenId, amount);
    }

    function burnRevenueTokensFromEscrow(uint256 revenueTokenId)
        external
        onlyRole(AUTHORIZED_REGISTRY_ROLE)
        returns (uint256 amount)
    {
        if (idToRegistry[revenueTokenId] != msg.sender) {
            revert RegistryNotBoundToAsset();
        }
        if (marketplace == address(0)) {
            revert MarketplaceNotSet();
        }

        amount = IMarketplace(marketplace).clearTokenEscrow(revenueTokenId);
        if (amount > 0) {
            roboshareTokens.burn(marketplace, revenueTokenId, amount);
        }
    }

    function getRegistryForAsset(uint256 assetId) external view override returns (address) {
        return idToRegistry[assetId];
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

    /**
     * @dev Update PartnerManager address
     * @param _partnerManager New PartnerManager contract address
     */
    function updatePartnerManager(address _partnerManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_partnerManager == address(0)) revert ZeroAddress();
        address oldPartnerManager = address(partnerManager);
        partnerManager = PartnerManager(_partnerManager);
        emit PartnerManagerUpdated(oldPartnerManager, _partnerManager);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }
}
