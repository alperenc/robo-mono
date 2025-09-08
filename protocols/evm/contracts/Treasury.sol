// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./Libraries.sol";
import "./PartnerManager.sol";
import "./VehicleRegistry.sol";

// Treasury errors
error Treasury__UnauthorizedPartner();
error Treasury__NoCollateralLocked();
error Treasury__CollateralAlreadyLocked();
error Treasury__IncorrectCollateralAmount();
error Treasury__InsufficientCollateral();
error Treasury__NotAPartnerVehicle();
error Treasury__ZeroAddressNotAllowed();
error Treasury__TransferFailed();
error Treasury__ExistingOutstandingRevenueTokens();
error Treasury__VehicleNotFound();

/**
 * @dev Treasury contract for USDC-based collateral management
 * Phase 1: Collateral locking functionality for vehicle registration
 */
contract Treasury is Initializable, AccessControlUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    using CollateralLib for CollateralLib.CollateralInfo;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant TREASURER_ROLE = keccak256("TREASURER_ROLE");

    // Core contracts
    PartnerManager public partnerManager;
    VehicleRegistry public vehicleRegistry;
    IERC20 public usdc;

    // Collateral storage - vehicleId => CollateralInfo
    mapping(uint256 => CollateralLib.CollateralInfo) public vehicleCollateral;
    
    // Partner pending withdrawals
    mapping(address => uint256) public pendingWithdrawals;
    
    // Treasury state
    uint256 public totalCollateralDeposited;

    // Events
    event CollateralLocked(uint256 indexed vehicleId, address indexed partner, uint256 amount);
    event CollateralUnlocked(uint256 indexed vehicleId, address indexed partner, uint256 amount);
    event WithdrawalProcessed(address indexed recipient, uint256 amount);

    /**
     * @dev Modifier to restrict access to authorized partners
     */
    modifier onlyAuthorizedPartner() {
        if (!partnerManager.isAuthorizedPartner(msg.sender)) {
            revert Treasury__UnauthorizedPartner();
        }
        _;
    }

    /**
     * @dev Initialize Treasury with core contract references
     */
    function initialize(
        address _admin,
        address _partnerManager,
        address _vehicleRegistry,
        address _usdc
    ) public initializer {
        if (_admin == address(0) || _partnerManager == address(0) || 
            _vehicleRegistry == address(0) || _usdc == address(0)) {
            revert Treasury__ZeroAddressNotAllowed();
        }

        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
        _grantRole(TREASURER_ROLE, _admin);

        partnerManager = PartnerManager(_partnerManager);
        vehicleRegistry = VehicleRegistry(_vehicleRegistry);
        usdc = IERC20(_usdc);
    }

    // Collateral Locking Functions

    /**
     * @dev Lock USDC collateral for vehicle registration
     * Note: Partner must approve Treasury to spend USDC before calling this function
     * @param vehicleId The ID of the vehicle to lock collateral for
     * @param revenueTokenPrice Price per revenue share token in USDC (with decimals)
     * @param totalRevenueTokens Total number of revenue share tokens to be issued
     */
    function lockCollateral(
        uint256 vehicleId, 
        uint256 revenueTokenPrice, 
        uint256 totalRevenueTokens
    ) external onlyAuthorizedPartner nonReentrant {
        // Verify vehicle exists and caller owns it
        if (!vehicleRegistry.vehicleExists(vehicleId)) {
            revert Treasury__VehicleNotFound();
        }

        CollateralLib.CollateralInfo storage collateralInfo = vehicleCollateral[vehicleId];
        
        // Check if collateral is already locked
        if (collateralInfo.isLocked) {
            revert Treasury__CollateralAlreadyLocked();
        }

        // Initialize or update collateral info
        if (!CollateralLib.isInitialized(collateralInfo)) {
            CollateralLib.initializeCollateralInfo(
                collateralInfo, 
                revenueTokenPrice, 
                totalRevenueTokens, 
                ProtocolLib.QUARTERLY_INTERVAL
            );
        }

        uint256 requiredCollateral = collateralInfo.totalCollateral;

        // Transfer USDC from partner to treasury (requires prior approval)
        usdc.safeTransferFrom(msg.sender, address(this), requiredCollateral);

        // Lock the collateral
        collateralInfo.isLocked = true;
        collateralInfo.lockedAt = block.timestamp;

        totalCollateralDeposited += requiredCollateral;

        emit CollateralLocked(vehicleId, msg.sender, requiredCollateral);
    }

    /**
     * @dev Unlock collateral for vehicle (Phase 1: simplified version)
     * @param vehicleId The ID of the vehicle to unlock collateral for
     */
    function unlockCollateral(uint256 vehicleId) external onlyAuthorizedPartner nonReentrant {
        // Verify vehicle exists
        if (!vehicleRegistry.vehicleExists(vehicleId)) {
            revert Treasury__VehicleNotFound();
        }

        CollateralLib.CollateralInfo storage collateralInfo = vehicleCollateral[vehicleId];
        
        if (!collateralInfo.isLocked) {
            revert Treasury__NoCollateralLocked();
        }

        uint256 collateralAmount = collateralInfo.totalCollateral;

        // Unlock the collateral
        collateralInfo.isLocked = false;
        collateralInfo.lockedAt = 0;

        // Add to pending withdrawals instead of direct transfer
        pendingWithdrawals[msg.sender] += collateralAmount;
        totalCollateralDeposited -= collateralAmount;

        emit CollateralUnlocked(vehicleId, msg.sender, collateralAmount);
    }

    /**
     * @dev Process withdrawal from pending withdrawals
     */
    function processWithdrawal() external nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) {
            revert Treasury__InsufficientCollateral();
        }

        pendingWithdrawals[msg.sender] = 0;

        // Transfer USDC back to partner
        usdc.safeTransfer(msg.sender, amount);

        emit WithdrawalProcessed(msg.sender, amount);
    }

    // View Functions

    /**
     * @dev Get collateral requirement for specific revenue token parameters
     * @param revenueTokenPrice Price per revenue share token in USDC
     * @param totalRevenueTokens Total number of revenue share tokens
     * @return Total collateral requirement in USDC
     */
    function getCollateralRequirement(
        uint256 revenueTokenPrice, 
        uint256 totalRevenueTokens
    ) external pure returns (uint256) {
        return CollateralLib.calculateCollateralRequirement(
            revenueTokenPrice, 
            totalRevenueTokens, 
            ProtocolLib.QUARTERLY_INTERVAL
        );
    }

    /**
     * @dev Get collateral breakdown for display purposes
     * @param revenueTokenPrice Price per revenue share token in USDC
     * @param totalRevenueTokens Total number of revenue share tokens
     * @return baseAmount Base collateral amount
     * @return earningsBuffer Earnings buffer amount  
     * @return protocolBuffer Protocol buffer amount
     * @return totalRequired Total collateral required
     */
    function getCollateralBreakdown(
        uint256 revenueTokenPrice,
        uint256 totalRevenueTokens
    ) external pure returns (
        uint256 baseAmount,
        uint256 earningsBuffer,
        uint256 protocolBuffer,
        uint256 totalRequired
    ) {
        return CollateralLib.getCollateralBreakdown(
            revenueTokenPrice, 
            totalRevenueTokens, 
            ProtocolLib.QUARTERLY_INTERVAL
        );
    }

    /**
     * @dev Get vehicle's collateral information
     * @param vehicleId The ID of the vehicle
     * @return baseCollateral Base collateral amount
     * @return totalCollateral Total collateral amount
     * @return isLocked Whether collateral is locked
     * @return lockedAt Timestamp when locked
     * @return lockDuration Duration since lock in seconds
     */
    function getVehicleCollateralInfo(uint256 vehicleId) 
        external 
        view 
        returns (
            uint256 baseCollateral,
            uint256 totalCollateral,
            bool isLocked,
            uint256 lockedAt,
            uint256 lockDuration
        )
    {
        CollateralLib.CollateralInfo storage info = vehicleCollateral[vehicleId];
        return (
            info.baseCollateral,
            info.totalCollateral,
            info.isLocked,
            info.lockedAt,
            CollateralLib.getLockDuration(info)
        );
    }

    /**
     * @dev Get pending withdrawal amount for an address
     * @param account The account to check
     * @return Pending withdrawal amount
     */
    function getPendingWithdrawal(address account) external view returns (uint256) {
        return pendingWithdrawals[account];
    }

    /**
     * @dev Get treasury statistics
     * @return totalDeposited Total collateral deposited
     * @return treasuryBalance Current USDC balance
     */
    function getTreasuryStats() external view returns (uint256 totalDeposited, uint256 treasuryBalance) {
        return (totalCollateralDeposited, usdc.balanceOf(address(this)));
    }

    // Admin Functions

    /**
     * @dev Update partner manager reference
     * @param _partnerManager New partner manager address
     */
    function updatePartnerManager(address _partnerManager) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_partnerManager == address(0)) {
            revert Treasury__ZeroAddressNotAllowed();
        }
        partnerManager = PartnerManager(_partnerManager);
    }

    /**
     * @dev Update vehicle registry reference
     * @param _vehicleRegistry New vehicle registry address
     */
    function updateVehicleRegistry(address _vehicleRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_vehicleRegistry == address(0)) {
            revert Treasury__ZeroAddressNotAllowed();
        }
        vehicleRegistry = VehicleRegistry(_vehicleRegistry);
    }

    /**
     * @dev Update USDC token reference
     * @param _usdc New USDC token address
     */
    function updateUSDC(address _usdc) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_usdc == address(0)) {
            revert Treasury__ZeroAddressNotAllowed();
        }
        usdc = IERC20(_usdc);
    }

    // UUPS Upgrade authorization
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}