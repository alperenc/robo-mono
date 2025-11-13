// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IAssetRegistry } from "./interfaces/IAssetRegistry.sol";
import { TokenLib, AssetLib, VehicleLib } from "./Libraries.sol";
import { RoboshareTokens } from "./RoboshareTokens.sol";
import { PartnerManager } from "./PartnerManager.sol";
import { Treasury } from "./Treasury.sol";

// Vehicle Registry errors
error VehicleRegistry__ZeroAddress();
error VehicleRegistry__VehicleAlreadyExists();
error VehicleRegistry__VehicleDoesNotExist();
error VehicleRegistry__RevenueTokensAlreadyMinted();
error VehicleRegistry__NotVehicleOwner();
error VehicleRegistry__IncorrectVehicleId();
error VehicleRegistry__IncorrectRevenueTokenId();
error VehicleRegistry__InvalidAssetData();
error VehicleRegistry__TreasuryNotSet();
error VehicleRegistry__TreasuryAlreadySet();

/**
 * @dev Vehicle registration and management with IPFS metadata integration
 * Coordinates with RoboshareTokens for minting and PartnerManager for authorization
 * Implements IAssetsRegistry for generic asset management capabilities
 */
contract VehicleRegistry is Initializable, AccessControlUpgradeable, UUPSUpgradeable, IAssetRegistry {
    using VehicleLib for VehicleLib.VehicleInfo;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Core contracts
    RoboshareTokens public roboshareTokens;
    PartnerManager public partnerManager;
    Treasury public treasury;

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
    event TreasuryAddressSet(address indexed treasury);

    /**
     * @dev Initialize contract with references to core contracts
     */
    function initialize(address _admin, address _roboshareTokens, address _partnerManager) public initializer {
        if (_admin == address(0) || _roboshareTokens == address(0) || _partnerManager == address(0)) {
            revert VehicleRegistry__ZeroAddress();
        }

        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);

        roboshareTokens = RoboshareTokens(_roboshareTokens);
        partnerManager = PartnerManager(_partnerManager);
    }

    /**
     * @dev Sets the Treasury contract address. Can only be called once by an admin.
     * This is part of a two-phase initialization to prevent circular deployment dependencies.
     */
    function setTreasury(address _treasury) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_treasury == address(0)) {
            revert VehicleRegistry__ZeroAddress();
        }
        if (address(treasury) != address(0)) {
            revert VehicleRegistry__TreasuryAlreadySet();
        }
        treasury = Treasury(_treasury);
        emit TreasuryAddressSet(_treasury);
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
        string memory dynamicMetadataURI
    ) internal returns (uint256 vehicleId, uint256 revenueTokenId) {
        if (vinExists[vin]) revert VehicleRegistry__VehicleAlreadyExists();

        // Get a unique pair of IDs from the central token contract
        (vehicleId, revenueTokenId) = roboshareTokens.reserveNextTokenIdPair();

        // Initialize vehicle data using new VehicleLib structure
        VehicleLib.Vehicle storage vehicle = vehicles[vehicleId];
        VehicleLib.initializeVehicle(
            vehicle,
            vehicleId,
            AssetLib.AssetStatus.Active,
            vin,
            make,
            model,
            year,
            manufacturerId,
            optionCodes,
            dynamicMetadataURI
        );

        // Mark VIN as used
        vinExists[vin] = true;

        emit AssetRegistered(vehicleId, msg.sender, AssetLib.AssetStatus.Active);
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
        if (vehicle.vehicleId == 0) revert VehicleRegistry__VehicleDoesNotExist();

        VehicleLib.VehicleInfo storage info = vehicle.vehicleInfo;
        return
            (info.vin, info.make, info.model, info.year, info.manufacturerId, info.optionCodes, info.dynamicMetadataURI);
    }

    /**
     * @dev Get vehicle display name
     */
    function getVehicleDisplayName(uint256 vehicleId) external view returns (string memory) {
        VehicleLib.Vehicle storage vehicle = vehicles[vehicleId];
        if (vehicle.vehicleId == 0) revert VehicleRegistry__VehicleDoesNotExist();

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
            string memory dynamicMetadataURI
        ) = abi.decode(data, (string, string, string, uint256, uint256, string, string));

        (assetId,) = _registerVehicle(vin, make, model, year, manufacturerId, optionCodes, dynamicMetadataURI);

        roboshareTokens.mint(msg.sender, assetId, 1, ""); // Mint 1 vehicle NFT to partner

        return assetId;
    }

    function mintRevenueTokens(uint256 assetId, uint256 price, uint256 supply)
        external
        override
        onlyAuthorizedPartner
        returns (uint256 revenueTokenId)
    {
        if (address(treasury) == address(0)) revert VehicleRegistry__TreasuryNotSet();

        VehicleLib.Vehicle storage vehicle = vehicles[assetId];
        if (vehicle.vehicleId == 0) revert AssetRegistry__AssetNotFound(assetId);
        if (roboshareTokens.balanceOf(msg.sender, assetId) == 0) revert VehicleRegistry__NotVehicleOwner();

        revenueTokenId = assetId + 1; // Revenue token ID is one more than vehicle NFT ID

        if (roboshareTokens.getRevenueTokenTotalSupply(revenueTokenId) > 0) {
            revert VehicleRegistry__RevenueTokensAlreadyMinted();
        }

        // Initialize revenue token info in RoboshareTokens
        roboshareTokens.setRevenueTokenInfo(revenueTokenId, price, supply);

        // Lock Collateral
        treasury.lockCollateralFor(msg.sender, assetId, price, supply);

        // Mint Revenue Tokens
        roboshareTokens.mint(msg.sender, revenueTokenId, supply, "");

        emit RevenueTokensMinted(assetId, revenueTokenId, msg.sender, supply);

        return revenueTokenId;
    }

    function registerAssetAndMintTokens(bytes calldata data, uint256 price, uint256 supply)
        external
        override
        onlyAuthorizedPartner
        returns (uint256 assetId, uint256 revenueTokenId)
    {
        if (address(treasury) == address(0)) revert VehicleRegistry__TreasuryNotSet();

        (
            string memory vin,
            string memory make,
            string memory model,
            uint256 year,
            uint256 manufacturerId,
            string memory optionCodes,
            string memory dynamicMetadataURI
        ) = abi.decode(data, (string, string, string, uint256, uint256, string, string));

        (assetId, revenueTokenId) =
            _registerVehicle(vin, make, model, year, manufacturerId, optionCodes, dynamicMetadataURI);

        // Initialize revenue token info in RoboshareTokens
        roboshareTokens.setRevenueTokenInfo(revenueTokenId, price, supply);

        // Mint Asset NFT
        roboshareTokens.mint(msg.sender, assetId, 1, "");

        // Lock Collateral
        treasury.lockCollateralFor(msg.sender, assetId, price, supply);

        // Mint Revenue Tokens
        roboshareTokens.mint(msg.sender, revenueTokenId, supply, "");

        emit VehicleRegisteredAndRevenueTokensMinted(assetId, revenueTokenId, msg.sender, supply);

        return (assetId, revenueTokenId);
    }

    /**
     * @dev Update dynamic metadata URI for a vehicle
     */
    function updateVehicleMetadata(uint256 vehicleId, string memory newMetadataURI) external onlyAuthorizedPartner {
        VehicleLib.Vehicle storage vehicle = vehicles[vehicleId];
        if (vehicle.vehicleId == 0) revert VehicleRegistry__VehicleDoesNotExist();

        VehicleLib.updateDynamicMetadata(vehicle.vehicleInfo, newMetadataURI);

        emit VehicleMetadataUpdated(vehicleId, newMetadataURI);
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
        if (vehicles[assetId].vehicleId == 0) revert AssetRegistry__AssetNotFound(assetId);
        return vehicles[assetId].assetInfo;
    }

    /**
     * @dev Get asset status
     */
    function getAssetStatus(uint256 assetId) external view override returns (AssetLib.AssetStatus) {
        if (vehicles[assetId].vehicleId == 0) revert AssetRegistry__AssetNotFound(assetId);
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
