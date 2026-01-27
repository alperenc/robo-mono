// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IAssetRegistry } from "./interfaces/IAssetRegistry.sol";
import { TokenLib, AssetLib, VehicleLib } from "./Libraries.sol";
import { RoboshareTokens } from "./RoboshareTokens.sol";
import { PartnerManager } from "./PartnerManager.sol";
import { RegistryRouter } from "./RegistryRouter.sol";

/**
 * @dev Vehicle registration and management with IPFS metadata integration
 * Coordinates with RoboshareTokens for minting and PartnerManager for authorization
 * Implements IAssetsRegistry for generic asset management capabilities
 */
contract VehicleRegistry is Initializable, AccessControlUpgradeable, UUPSUpgradeable, IAssetRegistry {
    using VehicleLib for VehicleLib.VehicleInfo;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant ROUTER_ROLE = keccak256("ROUTER_ROLE");

    // Core contracts
    RoboshareTokens public roboshareTokens;
    PartnerManager public partnerManager;
    RegistryRouter public router;

    // Vehicle storage
    mapping(uint256 => VehicleLib.Vehicle) public vehicles;
    mapping(string => bool) public vinExists; // VIN uniqueness tracking

    // Errors
    error ZeroAddress();
    error VehicleAlreadyExists();
    error VehicleDoesNotExist();
    error RevenueTokensAlreadyMinted();
    error OutstandingTokensHeldByOthers();

    // Events
    event VehicleRegistered(uint256 indexed vehicleId, address indexed partner, string vin);

    event RevenueTokensMinted(
        uint256 indexed vehicleId,
        uint256 indexed revenueTokenId,
        address indexed partner,
        uint256 assetValue,
        uint256 supply
    );

    event VehicleRegisteredAndRevenueTokensMinted(
        uint256 indexed vehicleId,
        uint256 indexed revenueTokenId,
        address indexed partner,
        uint256 assetValue,
        uint256 supply
    );

    event VehicleMetadataUpdated(uint256 indexed vehicleId, string newMetadataURI);
    event RoboshareTokensUpdated(address indexed oldAddress, address indexed newAddress);
    event PartnerManagerUpdated(address indexed oldAddress, address indexed newAddress);
    event RouterUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @dev Initialize contract with references to core contracts
     */
    function initialize(address _admin, address _roboshareTokens, address _partnerManager, address _router)
        public
        initializer
    {
        if (
            _admin == address(0) || _roboshareTokens == address(0) || _partnerManager == address(0)
                || _router == address(0)
        ) {
            revert ZeroAddress();
        }

        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
        _grantRole(ROUTER_ROLE, _router);

        roboshareTokens = RoboshareTokens(_roboshareTokens);
        partnerManager = PartnerManager(_partnerManager);
        router = RegistryRouter(_router);
    }

    /**
     * @dev Modifier to ensure only authorized partners can call functions
     */
    modifier onlyAuthorizedPartner() {
        _onlyAuthorizedPartner();
        _;
    }

    function _onlyAuthorizedPartner() internal view {
        if (!partnerManager.isAuthorizedPartner(msg.sender)) {
            revert PartnerManager.UnauthorizedPartner();
        }
    }

    /**
     * @dev Internal function to register vehicle data only
     */
    function _registerVehicle(bytes calldata data, uint256 assetValue)
        internal
        returns (uint256 vehicleId, uint256 revenueTokenId)
    {
        (
            string memory vin,
            string memory make,
            string memory model,
            uint256 year,
            uint256 manufacturerId,
            string memory optionCodes,
            string memory dynamicMetadataURI
        ) = abi.decode(data, (string, string, string, uint256, uint256, string, string));

        if (vinExists[vin]) revert VehicleAlreadyExists();

        // Get a unique pair of IDs from the Router (which calls RoboshareTokens)
        (vehicleId, revenueTokenId) = router.reserveNextTokenIdPair();

        // Initialize vehicle data using new VehicleLib structure
        VehicleLib.Vehicle storage vehicle = vehicles[vehicleId];
        VehicleLib.initializeVehicle(
            vehicle, vehicleId, assetValue, vin, make, model, year, manufacturerId, optionCodes, dynamicMetadataURI
        );

        // Mark VIN as used
        vinExists[vin] = true;

        emit AssetRegistered(vehicleId, msg.sender, assetValue, vehicle.assetInfo.status);
        emit VehicleRegistered(vehicleId, msg.sender, vin);
    }

    // View Functions

    /**
     * @dev Get vehicle information
     */
    function getVehicleInfo(uint256 vehicleId)
        external
        view
        returns (
            string memory vin,
            string memory make,
            string memory model,
            uint256 year,
            uint256 manufacturerId,
            string memory optionCodes,
            string memory dynamicMetadataURI
        )
    {
        VehicleLib.Vehicle storage vehicle = vehicles[vehicleId];
        if (vehicle.vehicleId == 0) {
            revert VehicleDoesNotExist();
        }

        VehicleLib.VehicleInfo storage info = vehicle.vehicleInfo;
        return
            (info.vin, info.make, info.model, info.year, info.manufacturerId, info.optionCodes, info.dynamicMetadataURI);
    }

    /**
     * @dev Get vehicle display name
     */
    function getVehicleDisplayName(uint256 vehicleId) external view returns (string memory) {
        VehicleLib.Vehicle storage vehicle = vehicles[vehicleId];
        if (vehicle.vehicleId == 0) {
            revert VehicleDoesNotExist();
        }

        return VehicleLib.getDisplayName(vehicle.vehicleInfo);
    }

    // IAssetsRegistry implementation

    function registerAsset(bytes calldata data, uint256 assetValue)
        external
        override
        onlyAuthorizedPartner
        returns (uint256 assetId)
    {
        (assetId,) = _registerVehicle(data, assetValue);

        roboshareTokens.mint(msg.sender, assetId, 1, ""); // Mint 1 vehicle NFT to partner

        return assetId;
    }

    function mintRevenueTokens(uint256 assetId, uint256 tokenPrice, uint256 maturityDate)
        external
        override
        onlyAuthorizedPartner
        returns (uint256 revenueTokenId, uint256 supply)
    {
        if (vehicles[assetId].vehicleId == 0) {
            revert AssetNotFound(assetId);
        }
        if (roboshareTokens.balanceOf(msg.sender, assetId) == 0) {
            revert NotAssetOwner();
        }

        // Get token ID (pure conversion)
        revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);

        if (roboshareTokens.getRevenueTokenSupply(revenueTokenId) > 0) {
            revert RevenueTokensAlreadyMinted();
        }

        // Calculate supply based on asset value and token price
        uint256 assetValue = vehicles[assetId].assetInfo.assetValue;
        supply = assetValue / tokenPrice;

        // Initialize revenue token info in RoboshareTokens
        roboshareTokens.setRevenueTokenInfo(revenueTokenId, tokenPrice, supply, maturityDate);

        // Lock Collateral via Router
        router.lockCollateralFor(msg.sender, assetId, assetValue);

        // Mint Revenue Tokens
        roboshareTokens.mint(msg.sender, revenueTokenId, supply, "");

        // Activate asset
        _setAssetStatus(assetId, AssetLib.AssetStatus.Active);

        emit RevenueTokensMinted(assetId, revenueTokenId, msg.sender, assetValue, supply);

        return (revenueTokenId, supply);
    }

    function registerAssetAndMintTokens(
        bytes calldata data,
        uint256 assetValue,
        uint256 tokenPrice,
        uint256 maturityDate
    ) external override onlyAuthorizedPartner returns (uint256 assetId, uint256 revenueTokenId, uint256 supply) {
        (assetId, revenueTokenId) = _registerVehicle(data, assetValue);

        // Calculate supply based on asset value and token price

        supply = assetValue / tokenPrice;

        // Initialize revenue token info in RoboshareTokens

        roboshareTokens.setRevenueTokenInfo(revenueTokenId, tokenPrice, supply, maturityDate);

        // Mint Asset NFT

        roboshareTokens.mint(msg.sender, assetId, 1, "");

        // Lock Collateral via Router

        router.lockCollateralFor(msg.sender, assetId, assetValue);

        // Mint Revenue Tokens

        roboshareTokens.mint(msg.sender, revenueTokenId, supply, "");

        // Activate asset

        _setAssetStatus(assetId, AssetLib.AssetStatus.Active);

        emit VehicleRegisteredAndRevenueTokensMinted(assetId, revenueTokenId, msg.sender, assetValue, supply);

        return (assetId, revenueTokenId, supply);
    }

    /**
     * @dev Register a vehicle, mint revenue tokens, and list for sale - all in one transaction.
     * Combines registerAssetAndMintTokens + router.createListingFor for better UX.
     * IMPORTANT: Partner must have approved marketplace for token transfers before calling.
     * @param data Encoded vehicle data (same as registerAsset)
     * @param assetValue Total value of the asset in USDC
     * @param tokenPrice Price per revenue token in USDC
     * @param maturityDate Maturity date for the revenue tokens
     * @param listingDuration Duration of the marketplace listing in seconds
     * @param buyerPaysFee If true, buyer pays protocol fee
     * @return assetId The registered asset ID
     * @return revenueTokenId The minted revenue token ID
     * @return supply The minted revenue token supply
     * @return listingId The created marketplace listing ID
     */
    function registerAssetMintAndList(
        bytes calldata data,
        uint256 assetValue,
        uint256 tokenPrice,
        uint256 maturityDate,
        uint256 listingDuration,
        bool buyerPaysFee
    )
        external
        override
        onlyAuthorizedPartner
        returns (uint256 assetId, uint256 revenueTokenId, uint256 supply, uint256 listingId)
    {
        // Step 1: Register and mint (reuses existing logic)
        (assetId, revenueTokenId) = _registerVehicle(data, assetValue);

        // Calculate supply based on asset value and token price
        supply = assetValue / tokenPrice;

        // Initialize revenue token info in RoboshareTokens
        roboshareTokens.setRevenueTokenInfo(revenueTokenId, tokenPrice, supply, maturityDate);

        // Mint Asset NFT
        roboshareTokens.mint(msg.sender, assetId, 1, "");

        // Lock Collateral via Router
        router.lockCollateralFor(msg.sender, assetId, assetValue);

        // Mint Revenue Tokens
        roboshareTokens.mint(msg.sender, revenueTokenId, supply, "");

        // Activate asset
        _setAssetStatus(assetId, AssetLib.AssetStatus.Active);

        emit VehicleRegisteredAndRevenueTokensMinted(assetId, revenueTokenId, msg.sender, assetValue, supply);

        // Step 2: Create listing at face value with full supply via Router
        listingId = router.createListingFor(
            msg.sender,
            revenueTokenId,
            supply, // Full supply
            tokenPrice, // Face value
            listingDuration,
            buyerPaysFee
        );
    }

    /**
     * @dev Update dynamic metadata URI for a vehicle
     */
    function updateVehicleMetadata(uint256 vehicleId, string memory newMetadataURI) external onlyAuthorizedPartner {
        VehicleLib.Vehicle storage vehicle = vehicles[vehicleId];
        if (vehicle.vehicleId == 0) {
            revert VehicleDoesNotExist();
        }

        VehicleLib.updateDynamicMetadata(vehicle.vehicleInfo, newMetadataURI);

        emit VehicleMetadataUpdated(vehicleId, newMetadataURI);
    }

    /**
     * @dev Burn revenue tokens.
     * Can be called by partner to reduce supply or internally by retireAssetAndBurnTokens.
     */
    function burnRevenueTokens(uint256 assetId, uint256 amount) public override onlyAuthorizedPartner {
        if (vehicles[assetId].vehicleId == 0) {
            revert AssetNotFound(assetId);
        }

        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);

        // Burn tokens
        roboshareTokens.burn(msg.sender, revenueTokenId, amount);
    }

    /**
     * @dev Voluntarily settle and retire an asset.
     * Partner can optionally top up the settlement pool to offer a higher payout.
     * Updates status to Retired and triggers settlement via Router.
     */
    function settleAsset(uint256 assetId, uint256 topUpAmount) external override onlyAuthorizedPartner {
        if (roboshareTokens.balanceOf(msg.sender, assetId) == 0) {
            revert NotAssetOwner();
        }

        // Verify asset is active
        if (!AssetLib.isOperational(vehicles[assetId].assetInfo)) {
            revert AssetNotActive(assetId, vehicles[assetId].assetInfo.status);
        }

        // Trigger Treasury Settlement via Router
        (uint256 settlementAmount, uint256 settlementPerToken) =
            router.initiateSettlement(msg.sender, assetId, topUpAmount);

        emit AssetSettled(assetId, msg.sender, settlementAmount, settlementPerToken);
    }

    /**
     * @dev Force liquidation of an asset.
     * Publicly callable if asset is expired or insolvent.
     * Updates status to Expired and triggers liquidation via Router.
     */
    function liquidateAsset(uint256 assetId) external override {
        if (vehicles[assetId].vehicleId == 0) {
            revert AssetNotFound(assetId);
        }

        AssetLib.AssetInfo storage info = vehicles[assetId].assetInfo;

        // Check if asset is already settled/retired
        if (info.status == AssetLib.AssetStatus.Retired || info.status == AssetLib.AssetStatus.Expired) {
            revert AssetAlreadySettled(assetId, info.status);
        }

        // Check liquidation conditions: Maturity OR Insolvency
        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);
        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(revenueTokenId);
        bool isMatured = block.timestamp >= maturityDate;
        bool isSolvent = router.isAssetSolvent(assetId);

        if (!isMatured && isSolvent) {
            revert AssetNotEligibleForLiquidation(assetId);
        }

        // Trigger Treasury Liquidation via Router
        (uint256 liquidationAmount, uint256 settlementPerToken) = router.executeLiquidation(assetId);

        emit AssetExpired(assetId, liquidationAmount, settlementPerToken);
    }

    /**
     * @dev Claim settlement funds.
     * Burns all revenue tokens held by caller and transfers settlement payout from Treasury.
     * @param assetId The ID of the settled asset
     * @param autoClaimEarnings If true, claims any unclaimed earnings before settlement in same tx.
     *                           If false, earnings are snapshotted and can be claimed via claimEarnings later.
     * @return claimedAmount The settlement USDC amount received
     * @return earningsClaimed The earnings USDC amount received (0 if autoClaimEarnings is false)
     */
    function claimSettlement(uint256 assetId, bool autoClaimEarnings)
        external
        override
        returns (uint256 claimedAmount, uint256 earningsClaimed)
    {
        if (vehicles[assetId].vehicleId == 0) {
            revert AssetNotFound(assetId);
        }

        AssetLib.AssetInfo storage info = vehicles[assetId].assetInfo;

        // Verify asset is settled
        if (info.status != AssetLib.AssetStatus.Retired && info.status != AssetLib.AssetStatus.Expired) {
            revert AssetNotSettled(assetId, info.status);
        }

        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);
        uint256 balance = roboshareTokens.balanceOf(msg.sender, revenueTokenId);

        if (balance == 0) {
            revert InsufficientTokenBalance(revenueTokenId, 1, balance);
        }

        // Snapshot (and optionally claim) earnings BEFORE burning tokens
        // This preserves earnings so they can be claimed later even after tokens are burned
        uint256 snapshotAmount = router.snapshotAndClaimEarnings(assetId, msg.sender, autoClaimEarnings);

        // Only return earnings if they were actually claimed (autoClaim=true)
        // When autoClaim=false, earnings are snapshotted for later claim via claimEarnings()
        if (autoClaimEarnings) {
            earningsClaimed = snapshotAmount;
        }

        // Burn tokens (positions will be deleted)
        roboshareTokens.burn(msg.sender, revenueTokenId, balance);

        // Process Claim via Router -> Treasury
        claimedAmount = router.processSettlementClaim(msg.sender, assetId, balance);

        emit SettlementClaimed(assetId, msg.sender, balance, claimedAmount);
    }

    /**
     * @dev Retire an asset.
     * Requires 0 revenue token supply.
     * Updates status and triggers settlement via Router.
     */
    function retireAsset(uint256 assetId) external override onlyAuthorizedPartner {
        if (roboshareTokens.balanceOf(msg.sender, assetId) == 0) {
            revert NotAssetOwner();
        }
        _retireAsset(assetId, msg.sender, 0);
    }

    /**
     * @dev Retire an asset and burn all partner's revenue tokens.
     * Convenience function for the full retirement flow.
     * Burns tokens first, then retires asset. Treasury will verify 0 supply.
     */
    function retireAssetAndBurnTokens(uint256 assetId) external override onlyAuthorizedPartner {
        if (vehicles[assetId].vehicleId == 0) {
            revert AssetNotFound(assetId);
        }

        // Verify ownership
        if (roboshareTokens.balanceOf(msg.sender, assetId) == 0) {
            revert NotAssetOwner();
        }

        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(assetId);
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);

        uint256 burnedTokens = 0;
        if (totalSupply > 0) {
            uint256 partnerBalance = roboshareTokens.balanceOf(msg.sender, revenueTokenId);
            if (partnerBalance < totalSupply) {
                revert OutstandingTokensHeldByOthers();
            }

            // Use existing burnRevenueTokens function
            burnRevenueTokens(assetId, partnerBalance);
            burnedTokens = partnerBalance;
        }

        // Call internal _retireAsset (Treasury will verify 0 token supply)
        _retireAsset(assetId, msg.sender, burnedTokens);
    }

    /**
     * @dev Internal function to handle asset retirement logic.
     * Verifies ownership and status, updates status to Archived, and triggers collateral release via Router.
     */
    function _retireAsset(uint256 assetId, address partner, uint256 burnedTokens) internal {
        // Verify asset is active
        if (!AssetLib.isOperational(vehicles[assetId].assetInfo)) {
            revert AssetNotActive(assetId, vehicles[assetId].assetInfo.status);
        }

        // Update Status using internal helper
        _setAssetStatus(assetId, AssetLib.AssetStatus.Retired);

        // Trigger Treasury Settlement via Router
        uint256 releasedCollateral = router.releaseCollateralFor(partner, assetId);

        emit AssetRetired(assetId, partner, burnedTokens, releasedCollateral);
    }

    /**
     * @dev Update asset status. Only callable by Router.
     */
    function setAssetStatus(uint256 assetId, AssetLib.AssetStatus status) external override onlyRole(ROUTER_ROLE) {
        if (vehicles[assetId].vehicleId == 0) {
            revert AssetNotFound(assetId);
        }

        _setAssetStatus(assetId, status);
    }

    /**
     * @dev Internal helper to update asset status and emit event.
     */
    function _setAssetStatus(uint256 assetId, AssetLib.AssetStatus status) internal {
        AssetLib.AssetStatus oldStatus = vehicles[assetId].assetInfo.status;

        // Use library for validation and updates
        AssetLib.updateAssetStatus(vehicles[assetId].assetInfo, status);

        emit AssetStatusUpdated(assetId, oldStatus, status);
    }

    /**
     * @dev Check if asset exists
     */
    function assetExists(uint256 assetId) external view override returns (bool) {
        return vehicles[assetId].vehicleId != 0;
    }

    /**
     * @dev Get asset information
     */
    function getAssetInfo(uint256 assetId) external view override returns (AssetLib.AssetInfo memory) {
        if (vehicles[assetId].vehicleId == 0) {
            revert AssetNotFound(assetId);
        }
        return vehicles[assetId].assetInfo;
    }

    /**
     * @dev Get asset status
     */
    function getAssetStatus(uint256 assetId) external view override returns (AssetLib.AssetStatus) {
        if (vehicles[assetId].vehicleId == 0) {
            revert AssetNotFound(assetId);
        }
        return vehicles[assetId].assetInfo.status;
    }

    /**
     * @dev Check if account is authorized for asset
     */
    function isAuthorizedForAsset(address account, uint256 assetId) external view override returns (bool) {
        // Must be an authorized partner AND own the asset
        if (!partnerManager.isAuthorizedPartner(account)) {
            return false;
        }

        // Check if the account owns the vehicle (has the vehicle NFT)
        return roboshareTokens.balanceOf(account, assetId) > 0;
    }

    function getRegistryForAsset(uint256 assetId) external view override returns (address) {
        if (vehicles[assetId].vehicleId != 0) {
            return address(this);
        }
        return address(0);
    }

    /**
     * @dev Get registry type
     */
    function getRegistryType() external pure override returns (string memory) {
        return "VehicleRegistry";
    }

    /**
     * @dev Get registry version
     */
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
     * @dev Update PartnerManager contract reference
     * @param _partnerManager New PartnerManager contract address
     */
    function updatePartnerManager(address _partnerManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_partnerManager == address(0)) {
            revert ZeroAddress();
        }
        address oldAddress = address(partnerManager);
        partnerManager = PartnerManager(_partnerManager);
        emit PartnerManagerUpdated(oldAddress, _partnerManager);
    }

    /**
     * @dev Update RegistryRouter contract reference
     * @param _router New RegistryRouter contract address
     */
    function updateRouter(address _router) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_router == address(0)) {
            revert ZeroAddress();
        }
        address oldAddress = address(router);
        _revokeRole(ROUTER_ROLE, oldAddress);
        router = RegistryRouter(_router);
        _grantRole(ROUTER_ROLE, _router);
        emit RouterUpdated(oldAddress, _router);
    }

    // UUPS Upgrade authorization
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }
}
