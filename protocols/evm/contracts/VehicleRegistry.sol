// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./Libraries.sol";
import "./RoboshareTokens.sol";
import "./PartnerManager.sol";

// Vehicle Registry errors
error VehicleRegistry__ZeroAddress();
error VehicleRegistry__VehicleAlreadyExists();
error VehicleRegistry__VehicleDoesNotExist();
error VehicleRegistry__NotVehicleOwner();
error VehicleRegistry__InvalidTokenId();
error VehicleRegistry__IncorrectVehicleId();
error VehicleRegistry__IncorrectRevenueShareTokenId();

/**
 * @dev Vehicle registration and management with IPFS metadata integration
 * Coordinates with RoboshareTokens for minting and PartnerManager for authorization
 */
contract VehicleRegistry is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    using VehicleLib for VehicleLib.VehicleInfo;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Core contracts
    RoboshareTokens public roboshareTokens;
    PartnerManager public partnerManager;

    // Vehicle storage
    mapping(uint256 => VehicleLib.Vehicle) public vehicles;
    mapping(string => bool) public vinExists; // VIN uniqueness tracking

    // Token management
    uint256 private _tokenIdCounter;

    // Events
    event VehicleRegistered(uint256 indexed vehicleId, address indexed partner, string vin, address indexed owner);

    event RevenueShareTokensMinted(
        uint256 indexed vehicleId, uint256 indexed revenueShareTokenId, address indexed partner, uint256 totalSupply
    );

    event VehicleAndRevenueShareTokensMinted(
        uint256 indexed vehicleId,
        uint256 indexed revenueShareTokenId,
        address indexed partner,
        address vehicleOwner,
        uint256 revenueShareSupply
    );

    event VehicleMetadataUpdated(uint256 indexed vehicleId, string newMetadataURI);

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

        // Start with tokenId 1 (vehicles will be odd: 1, 3, 5...)
        _tokenIdCounter = 1;
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
     * @dev Register vehicle and mint NFT token
     */
    function registerVehicle(
        address owner,
        string memory vin,
        string memory make,
        string memory model,
        uint256 year,
        uint256 manufacturerId,
        string memory optionCodes,
        string memory dynamicMetadataURI
    ) external onlyAuthorizedPartner returns (uint256 vehicleId) {
        return _registerVehicle(owner, vin, make, model, year, manufacturerId, optionCodes, dynamicMetadataURI);
    }

    /**
     * @dev Internal function to register vehicle and mint NFT token
     */
    function _registerVehicle(
        address owner,
        string memory vin,
        string memory make,
        string memory model,
        uint256 year,
        uint256 manufacturerId,
        string memory optionCodes,
        string memory dynamicMetadataURI
    ) internal returns (uint256 vehicleId) {
        if (owner == address(0)) revert VehicleRegistry__ZeroAddress();
        if (vinExists[vin]) revert VehicleRegistry__VehicleAlreadyExists();

        // Get current token ID (always odd for vehicles)
        vehicleId = _tokenIdCounter;
        _tokenIdCounter += 2; // Next vehicle will be vehicleId + 2

        // Initialize vehicle data
        VehicleLib.Vehicle storage vehicle = vehicles[vehicleId];
        vehicle.vehicleId = vehicleId;
        vehicle.isActive = true;
        vehicle.createdAt = block.timestamp;

        // Initialize vehicle info with validation
        VehicleLib.initializeVehicleInfo(
            vehicle.vehicleInfo, vin, make, model, year, manufacturerId, optionCodes, dynamicMetadataURI
        );

        // Mark VIN as used
        vinExists[vin] = true;

        // Mint vehicle NFT token
        roboshareTokens.mint(owner, vehicleId, 1, "");

        emit VehicleRegistered(vehicleId, msg.sender, vin, owner);

        return vehicleId;
    }

    /**
     * @dev Mint revenue share tokens for existing vehicle
     */
    function mintRevenueShareTokens(uint256 vehicleId, uint256 totalSupply)
        external
        onlyAuthorizedPartner
        returns (uint256 revenueShareTokenId)
    {
        // Validate vehicle exists
        VehicleLib.Vehicle storage vehicle = vehicles[vehicleId];
        if (!vehicle.isActive) revert VehicleRegistry__VehicleDoesNotExist();

        // Calculate revenue share token ID (always even)
        revenueShareTokenId = getRevenueShareTokenIdFromVehicleId(vehicleId);

        // Mint revenue share tokens to partner (who can distribute)
        roboshareTokens.mint(msg.sender, revenueShareTokenId, totalSupply, "");

        emit RevenueShareTokensMinted(vehicleId, revenueShareTokenId, msg.sender, totalSupply);

        return revenueShareTokenId;
    }

    /**
     * @dev Register vehicle and mint both NFT and revenue share tokens in one transaction
     */
    function registerVehicleAndMintRevenueShareTokens(
        address vehicleOwner,
        string memory vin,
        string memory make,
        string memory model,
        uint256 year,
        uint256 manufacturerId,
        string memory optionCodes,
        string memory dynamicMetadataURI,
        uint256 revenueShareSupply
    ) external onlyAuthorizedPartner returns (uint256 vehicleId, uint256 revenueShareTokenId) {
        // Register vehicle and get vehicle ID
        vehicleId = _registerVehicle(vehicleOwner, vin, make, model, year, manufacturerId, optionCodes, dynamicMetadataURI);

        // Calculate revenue share token ID (vehicleId + 1)
        revenueShareTokenId = getRevenueShareTokenIdFromVehicleId(vehicleId);

        // Mint revenue share tokens to partner
        roboshareTokens.mint(msg.sender, revenueShareTokenId, revenueShareSupply, "");

        emit VehicleAndRevenueShareTokensMinted(
            vehicleId, revenueShareTokenId, msg.sender, vehicleOwner, revenueShareSupply
        );

        return (vehicleId, revenueShareTokenId);
    }

    /**
     * @dev Update dynamic metadata URI for a vehicle
     */
    function updateVehicleMetadata(uint256 vehicleId, string memory newMetadataURI) external onlyAuthorizedPartner {
        VehicleLib.Vehicle storage vehicle = vehicles[vehicleId];
        if (!vehicle.isActive) revert VehicleRegistry__VehicleDoesNotExist();

        VehicleLib.updateDynamicMetadata(vehicle.vehicleInfo, newMetadataURI);

        emit VehicleMetadataUpdated(vehicleId, newMetadataURI);
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
        if (!vehicle.isActive) revert VehicleRegistry__VehicleDoesNotExist();

        VehicleLib.VehicleInfo storage info = vehicle.vehicleInfo;
        return
            (info.vin, info.make, info.model, info.year, info.manufacturerId, info.optionCodes, info.dynamicMetadataURI);
    }

    /**
     * @dev Get vehicle display name
     */
    function getVehicleDisplayName(uint256 vehicleId) external view returns (string memory) {
        VehicleLib.Vehicle storage vehicle = vehicles[vehicleId];
        if (!vehicle.isActive) revert VehicleRegistry__VehicleDoesNotExist();

        return VehicleLib.getDisplayName(vehicle.vehicleInfo);
    }

    /**
     * @dev Get the vehicle ID corresponding to a revenue share token ID
     * Revenue share token IDs are always even, vehicle IDs are always odd
     */
    function getVehicleIdFromRevenueShareTokenId(uint256 revenueShareTokenId) public view returns (uint256) {
        if (revenueShareTokenId == 0 || revenueShareTokenId % 2 != 0 || revenueShareTokenId >= _tokenIdCounter) {
            revert VehicleRegistry__IncorrectRevenueShareTokenId();
        }

        uint256 vehicleId = revenueShareTokenId - 1;
        VehicleLib.Vehicle storage vehicle = vehicles[vehicleId];
        if (!vehicle.isActive) {
            revert VehicleRegistry__VehicleDoesNotExist();
        }

        return vehicleId;
    }

    /**
     * @dev Get the revenue share token ID corresponding to a vehicle ID
     * Vehicle IDs are always odd, revenue share token IDs are always even (vehicleId + 1)
     */
    function getRevenueShareTokenIdFromVehicleId(uint256 vehicleId) public view returns (uint256) {
        if (vehicleId == 0 || vehicleId % 2 != 1 || vehicleId >= _tokenIdCounter) {
            revert VehicleRegistry__IncorrectVehicleId();
        }

        if (!vehicles[vehicleId].isActive) {
            revert VehicleRegistry__VehicleDoesNotExist();
        }

        return vehicleId + 1;
    }

    /**
     * @dev Check if a vehicle exists and is active
     */
    function vehicleExists(uint256 vehicleId) external view returns (bool) {
        return vehicles[vehicleId].isActive;
    }

    /**
     * @dev Get current token counter value
     */
    function getCurrentTokenId() external view returns (uint256) {
        return _tokenIdCounter;
    }

    // UUPS Upgrade authorization
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }
}
