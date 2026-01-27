// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title PartnerManager
 * @dev Manages authorized partners for the Roboshare protocol
 * Partners can register vehicles and participate in the ecosystem
 */
contract PartnerManager is Initializable, AccessControlUpgradeable, UUPSUpgradeable {
    bytes32 public constant PARTNER_ADMIN_ROLE = keccak256("PARTNER_ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // Partner state
    mapping(address => bool) private _authorizedPartners;
    mapping(address => string) private _partnerNames;
    mapping(address => uint256) private _partnerRegistrationTime;
    address[] private _allPartners;

    // Errors
    error ZeroAddress();
    error AlreadyAuthorized();
    error EmptyName();
    error UnauthorizedPartner();

    // Events
    event PartnerAuthorized(address indexed partner, string name);
    event PartnerRevoked(address indexed partner);
    event PartnerNameUpdated(address indexed partner, string newName);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address defaultAdmin) public initializer {
        if (defaultAdmin == address(0)) revert ZeroAddress();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PARTNER_ADMIN_ROLE, defaultAdmin);
        _grantRole(UPGRADER_ROLE, defaultAdmin);
    }

    /**
     * @dev Authorize a new partner
     * @param partner Address of the partner to authorize
     * @param name Name of the partner organization
     */
    function authorizePartner(address partner, string calldata name) external onlyRole(PARTNER_ADMIN_ROLE) {
        if (partner == address(0)) revert ZeroAddress();
        if (bytes(name).length == 0) revert EmptyName();
        if (_authorizedPartners[partner]) {
            revert AlreadyAuthorized();
        }

        _authorizedPartners[partner] = true;
        _partnerNames[partner] = name;
        _partnerRegistrationTime[partner] = block.timestamp;
        _allPartners.push(partner);

        emit PartnerAuthorized(partner, name);
    }

    /**
     * @dev Revoke partner authorization
     * @param partner Address of the partner to revoke
     */
    function revokePartner(address partner) external onlyRole(PARTNER_ADMIN_ROLE) {
        if (!_authorizedPartners[partner]) {
            revert UnauthorizedPartner();
        }

        _authorizedPartners[partner] = false;
        delete _partnerNames[partner];
        delete _partnerRegistrationTime[partner];

        // Remove from array
        for (uint256 i = 0; i < _allPartners.length; i++) {
            if (_allPartners[i] == partner) {
                _allPartners[i] = _allPartners[_allPartners.length - 1];
                _allPartners.pop();
                break;
            }
        }

        emit PartnerRevoked(partner);
    }

    /**
     * @dev Update partner name
     * @param partner Address of the partner
     * @param newName New name for the partner
     */
    function updatePartnerName(address partner, string calldata newName) external onlyRole(PARTNER_ADMIN_ROLE) {
        if (!_authorizedPartners[partner]) {
            revert UnauthorizedPartner();
        }
        if (bytes(newName).length == 0) revert EmptyName();

        _partnerNames[partner] = newName;
        emit PartnerNameUpdated(partner, newName);
    }

    /**
     * @dev Check if an address is an authorized partner
     * @param partner Address to check
     * @return True if partner is authorized
     */
    function isAuthorizedPartner(address partner) external view returns (bool) {
        return _authorizedPartners[partner];
    }

    /**
     * @dev Get partner name
     * @param partner Address of the partner
     * @return Name of the partner
     */
    function getPartnerName(address partner) external view returns (string memory) {
        return _partnerNames[partner];
    }

    /**
     * @dev Get partner registration time
     * @param partner Address of the partner
     * @return Timestamp when partner was registered
     */
    function getPartnerRegistrationTime(address partner) external view returns (uint256) {
        return _partnerRegistrationTime[partner];
    }

    /**
     * @dev Get all authorized partners
     * @return Array of all partner addresses
     */
    function getAllPartners() external view returns (address[] memory) {
        return _allPartners;
    }

    /**
     * @dev Get number of authorized partners
     * @return Count of authorized partners
     */
    function getPartnerCount() external view returns (uint256) {
        return _allPartners.length;
    }

    /**
     * @dev Get partner info
     * @param partner Address of the partner
     * @return name Partner name
     * @return registrationTime When partner was registered
     * @return isAuthorized Current authorization status
     */
    function getPartnerInfo(address partner)
        external
        view
        returns (string memory name, uint256 registrationTime, bool isAuthorized)
    {
        return (_partnerNames[partner], _partnerRegistrationTime[partner], _authorizedPartners[partner]);
    }

    /**
     * @dev Modifier to check if caller is authorized partner
     */
    modifier onlyAuthorizedPartner() {
        _onlyAuthorizedPartner();
        _;
    }

    function _onlyAuthorizedPartner() internal view {
        if (!_authorizedPartners[msg.sender]) {
            revert UnauthorizedPartner();
        }
    }

    /**
     * @dev Required override for UUPS upgrades
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }
}
