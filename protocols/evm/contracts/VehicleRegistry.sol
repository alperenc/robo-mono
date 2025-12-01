// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IAssetRegistry } from "./interfaces/IAssetRegistry.sol";
import { TokenLib, AssetLib, VehicleLib } from "./Libraries.sol";
import { RegistryRouter } from "./RegistryRouter.sol";
import { RoboshareTokens } from "./RoboshareTokens.sol";
import { PartnerManager } from "./PartnerManager.sol";

// Vehicle Registry errors
error VehicleRegistry__ZeroAddress();
error VehicleRegistry__VehicleAlreadyExists();
error VehicleRegistry__VehicleDoesNotExist();
error VehicleRegistry__RevenueTokensAlreadyMinted();
error VehicleRegistry__OutstandingTokensHeldByOthers();
error VehicleRegistry__NotVehicleOwner();
error VehicleRegistry__IncorrectVehicleId();
error VehicleRegistry__IncorrectRevenueTokenId();
error VehicleRegistry__AssetNotActive(uint256 assetId, AssetLib.AssetStatus currentStatus);

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

    // Events
    event VehicleRegistered(uint256 indexed vehicleId, address indexed partner, string vin);

    event RevenueTokensMinted(
        uint256 indexed vehicleId, uint256 indexed revenueTokenId, address indexed partner, uint256 totalSupply
    );

    event VehicleRegisteredAndRevenueTokensMinted(
        uint256 indexed vehicleId, uint256 indexed revenueTokenId, address indexed partner, uint256 totalSupply
    );

    event VehicleMetadataUpdated(uint256 indexed vehicleId, string newMetadataURI);

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
            revert VehicleRegistry__ZeroAddress();
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
        if (!partnerManager.isAuthorizedPartner(msg.sender)) {
            revert PartnerManager.PartnerManager__NotAuthorized();
        }
        _;
    }

    /**
     * @dev Internal function to register vehicle data only
     */
    function _registerVehicle(
        string memory vin,
        string memory make,
        string memory model,
        uint256 year,
        uint256 manufacturerId,
        string memory optionCodes,
        string memory dynamicMetadataURI,
        uint256 maturityDate
    ) internal returns (uint256 vehicleId, uint256 revenueTokenId) {
        if (vinExists[vin]) revert VehicleRegistry__VehicleAlreadyExists();

        // Get a unique pair of IDs from the Router (which calls RoboshareTokens)
        (vehicleId, revenueTokenId) = router.reserveNextTokenIdPair();

        // Initialize vehicle data using new VehicleLib structure
        VehicleLib.Vehicle storage vehicle = vehicles[vehicleId];
        VehicleLib.initializeVehicle(
            vehicle, vehicleId, vin, make, model, year, manufacturerId, optionCodes, dynamicMetadataURI, maturityDate
        );

        // Mark VIN as used
        vinExists[vin] = true;

        emit AssetRegistered(vehicleId, msg.sender, vehicle.assetInfo.status);
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
            revert VehicleRegistry__VehicleDoesNotExist();
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
            revert VehicleRegistry__VehicleDoesNotExist();
        }

        return VehicleLib.getDisplayName(vehicle.vehicleInfo);
    }

    // IAssetsRegistry implementation

    function registerAsset(bytes calldata data) external override onlyAuthorizedPartner returns (uint256 assetId) {
        (
            string memory vin,
            string memory make,
            string memory model,
            uint256 year,
            uint256 manufacturerId,
            string memory optionCodes,
            string memory dynamicMetadataURI,
            uint256 maturityDate
        ) = abi.decode(data, (string, string, string, uint256, uint256, string, string, uint256));

        (assetId,) =
            _registerVehicle(vin, make, model, year, manufacturerId, optionCodes, dynamicMetadataURI, maturityDate);

        roboshareTokens.mint(msg.sender, assetId, 1, ""); // Mint 1 vehicle NFT to partner

        return assetId;
    }

    function mintRevenueTokens(uint256 assetId, uint256 price, uint256 supply)
        external
        override
        onlyAuthorizedPartner
        returns (uint256 revenueTokenId)
    {
        VehicleLib.Vehicle storage vehicle = vehicles[assetId];
        if (vehicle.vehicleId == 0) {
            revert AssetNotFound(assetId);
        }
        if (roboshareTokens.balanceOf(msg.sender, assetId) == 0) {
            revert VehicleRegistry__NotVehicleOwner();
        }

        revenueTokenId = assetId + 1; // Revenue token ID is one more than vehicle NFT ID

        if (roboshareTokens.getRevenueTokenSupply(revenueTokenId) > 0) {
            revert VehicleRegistry__RevenueTokensAlreadyMinted();
        }

        // Initialize revenue token info in RoboshareTokens
        roboshareTokens.setRevenueTokenInfo(revenueTokenId, price, supply);

        // Lock Collateral via Router
        router.lockCollateralFor(msg.sender, assetId, price, supply);

        // Mint Revenue Tokens
        roboshareTokens.mint(msg.sender, revenueTokenId, supply, "");

        // Activate asset
        _setAssetStatus(assetId, AssetLib.AssetStatus.Active);

        emit RevenueTokensMinted(assetId, revenueTokenId, msg.sender, supply);

        return revenueTokenId;
    }

    function registerAssetAndMintTokens(bytes calldata data, uint256 price, uint256 supply)
        external
        override
        onlyAuthorizedPartner
        returns (uint256 assetId, uint256 revenueTokenId)
    {
        (
            string memory vin,
            string memory make,
            string memory model,
            uint256 year,
            uint256 manufacturerId,
            string memory optionCodes,
            string memory dynamicMetadataURI,
            uint256 maturityDate
        ) = abi.decode(data, (string, string, string, uint256, uint256, string, string, uint256));

        (assetId, revenueTokenId) =
            _registerVehicle(vin, make, model, year, manufacturerId, optionCodes, dynamicMetadataURI, maturityDate);

        // Initialize revenue token info in RoboshareTokens
        roboshareTokens.setRevenueTokenInfo(revenueTokenId, price, supply);

        // Mint Asset NFT
        roboshareTokens.mint(msg.sender, assetId, 1, "");

        // Lock Collateral via Router
        router.lockCollateralFor(msg.sender, assetId, price, supply);

        // Mint Revenue Tokens
        roboshareTokens.mint(msg.sender, revenueTokenId, supply, "");

        // Activate asset
        _setAssetStatus(assetId, AssetLib.AssetStatus.Active);

        emit VehicleRegisteredAndRevenueTokensMinted(assetId, revenueTokenId, msg.sender, supply);

        return (assetId, revenueTokenId);
    }

    /**
     * @dev Update dynamic metadata URI for a vehicle
     */
    function updateVehicleMetadata(uint256 vehicleId, string memory newMetadataURI) external onlyAuthorizedPartner {
        VehicleLib.Vehicle storage vehicle = vehicles[vehicleId];
        if (vehicle.vehicleId == 0) {
            revert VehicleRegistry__VehicleDoesNotExist();
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

        uint256 revenueTokenId = assetId + 1;

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
            revert VehicleRegistry__NotVehicleOwner();
        }

        // Verify asset is active
        if (!AssetLib.isOperational(vehicles[assetId].assetInfo)) {
            revert VehicleRegistry__AssetNotActive(assetId, vehicles[assetId].assetInfo.status);
        }

        // Update Status
        _setAssetStatus(assetId, AssetLib.AssetStatus.Retired);

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
            revert VehicleRegistry__AssetNotActive(assetId, info.status);
        }

        // Check liquidation conditions: Maturity OR Insolvency
        bool isMatured = block.timestamp >= info.maturityDate;
        bool isSolvent = router.isAssetSolvent(assetId);

        if (!isMatured && isSolvent) {
            revert("Asset not eligible for liquidation");
        }

        // Update Status
        _setAssetStatus(assetId, AssetLib.AssetStatus.Expired);

        // Trigger Treasury Liquidation via Router
        (uint256 liquidationAmount, uint256 settlementPerToken) = router.executeLiquidation(assetId);

        emit AssetExpired(assetId, liquidationAmount, settlementPerToken);
    }

    /**
     * @dev Retire an asset.
     * Requires 0 revenue token supply.
     * Updates status and triggers settlement via Router.
     */
    function retireAsset(uint256 assetId) external override onlyAuthorizedPartner {
        if (roboshareTokens.balanceOf(msg.sender, assetId) == 0) {
            revert VehicleRegistry__NotVehicleOwner();
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
            revert VehicleRegistry__NotVehicleOwner();
        }

        uint256 revenueTokenId = assetId + 1;
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);

        uint256 burnedTokens = 0;
        if (totalSupply > 0) {
            uint256 partnerBalance = roboshareTokens.balanceOf(msg.sender, revenueTokenId);
            if (partnerBalance < totalSupply) {
                revert VehicleRegistry__OutstandingTokensHeldByOthers();
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

        // Verify asset is active
        if (!AssetLib.isOperational(vehicles[assetId].assetInfo)) {
            revert VehicleRegistry__AssetNotActive(assetId, vehicles[assetId].assetInfo.status);
        }

        // Update Status using internal helper
        _setAssetStatus(assetId, AssetLib.AssetStatus.Archived);

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
     * @dev Get asset ID from token ID
     */
    function getAssetIdFromTokenId(uint256 tokenId) external view override returns (uint256) {
        if (!TokenLib.isRevenueToken(tokenId) || tokenId > roboshareTokens.getNextTokenId()) {
            revert VehicleRegistry__IncorrectRevenueTokenId();
        }

        return tokenId - 1; // Vehicle NFT has ID one less than revenue token ID
    }

    /**
     * @dev Get token ID from asset ID
     */
    function getTokenIdFromAssetId(uint256 assetId) external view override returns (uint256) {
        if (TokenLib.isRevenueToken(assetId) || assetId == 0 || assetId >= roboshareTokens.getNextTokenId()) {
            revert VehicleRegistry__IncorrectVehicleId();
        }

        return assetId + 1; // Revenue token ID is one more than vehicle NFT ID
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

    // UUPS Upgrade authorization
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }
}
