// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";

contract TreasuryTest is BaseTest {
    uint256 constant BASE_COLLATERAL = REVENUE_TOKEN_PRICE * TOTAL_REVENUE_TOKENS;

    function setUp() public {
        _ensureState(SetupState.ContractsDeployed);
        // Explicitly set the partner manager again to be sure
        vm.startPrank(admin);
        treasury.updatePartnerManager(address(partnerManager));
        vm.stopPrank();
    }

    // Initialization Tests

    function testInitialization() public view {
        // Check contract references
        assertEq(address(treasury.partnerManager()), address(partnerManager));
        assertEq(address(treasury.assetRegistry()), address(vehicleRegistry));
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
        newTreasury.initialize(
            address(0),
            address(partnerManager),
            address(vehicleRegistry),
            address(roboshareTokens),
            address(usdc),
            config.treasuryFeeRecipient
        );

        // Test zero partner manager
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        newTreasury.initialize(
            admin,
            address(0),
            address(vehicleRegistry),
            address(roboshareTokens),
            address(usdc),
            config.treasuryFeeRecipient
        );

        // Test zero vehicle registry
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        newTreasury.initialize(
            admin,
            address(partnerManager),
            address(0),
            address(roboshareTokens),
            address(usdc),
            config.treasuryFeeRecipient
        );

        // Test zero USDC
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        newTreasury.initialize(
            admin,
            address(partnerManager),
            address(vehicleRegistry),
            address(roboshareTokens),
            address(0),
            config.treasuryFeeRecipient
        );

        // Test zero treasury fee recipient
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        newTreasury.initialize(
            admin,
            address(partnerManager),
            address(vehicleRegistry),
            address(roboshareTokens),
            address(usdc),
            address(0)
        );
    }

    // Collateral Calculation Tests

    function testGetCollateralRequirement() public view {
        uint256 requirement = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        uint256 baseAmount = BASE_COLLATERAL;
        uint256 expectedQuarterlyEarnings = (baseAmount * 90 days) / 365 days;
        uint256 earningsBuffer = (expectedQuarterlyEarnings * 1000) / 10000; // 10%
        uint256 protocolBuffer = (expectedQuarterlyEarnings * 500) / 10000; // 5%
        uint256 expectedTotal = baseAmount + earningsBuffer + protocolBuffer;

        assertEq(requirement, expectedTotal);
    }

    function testGetCollateralBreakdown() public view {
        (uint256 base, uint256 earnings, uint256 protocol, uint256 total) =
            treasury.getCollateralBreakdown(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        uint256 expectedQuarterlyEarnings = (BASE_COLLATERAL * 90 days) / 365 days;
        uint256 expectedEarningsBuffer = (expectedQuarterlyEarnings * 1000) / 10000; // 10%
        uint256 expectedProtocolBuffer = (expectedQuarterlyEarnings * 500) / 10000; // 5%

        assertEq(base, BASE_COLLATERAL);
        assertEq(earnings, expectedEarningsBuffer);
        assertEq(protocol, expectedProtocolBuffer);
        assertEq(total, base + earnings + protocol);
    }

    // Collateral Locking Tests

    function testLockCollateral() public {
        _ensureState(SetupState.VehicleRegistered);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        uint256 initialBalance = usdc.balanceOf(partner1);
        uint256 initialTreasuryBalance = usdc.balanceOf(address(treasury));

        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();

        // Check USDC transfers
        assertEq(usdc.balanceOf(partner1), initialBalance - requiredCollateral);
        assertEq(usdc.balanceOf(address(treasury)), initialTreasuryBalance + requiredCollateral);

        // Check collateral info
        (uint256 base, uint256 total, bool locked, uint256 lockedAt, uint256 duration) =
            treasury.getAssetCollateralInfo(vehicleId);

        assertEq(base, BASE_COLLATERAL);
        assertEq(total, requiredCollateral);
        assertTrue(locked);
        assertEq(lockedAt, block.timestamp);
        assertEq(duration, 0); // Just locked

        // Check treasury state
        assertEq(treasury.totalCollateralDeposited(), requiredCollateral);
    }

    function testLockCollateralEmitsEvent() public {
        _ensureState(SetupState.VehicleRegistered);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);

        vm.expectEmit(true, true, false, true);
        emit Treasury.CollateralLocked(vehicleId, partner1, requiredCollateral);

        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();
    }

    function testLockCollateralForNonexistentVehicleFails() public {
        uint256 nonexistentVehicleId = 999;

        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000 * 1e6);

        vm.expectRevert(Treasury__VehicleNotFound.selector);
        treasury.lockCollateral(nonexistentVehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();
    }

    function testLockCollateralAlreadyLockedFails() public {
        _ensureState(SetupState.VehicleRegistered);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Lock collateral first time
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();

        // Try to lock again - should fail
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);

        vm.expectRevert(Treasury__CollateralAlreadyLocked.selector);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();
    }

    function testLockCollateralWithoutApprovalFails() public {
        _ensureState(SetupState.VehicleRegistered);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Clear approval
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 0);

        vm.expectRevert();
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();
    }

    function testLockCollateralInsufficientApprovalFails() public {
        _ensureState(SetupState.VehicleRegistered);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Approve less than required
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral - 1);

        vm.expectRevert();
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();
    }

    // Collateral Unlocking Tests

    function testUnlockCollateral() public {
        _ensureState(SetupState.CollateralLockedAndListed);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Unlock collateral
        vm.startPrank(partner1);
        treasury.releaseCollateral(vehicleId);
        vm.stopPrank();

        // Check collateral info
        (,, bool locked,,) = treasury.getAssetCollateralInfo(vehicleId);
        assertFalse(locked);

        // Check pending withdrawal
        assertEq(treasury.getPendingWithdrawal(partner1), requiredCollateral);
        assertEq(treasury.totalCollateralDeposited(), 0);
    }

    function testUnlockCollateralEmitsEvent() public {
        _ensureState(SetupState.CollateralLockedAndListed);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        vm.startPrank(partner1);
        vm.expectEmit(true, true, false, true);
        emit Treasury.CollateralReleased(vehicleId, partner1, requiredCollateral);

        treasury.releaseCollateral(vehicleId);
        vm.stopPrank();
    }

    function testUnlockCollateralNotLockedFails() public {
        _ensureState(SetupState.VehicleRegistered);

        vm.expectRevert(Treasury__NoCollateralLocked.selector);
        vm.startPrank(partner1);
        treasury.releaseCollateral(vehicleId);
        vm.stopPrank();
    }

    function testUnlockCollateralNonexistentVehicleFails() public {
        uint256 nonexistentVehicleId = 999;

        vm.expectRevert(Treasury__VehicleNotFound.selector);
        vm.startPrank(partner1);
        treasury.releaseCollateral(nonexistentVehicleId);
        vm.stopPrank();
    }

    // Withdrawal Tests

    function testProcessWithdrawal() public {
        _ensureState(SetupState.VehicleRegistered);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        uint256 initialBalance = usdc.balanceOf(partner1);

        // Lock collateral
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();

        // Unlock collateral
        vm.startPrank(partner1);
        treasury.releaseCollateral(vehicleId);
        vm.stopPrank();

        // Process withdrawal
        vm.startPrank(partner1);
        treasury.processWithdrawal();
        vm.stopPrank();

        // Check balances
        assertEq(usdc.balanceOf(partner1), initialBalance); // Should be back to initial balance
        assertEq(treasury.getPendingWithdrawal(partner1), 0);
    }

    function testProcessWithdrawalEmitsEvent() public {
        _ensureState(SetupState.CollateralLockedAndListed);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Unlock collateral
        vm.startPrank(partner1);
        treasury.releaseCollateral(vehicleId);
        vm.stopPrank();

        vm.expectEmit(true, false, false, true);
        emit Treasury.WithdrawalProcessed(partner1, requiredCollateral);

        vm.startPrank(partner1);
        treasury.processWithdrawal();
        vm.stopPrank();
    }

    function testProcessWithdrawalNoPendingFails() public {
        vm.expectRevert(Treasury__InsufficientCollateral.selector);
        vm.startPrank(partner1);
        treasury.processWithdrawal();
        vm.stopPrank();
    }

    // Access Control Tests

    function testUnauthorizedPartnerCannotLockCollateral() public {
        // Manually register a vehicle with partner1
        vm.startPrank(partner1);
        uint256 registeredVehicleId = vehicleRegistry.registerVehicle(
            "TEMP_VIN_12345678",
            TEST_MAKE,
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            TEST_METADATA_URI
        );
        vm.stopPrank();

        vm.startPrank(unauthorized);
        usdc.approve(address(treasury), 1000 * 1e6); // Approve some amount
        vm.expectRevert(Treasury__UnauthorizedPartner.selector);
        treasury.lockCollateral(registeredVehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();
    }

    function testUnauthorizedPartnerCannotUnlockCollateral() public {
        _ensureState(SetupState.CollateralLockedAndListed);

        vm.expectRevert(Treasury__UnauthorizedPartner.selector);
        vm.prank(unauthorized);
        treasury.releaseCollateral(vehicleId);
    }

    // View Functions Tests

    function testGetTreasuryStats() public {
        _ensureState(SetupState.VehicleRegistered);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Initially empty
        (uint256 deposited, uint256 balance) = treasury.getTreasuryStats();
        assertEq(deposited, 0);
        assertEq(balance, 0);

        // After locking collateral
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();

        (deposited, balance) = treasury.getTreasuryStats();
        assertEq(deposited, requiredCollateral);
        assertEq(balance, requiredCollateral);
    }

    function testGetVehicleCollateralInfoUninitialized() public {
        _ensureState(SetupState.ContractsDeployed);
        // Register a vehicle without locking collateral
        vm.startPrank(partner1);
        uint256 newVehicleId = vehicleRegistry.registerVehicle(
            "NEWVIN123456789",
            TEST_MAKE,
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            TEST_METADATA_URI
        );
        vm.stopPrank();

        (uint256 base, uint256 total, bool locked, uint256 lockedAt, uint256 duration) =
            treasury.getAssetCollateralInfo(newVehicleId);

        assertEq(base, 0);
        assertEq(total, 0);
        assertFalse(locked);
        assertEq(lockedAt, 0);
        assertEq(duration, 0);
    }

    // Admin Functions Tests

    function testUpdatePartnerManager() public {
        _ensureState(SetupState.ContractsDeployed);
        PartnerManager newPartnerManager = new PartnerManager();

        vm.startPrank(admin);
        treasury.updatePartnerManager(address(newPartnerManager));
        vm.stopPrank();

        assertEq(address(treasury.partnerManager()), address(newPartnerManager));
    }

    function testUpdatePartnerManagerZeroAddressFails() public {
        _ensureState(SetupState.ContractsDeployed);
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        vm.startPrank(admin);
        treasury.updatePartnerManager(address(0));
        vm.stopPrank();
    }

    function testUpdatePartnerManagerUnauthorizedFails() public {
        _ensureState(SetupState.ContractsDeployed);
        PartnerManager newPartnerManager = new PartnerManager();

        vm.expectRevert();
        vm.prank(unauthorized);
        treasury.updatePartnerManager(address(newPartnerManager));
    }

    function testUpdateVehicleRegistry() public {
        _ensureState(SetupState.ContractsDeployed);
        VehicleRegistry newRegistry = new VehicleRegistry();

        vm.startPrank(admin);
        treasury.updateAssetRegistry(address(newRegistry));
        vm.stopPrank();

        assertEq(address(treasury.assetRegistry()), address(newRegistry));
    }

    function testUpdateUSDC() public {
        _ensureState(SetupState.ContractsDeployed);
        ERC20Mock newUSDC = new ERC20Mock();

        vm.startPrank(admin);
        treasury.updateUSDC(address(newUSDC));
        vm.stopPrank();

        assertEq(address(treasury.usdc()), address(newUSDC));
    }

    // Integration Tests

    function testMultipleVehicleCollateralLocking() public {
        _ensureState(SetupState.ContractsDeployed);
        // Register multiple vehicles
        vm.startPrank(partner1);
        uint256 vehicleId1 = vehicleRegistry.registerVehicle(
            TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );
        vm.stopPrank();

        vm.startPrank(partner2);
        uint256 vehicleId2 =
            vehicleRegistry.registerVehicle("2HGCM82633A654321", "Toyota", "Camry", 2023, 2, "LE", TEST_METADATA_URI);
        vm.stopPrank();

        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Approve and lock collateral for both vehicles
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(vehicleId1, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();

        vm.startPrank(partner2);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(vehicleId2, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();

        // Check treasury state
        assertEq(treasury.totalCollateralDeposited(), requiredCollateral * 2);

        // Check individual collateral states
        (,, bool locked1,,) = treasury.getAssetCollateralInfo(vehicleId1);
        (,, bool locked2,,) = treasury.getAssetCollateralInfo(vehicleId2);
        assertTrue(locked1);
        assertTrue(locked2);
    }

    function testCompleteCollateralLifecycle() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        uint256 initialBalance = usdc.balanceOf(partner1);

        // 1. Lock collateral
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();
        assertEq(usdc.balanceOf(partner1), initialBalance - requiredCollateral);

        // 2. Unlock collateral
        vm.startPrank(partner1);
        treasury.releaseCollateral(vehicleId);
        vm.stopPrank();
        assertEq(treasury.getPendingWithdrawal(partner1), requiredCollateral);

        // 3. Process withdrawal
        vm.startPrank(partner1);
        treasury.processWithdrawal();
        vm.stopPrank();
        assertEq(usdc.balanceOf(partner1), initialBalance);
        assertEq(treasury.getPendingWithdrawal(partner1), 0);
    }

    function testSetRoboshareTokens() public {
        _ensureState(SetupState.ContractsDeployed);
        // Deploy a new RoboshareTokens contract for testing
        RoboshareTokens newRoboshareTokens = new RoboshareTokens();

        vm.startPrank(admin);
        treasury.setRoboshareTokens(address(newRoboshareTokens));
        vm.stopPrank();

        assertEq(address(treasury.roboshareTokens()), address(newRoboshareTokens));
    }

    function testSetRoboshareTokensUnauthorizedFails() public {
        _ensureState(SetupState.ContractsDeployed);
        RoboshareTokens newRoboshareTokens = new RoboshareTokens();

        vm.expectRevert();
        vm.prank(unauthorized);
        treasury.setRoboshareTokens(address(newRoboshareTokens));
    }

    function testSetRoboshareTokensZeroAddressFails() public {
        _ensureState(SetupState.ContractsDeployed);
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        vm.startPrank(admin);
        treasury.setRoboshareTokens(address(0));
        vm.stopPrank();
    }

    // Earnings Distribution Tests

    function testDistributeEarnings() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);

        // Lock collateral first
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();

        uint256 earningsAmount = 1000 * 1e6; // $1000 USDC
        uint256 expectedProtocolFee = (earningsAmount * 250) / 10000; // 2.5%
        uint256 expectedNetEarnings = earningsAmount - expectedProtocolFee;

        // Approve USDC for earnings distribution
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        vm.stopPrank();

        uint256 initialTreasuryBalance = treasury.totalEarningsDeposited();
        uint256 initialTreasuryFeePending = treasury.getPendingWithdrawal(config.treasuryFeeRecipient);

        // Expect EarningsDistributed event
        vm.expectEmit(true, true, false, true);
        emit Treasury.EarningsDistributed(vehicleId, partner1, expectedNetEarnings, 1);

        vm.startPrank(partner1);
        treasury.distributeEarnings(vehicleId, earningsAmount);
        vm.stopPrank();

        // Verify treasury state (total deposited includes protocol fees)
        assertEq(treasury.totalEarningsDeposited(), initialTreasuryBalance + earningsAmount);

        // Verify protocol fee was allocated to treasury fee recipient
        assertEq(
            treasury.getPendingWithdrawal(config.treasuryFeeRecipient), initialTreasuryFeePending + expectedProtocolFee
        );

        // Verify USDC was transferred to treasury
        assertEq(usdc.balanceOf(address(treasury)), requiredCollateral + earningsAmount);
    }

    function testDistributeEarningsUnauthorized() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.expectRevert(Treasury__UnauthorizedPartner.selector);
        vm.prank(unauthorized);
        treasury.distributeEarnings(vehicleId, 1000 * 1e6);
    }

    function testDistributeEarningsInvalidAmount() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.expectRevert(Treasury__InvalidEarningsAmount.selector);
        vm.prank(partner1);
        treasury.distributeEarnings(vehicleId, 0);
    }

    function testDistributeEarningsVehicleNotFound() public {
        _ensureState(SetupState.ContractsDeployed);
        uint256 nonexistentVehicleId = 999;

        vm.expectRevert(Treasury__VehicleNotFound.selector);
        vm.prank(partner1);
        treasury.distributeEarnings(nonexistentVehicleId, 1000 * 1e6);
    }

    function testDistributeEarningsNoRevenueTokensIssued() public {
        _ensureState(SetupState.VehicleRegistered);

        vm.expectRevert(Treasury__NoRevenueTokensIssued.selector);
        vm.prank(partner1);
        treasury.distributeEarnings(vehicleId, 1000 * 1e6);
    }

    // Earnings Claims Tests

    function testClaimEarnings() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Lock collateral and distribute earnings
        vm.startPrank(partner1);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();

        uint256 earningsAmount = 1000 * 1e6;
        uint256 expectedProtocolFee = (earningsAmount * 250) / 10000;
        uint256 expectedNetEarnings = earningsAmount - expectedProtocolFee;

        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        treasury.distributeEarnings(vehicleId, earningsAmount);
        vm.stopPrank();

        // Partner1 owns all tokens, so should be able to claim all earnings
        uint256 initialPendingWithdrawal = treasury.getPendingWithdrawal(partner1);

        // Expect EarningsClaimed event
        vm.expectEmit(true, true, false, true);
        emit Treasury.EarningsClaimed(vehicleId, partner1, expectedNetEarnings);

        vm.startPrank(partner1);
        treasury.claimEarnings(vehicleId);
        vm.stopPrank();

        // Verify earnings were added to pending withdrawals
        assertEq(treasury.getPendingWithdrawal(partner1), initialPendingWithdrawal + expectedNetEarnings);
    }

    function testClaimEarningsMultiplePeriods() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Lock collateral
        vm.startPrank(partner1);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();

        uint256 earningsAmount1 = 1000 * 1e6;
        uint256 earningsAmount2 = 500 * 1e6;
        uint256 totalEarnings = earningsAmount1 + earningsAmount2;
        uint256 totalProtocolFee = (totalEarnings * 250) / 10000;
        uint256 totalNetEarnings = totalEarnings - totalProtocolFee;

        // First distribution
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount1);
        treasury.distributeEarnings(vehicleId, earningsAmount1);
        vm.stopPrank();

        // Second distribution
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount2);
        treasury.distributeEarnings(vehicleId, earningsAmount2);
        vm.stopPrank();

        // Claim all earnings from both periods
        uint256 initialPendingWithdrawal = treasury.getPendingWithdrawal(partner1);

        vm.startPrank(partner1);
        treasury.claimEarnings(vehicleId);
        vm.stopPrank();

        // Should receive earnings from both periods
        assertEq(treasury.getPendingWithdrawal(partner1), initialPendingWithdrawal + totalNetEarnings);
    }

    function testClaimEarningsNoBalance() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Lock collateral and distribute earnings
        vm.startPrank(partner1);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();

        uint256 earningsAmount = 1000 * 1e6;
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        treasury.distributeEarnings(vehicleId, earningsAmount);
        vm.stopPrank();

        // Unauthorized user has no tokens
        vm.expectRevert(Treasury__InsufficientTokenBalance.selector);
        vm.prank(unauthorized);
        treasury.claimEarnings(vehicleId);
    }

    function testClaimEarningsAlreadyClaimed() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Lock collateral and distribute earnings
        vm.startPrank(partner1);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();

        uint256 earningsAmount = 1000 * 1e6;
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        treasury.distributeEarnings(vehicleId, earningsAmount);
        vm.stopPrank();

        // First claim
        vm.startPrank(partner1);
        treasury.claimEarnings(vehicleId);
        vm.stopPrank();

        // Second claim should fail (no new earnings)
        vm.expectRevert(Treasury__NoEarningsToClaim.selector);
        vm.startPrank(partner1);
        treasury.claimEarnings(vehicleId);
        vm.stopPrank();
    }

    // Partial Collateral Release Tests

    function testReleasePartialCollateral() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Lock collateral
        vm.startPrank(partner1);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();

        // Wait past minimum event interval
        vm.warp(block.timestamp + 30 days);

        // Distribute earnings
        uint256 earningsAmount = 1000 * 1e6;
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        treasury.distributeEarnings(vehicleId, earningsAmount);
        vm.stopPrank();

        uint256 initialPendingWithdrawal = treasury.getPendingWithdrawal(partner1);
        uint256 initialTotalDeposited = treasury.totalCollateralDeposited();

        vm.startPrank(partner1);
        treasury.releasePartialCollateral(vehicleId);
        vm.stopPrank();

        // Verify some collateral was released
        assertTrue(treasury.getPendingWithdrawal(partner1) > initialPendingWithdrawal);
        assertTrue(treasury.totalCollateralDeposited() < initialTotalDeposited);
    }

    function testReleasePartialCollateralTooSoon() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Lock collateral and distribute earnings
        vm.startPrank(partner1);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();

        uint256 earningsAmount = 1000 * 1e6;
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        treasury.distributeEarnings(vehicleId, earningsAmount);
        vm.stopPrank();

        // Try to release immediately (should fail due to time restriction)
        vm.expectRevert(Treasury__TooSoonForCollateralRelease.selector);
        vm.startPrank(partner1);
        treasury.releasePartialCollateral(vehicleId);
        vm.stopPrank();
    }

    function testReleasePartialCollateralNoEarnings() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Lock collateral but don't distribute earnings
        vm.startPrank(partner1);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();

        // Fast forward past minimum event interval
        vm.warp(block.timestamp + 16 days);

        // Should fail because no prior earnings distribution
        vm.expectRevert(Treasury__NoPriorEarningsDistribution.selector);
        vm.startPrank(partner1);
        treasury.releasePartialCollateral(vehicleId);
        vm.stopPrank();
    }

    // Integration Tests

    function testCompleteEarningsLifecycle() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 initialBalance = usdc.balanceOf(partner1);

        // 1. Lock collateral
        vm.startPrank(partner1);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(vehicleId, REVENUE_TOKEN_PRICE, TOTAL_REVENUE_TOKENS);
        vm.stopPrank();

        // 2. Wait past minimum event interval
        vm.warp(block.timestamp + 30 days);

        // 3. Distribute earnings
        uint256 earningsAmount = 1000 * 1e6;
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        treasury.distributeEarnings(vehicleId, earningsAmount);
        vm.stopPrank();

        // 4. Claim earnings
        vm.startPrank(partner1);
        treasury.claimEarnings(vehicleId);
        vm.stopPrank();

        // 5. Process withdrawal
        vm.startPrank(partner1);
        treasury.processWithdrawal();
        vm.stopPrank();

        // 6. Release partial collateral
        vm.startPrank(partner1);
        treasury.releasePartialCollateral(vehicleId);
        vm.stopPrank();

        // 6. Process collateral withdrawal
        vm.startPrank(partner1);
        treasury.processWithdrawal();
        vm.stopPrank();

        // Verify partner received back their earnings (minus protocol fee)
        uint256 finalBalance = usdc.balanceOf(partner1);

        // Partner should have received back the net earnings plus some partial collateral
        // They paid: requiredCollateral + earningsAmount
        // They received: netEarnings + partial collateral release
        // Final balance should be: initial - paid + received
        assertTrue(finalBalance < initialBalance); // They should have less than they started with since most collateral is still locked
    }
}
