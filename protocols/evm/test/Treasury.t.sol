// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/Treasury.sol";
import "../contracts/RoboshareTokens.sol";
import "../contracts/PartnerManager.sol";
import "../contracts/VehicleRegistry.sol";
import "../contracts/Libraries.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock USDC contract for testing
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}
    
    function decimals() public pure override returns (uint8) {
        return 6;
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract TreasuryTest is Test {
    Treasury public treasury;
    Treasury public treasuryImplementation;
    RoboshareTokens public roboshareTokens;
    RoboshareTokens public tokenImplementation;
    PartnerManager public partnerManager;
    PartnerManager public partnerImplementation;
    VehicleRegistry public vehicleRegistry;
    VehicleRegistry public vehicleImplementation;
    MockUSDC public usdc;

    address public admin = makeAddr("admin");
    address public partner1 = makeAddr("partner1"); // Fleet operator 1
    address public partner2 = makeAddr("partner2"); // Fleet operator 2
    address public unauthorized = makeAddr("unauthorized");

    // Test constants
    string constant PARTNER1_NAME = "RideShare Fleet Co.";
    string constant PARTNER2_NAME = "Urban Delivery Services";
    string constant TEST_VIN = "1HGCM82633A123456";
    string constant TEST_MAKE = "Honda";
    string constant TEST_MODEL = "Civic";
    uint256 constant TEST_YEAR = 2024;
    uint256 constant TEST_MANUFACTURER_ID = 1;
    string constant TEST_OPTION_CODES = "EX-L,NAV,HSS";
    string constant TEST_METADATA_URI = "ipfs://QmTestHash123456789abcdefghijklmnopqrstuvwxyzABC";

    // Collateral test constants (USDC has 6 decimals)
    uint256 constant REVENUE_TOKEN_PRICE = 100 * 1e6; // $100 in USDC
    uint256 constant TOTAL_REVENUE_TOKENS = 10;
    uint256 constant BASE_COLLATERAL = REVENUE_TOKEN_PRICE * TOTAL_REVENUE_TOKENS; // $1000
    
    // Role constants
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    function setUp() public {
        // Deploy USDC mock
        usdc = new MockUSDC();

        // Deploy RoboshareTokens
        tokenImplementation = new RoboshareTokens();
        bytes memory tokenInitData = abi.encodeWithSignature("initialize(address)", admin);
        ERC1967Proxy tokenProxy = new ERC1967Proxy(address(tokenImplementation), tokenInitData);
        roboshareTokens = RoboshareTokens(address(tokenProxy));

        // Deploy PartnerManager
        partnerImplementation = new PartnerManager();
        bytes memory partnerInitData = abi.encodeWithSignature("initialize(address)", admin);
        ERC1967Proxy partnerProxy = new ERC1967Proxy(address(partnerImplementation), partnerInitData);
        partnerManager = PartnerManager(address(partnerProxy));

        // Deploy VehicleRegistry
        vehicleImplementation = new VehicleRegistry();
        bytes memory vehicleInitData = abi.encodeWithSignature(
            "initialize(address,address,address)", admin, address(roboshareTokens), address(partnerManager)
        );
        ERC1967Proxy vehicleProxy = new ERC1967Proxy(address(vehicleImplementation), vehicleInitData);
        vehicleRegistry = VehicleRegistry(address(vehicleProxy));

        // Deploy Treasury
        treasuryImplementation = new Treasury();
        bytes memory treasuryInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address)", 
            admin, 
            address(partnerManager), 
            address(vehicleRegistry),
            address(usdc)
        );
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(address(treasuryImplementation), treasuryInitData);
        treasury = Treasury(address(treasuryProxy));

        // Setup roles and permissions
        vm.startPrank(admin);
        // Grant MINTER_ROLE to VehicleRegistry for token operations
        roboshareTokens.grantRole(MINTER_ROLE, address(vehicleRegistry));
        // Authorize partners (fleet operators)
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);
        partnerManager.authorizePartner(partner2, PARTNER2_NAME);
        vm.stopPrank();

        // Mint USDC to partners for testing
        usdc.mint(partner1, 10000 * 1e6); // $10,000
        usdc.mint(partner2, 10000 * 1e6); // $10,000
    }

    // Initialization Tests

    function testInitialization() public view {
        // Check contract references
        assertEq(address(treasury.partnerManager()), address(partnerManager));
        assertEq(address(treasury.vehicleRegistry()), address(vehicleRegistry));
        assertEq(address(treasury.usdc()), address(usdc));

        // Check initial state
        assertEq(treasury.totalCollateralDeposited(), 0);

        // Check admin roles
        assertTrue(treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(treasury.hasRole(treasury.UPGRADER_ROLE(), admin));
        assertTrue(treasury.hasRole(treasury.TREASURER_ROLE(), admin));
    }

    function testInitializationWithZeroAddressesFails() public {
        Treasury newTreasury = new Treasury();
        
        // Test zero admin
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        newTreasury.initialize(address(0), address(partnerManager), address(vehicleRegistry), address(usdc));
        
        // Test zero partner manager
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        newTreasury.initialize(admin, address(0), address(vehicleRegistry), address(usdc));
        
        // Test zero vehicle registry
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        newTreasury.initialize(admin, address(partnerManager), address(0), address(usdc));
        
        // Test zero USDC
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        newTreasury.initialize(admin, address(partnerManager), address(vehicleRegistry), address(0));
    }

    // Collateral Calculation Tests

    function testGetCollateralRequirement() public view {
        uint256 requirement = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        
        // Time-based calculation:
        // Base: $1000
        // Expected quarterly earnings: $1000 * 90 days / 365 days = ~$246.58
        // Earnings buffer: $246.58 * 10% = ~$24.66
        // Protocol buffer: $246.58 * 5% = ~$12.33
        // Total: $1000 + $24.66 + $12.33 = ~$1036.99
        uint256 baseAmount = BASE_COLLATERAL;
        uint256 expectedQuarterlyEarnings = (baseAmount * 90 days) / 365 days;
        uint256 earningsBuffer = (expectedQuarterlyEarnings * 1000) / 10000; // 10%
        uint256 protocolBuffer = (expectedQuarterlyEarnings * 500) / 10000;  // 5%
        uint256 expectedTotal = baseAmount + earningsBuffer + protocolBuffer;
        
        assertEq(requirement, expectedTotal);
    }

    function testGetCollateralBreakdown() public view {
        (uint256 base, uint256 earnings, uint256 protocol, uint256 total) = 
            treasury.getCollateralBreakdown(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        
        // Time-based calculation components
        uint256 expectedQuarterlyEarnings = (BASE_COLLATERAL * 90 days) / 365 days;
        uint256 expectedEarningsBuffer = (expectedQuarterlyEarnings * 1000) / 10000; // 10%
        uint256 expectedProtocolBuffer = (expectedQuarterlyEarnings * 500) / 10000;  // 5%
        
        assertEq(base, BASE_COLLATERAL);
        assertEq(earnings, expectedEarningsBuffer);
        assertEq(protocol, expectedProtocolBuffer);
        assertEq(total, base + earnings + protocol);
    }

    // Helper function to register vehicle and approve USDC
    function _setupVehicleAndApproval(address partner) internal returns (uint256 vehicleId) {
        // Register vehicle
        vm.prank(partner);
        vehicleId = vehicleRegistry.registerVehicle(
            TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        // Calculate required collateral and approve Treasury
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.prank(partner);
        usdc.approve(address(treasury), requiredCollateral);
        
        return vehicleId;
    }

    // Collateral Locking Tests

    function testLockCollateral() public {
        uint256 vehicleId = _setupVehicleAndApproval(partner1);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        
        uint256 initialBalance = usdc.balanceOf(partner1);
        uint256 initialTreasuryBalance = usdc.balanceOf(address(treasury));

        vm.prank(partner1);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Check USDC transfers
        assertEq(usdc.balanceOf(partner1), initialBalance - requiredCollateral);
        assertEq(usdc.balanceOf(address(treasury)), initialTreasuryBalance + requiredCollateral);

        // Check collateral info
        (uint256 base, uint256 total, bool locked, uint256 lockedAt, uint256 duration) = 
            treasury.getVehicleCollateralInfo(vehicleId);
        
        assertEq(base, BASE_COLLATERAL);
        assertEq(total, requiredCollateral);
        assertTrue(locked);
        assertEq(lockedAt, block.timestamp);
        assertEq(duration, 0); // Just locked

        // Check treasury state
        assertEq(treasury.totalCollateralDeposited(), requiredCollateral);
    }

    function testLockCollateralEmitsEvent() public {
        uint256 vehicleId = _setupVehicleAndApproval(partner1);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        vm.expectEmit(true, true, false, true);
        emit CollateralLocked(vehicleId, partner1, requiredCollateral);

        vm.prank(partner1);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
    }

    function testLockCollateralForNonexistentVehicleFails() public {
        uint256 nonexistentVehicleId = 999;
        
        vm.prank(partner1);
        usdc.approve(address(treasury), 1000 * 1e6);

        vm.expectRevert(Treasury__VehicleNotFound.selector);
        vm.prank(partner1);
        treasury.lockCollateral(nonexistentVehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
    }

    function testLockCollateralAlreadyLockedFails() public {
        uint256 vehicleId = _setupVehicleAndApproval(partner1);

        // Lock collateral first time
        vm.prank(partner1);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Try to lock again - should fail
        vm.prank(partner1);
        usdc.approve(address(treasury), treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS));
        
        vm.expectRevert(Treasury__CollateralAlreadyLocked.selector);
        vm.prank(partner1);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
    }

    function testLockCollateralWithoutApprovalFails() public {
        uint256 vehicleId = _setupVehicleAndApproval(partner1);

        // Clear approval
        vm.prank(partner1);
        usdc.approve(address(treasury), 0);

        vm.expectRevert();
        vm.prank(partner1);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
    }

    function testLockCollateralInsufficientApprovalFails() public {
        uint256 vehicleId = _setupVehicleAndApproval(partner1);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Approve less than required
        vm.prank(partner1);
        usdc.approve(address(treasury), requiredCollateral - 1);

        vm.expectRevert();
        vm.prank(partner1);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
    }

    // Collateral Unlocking Tests

    function testUnlockCollateral() public {
        uint256 vehicleId = _setupVehicleAndApproval(partner1);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Lock collateral first
        vm.prank(partner1);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Unlock collateral
        vm.prank(partner1);
        treasury.unlockCollateral(vehicleId);

        // Check collateral info
        (,, bool locked,,) = treasury.getVehicleCollateralInfo(vehicleId);
        assertFalse(locked);

        // Check pending withdrawal
        assertEq(treasury.getPendingWithdrawal(partner1), requiredCollateral);
        assertEq(treasury.totalCollateralDeposited(), 0);
    }

    function testUnlockCollateralEmitsEvent() public {
        uint256 vehicleId = _setupVehicleAndApproval(partner1);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Lock first
        vm.prank(partner1);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        vm.expectEmit(true, true, false, true);
        emit CollateralUnlocked(vehicleId, partner1, requiredCollateral);

        vm.prank(partner1);
        treasury.unlockCollateral(vehicleId);
    }

    function testUnlockCollateralNotLockedFails() public {
        uint256 vehicleId = _setupVehicleAndApproval(partner1);

        vm.expectRevert(Treasury__NoCollateralLocked.selector);
        vm.prank(partner1);
        treasury.unlockCollateral(vehicleId);
    }

    function testUnlockCollateralNonexistentVehicleFails() public {
        uint256 nonexistentVehicleId = 999;

        vm.expectRevert(Treasury__VehicleNotFound.selector);
        vm.prank(partner1);
        treasury.unlockCollateral(nonexistentVehicleId);
    }

    // Withdrawal Tests

    function testProcessWithdrawal() public {
        uint256 vehicleId = _setupVehicleAndApproval(partner1);
        uint256 initialBalance = usdc.balanceOf(partner1);

        // Lock and unlock collateral
        vm.prank(partner1);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        
        vm.prank(partner1);
        treasury.unlockCollateral(vehicleId);

        // Process withdrawal
        vm.prank(partner1);
        treasury.processWithdrawal();

        // Check balances
        assertEq(usdc.balanceOf(partner1), initialBalance);
        assertEq(treasury.getPendingWithdrawal(partner1), 0);
    }

    function testProcessWithdrawalEmitsEvent() public {
        uint256 vehicleId = _setupVehicleAndApproval(partner1);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Setup pending withdrawal
        vm.prank(partner1);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.prank(partner1);
        treasury.unlockCollateral(vehicleId);

        vm.expectEmit(true, false, false, true);
        emit WithdrawalProcessed(partner1, requiredCollateral);

        vm.prank(partner1);
        treasury.processWithdrawal();
    }

    function testProcessWithdrawalNoPendingFails() public {
        vm.expectRevert(Treasury__InsufficientCollateral.selector);
        vm.prank(partner1);
        treasury.processWithdrawal();
    }

    // Access Control Tests

    function testUnauthorizedPartnerCannotLockCollateral() public {
        uint256 vehicleId = _setupVehicleAndApproval(partner1);

        vm.expectRevert(Treasury__UnauthorizedPartner.selector);
        vm.prank(unauthorized);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
    }

    function testUnauthorizedPartnerCannotUnlockCollateral() public {
        uint256 vehicleId = _setupVehicleAndApproval(partner1);

        vm.expectRevert(Treasury__UnauthorizedPartner.selector);
        vm.prank(unauthorized);
        treasury.unlockCollateral(vehicleId);
    }

    // View Functions Tests

    function testGetTreasuryStats() public {
        uint256 vehicleId = _setupVehicleAndApproval(partner1);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Initially empty
        (uint256 deposited, uint256 balance) = treasury.getTreasuryStats();
        assertEq(deposited, 0);
        assertEq(balance, 0);

        // After locking collateral
        vm.prank(partner1);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        (deposited, balance) = treasury.getTreasuryStats();
        assertEq(deposited, requiredCollateral);
        assertEq(balance, requiredCollateral);
    }

    function testGetVehicleCollateralInfoUninitialized() public {
        uint256 vehicleId = _setupVehicleAndApproval(partner1);

        (uint256 base, uint256 total, bool locked, uint256 lockedAt, uint256 duration) = 
            treasury.getVehicleCollateralInfo(vehicleId);

        assertEq(base, 0);
        assertEq(total, 0);
        assertFalse(locked);
        assertEq(lockedAt, 0);
        assertEq(duration, 0);
    }

    // Admin Functions Tests

    function testUpdatePartnerManager() public {
        PartnerManager newPartnerManager = new PartnerManager();

        vm.prank(admin);
        treasury.updatePartnerManager(address(newPartnerManager));

        assertEq(address(treasury.partnerManager()), address(newPartnerManager));
    }

    function testUpdatePartnerManagerZeroAddressFails() public {
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        vm.prank(admin);
        treasury.updatePartnerManager(address(0));
    }

    function testUpdatePartnerManagerUnauthorizedFails() public {
        PartnerManager newPartnerManager = new PartnerManager();

        vm.expectRevert();
        vm.prank(unauthorized);
        treasury.updatePartnerManager(address(newPartnerManager));
    }

    function testUpdateVehicleRegistry() public {
        VehicleRegistry newRegistry = new VehicleRegistry();

        vm.prank(admin);
        treasury.updateVehicleRegistry(address(newRegistry));

        assertEq(address(treasury.vehicleRegistry()), address(newRegistry));
    }

    function testUpdateUSDC() public {
        MockUSDC newUSDC = new MockUSDC();

        vm.prank(admin);
        treasury.updateUSDC(address(newUSDC));

        assertEq(address(treasury.usdc()), address(newUSDC));
    }

    // Integration Tests

    function testMultipleVehicleCollateralLocking() public {
        // Register multiple vehicles
        vm.prank(partner1);
        uint256 vehicleId1 = vehicleRegistry.registerVehicle(
            TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        vm.prank(partner2);
        uint256 vehicleId2 = vehicleRegistry.registerVehicle(
            "2HGCM82633A654321", "Toyota", "Camry", 2023, 2, "LE", TEST_METADATA_URI
        );

        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Approve and lock collateral for both vehicles
        vm.prank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        vm.prank(partner1);
        treasury.lockCollateral(vehicleId1, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        vm.prank(partner2);
        usdc.approve(address(treasury), requiredCollateral);
        vm.prank(partner2);
        treasury.lockCollateral(vehicleId2, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Check treasury state
        assertEq(treasury.totalCollateralDeposited(), requiredCollateral * 2);
        
        // Check individual collateral states
        (,, bool locked1,,) = treasury.getVehicleCollateralInfo(vehicleId1);
        (,, bool locked2,,) = treasury.getVehicleCollateralInfo(vehicleId2);
        assertTrue(locked1);
        assertTrue(locked2);
    }

    function testCompleteCollateralLifecycle() public {
        uint256 vehicleId = _setupVehicleAndApproval(partner1);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        uint256 initialBalance = usdc.balanceOf(partner1);

        // 1. Lock collateral
        vm.prank(partner1);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        assertEq(usdc.balanceOf(partner1), initialBalance - requiredCollateral);

        // 2. Unlock collateral  
        vm.prank(partner1);
        treasury.unlockCollateral(vehicleId);
        assertEq(treasury.getPendingWithdrawal(partner1), requiredCollateral);

        // 3. Process withdrawal
        vm.prank(partner1);
        treasury.processWithdrawal();
        assertEq(usdc.balanceOf(partner1), initialBalance);
        assertEq(treasury.getPendingWithdrawal(partner1), 0);
    }

    // Events
    event CollateralLocked(uint256 indexed vehicleId, address indexed partner, uint256 amount);
    event CollateralUnlocked(uint256 indexed vehicleId, address indexed partner, uint256 amount);
    event WithdrawalProcessed(address indexed recipient, uint256 amount);
}