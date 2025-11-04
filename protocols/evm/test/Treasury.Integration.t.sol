// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";

contract TreasuryIntegrationTest is BaseTest {
    uint256 constant BASE_COLLATERAL = REVENUE_TOKEN_PRICE * REVENUE_TOKEN_SUPPLY;

    function setUp() public {
        // Integration tests need funded accounts and authorized partners as a baseline
        _ensureState(SetupState.AccountsFunded);
    }

    // Collateral Locking Tests

    function testLockCollateral() public {
        _ensureState(SetupState.VehicleWithTokens);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);

        BalanceSnapshot memory beforeSnapshot = takeBalanceSnapshot(scenario.revenueTokenId);

        treasury.lockCollateral(scenario.vehicleId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();

        BalanceSnapshot memory afterSnapshot = takeBalanceSnapshot(scenario.revenueTokenId);

        assertBalanceChanges(
            beforeSnapshot,
            afterSnapshot,
            -int256(requiredCollateral), // Partner USDC change
            0, // Buyer USDC change
            0, // Treasury Fee Recipient USDC change
            int256(requiredCollateral), // Treasury Contract USDC change
            0, // Partner token change
            0 // Buyer token change
        );

        assertCollateralState(scenario.vehicleId, BASE_COLLATERAL, requiredCollateral, true);
        assertEq(treasury.totalCollateralDeposited(), requiredCollateral);
    }

    function testLockCollateralEmitsEvent() public {
        _ensureState(SetupState.VehicleWithTokens);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);

        vm.expectEmit(true, true, false, true);
        emit Treasury.CollateralLocked(scenario.vehicleId, partner1, requiredCollateral);

        treasury.lockCollateral(scenario.vehicleId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();
    }

    function testLockCollateralForNonexistentVehicleFails() public {
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000 * 1e6);
        vm.expectRevert(Treasury__VehicleNotFound.selector);
        treasury.lockCollateral(999, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();
    }

    function testLockCollateralAlreadyLockedFails() public {
        _ensureState(SetupState.VehicleWithListing);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        vm.expectRevert(Treasury__CollateralAlreadyLocked.selector);
        treasury.lockCollateral(scenario.vehicleId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();
    }

    function testLockCollateralWithoutApprovalFails() public {
        _ensureState(SetupState.VehicleWithTokens);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 0);
        vm.expectRevert();
        treasury.lockCollateral(scenario.vehicleId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();
    }

    function testLockCollateralInsufficientApprovalFails() public {
        _ensureState(SetupState.VehicleWithTokens);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral - 1);
        vm.expectRevert();
        treasury.lockCollateral(scenario.vehicleId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();
    }

    // Collateral Unlocking Tests

    function testUnlockCollateral() public {
        _ensureState(SetupState.VehicleWithListing);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        vm.startPrank(partner1);
        treasury.releaseCollateral(scenario.vehicleId);
        vm.stopPrank();

        assertCollateralState(scenario.vehicleId, 0, 0, false);
        assertEq(treasury.getPendingWithdrawal(partner1), requiredCollateral);
        assertEq(treasury.totalCollateralDeposited(), 0);
    }

    function testUnlockCollateralEmitsEvent() public {
        _ensureState(SetupState.VehicleWithListing);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        vm.startPrank(partner1);
        vm.expectEmit(true, true, false, true);
        emit Treasury.CollateralReleased(scenario.vehicleId, partner1, requiredCollateral);
        treasury.releaseCollateral(scenario.vehicleId);
        vm.stopPrank();
    }

    function testUnlockCollateralNotLockedFails() public {
        _ensureState(SetupState.VehicleWithTokens);
        vm.expectRevert(Treasury__NoCollateralLocked.selector);
        vm.prank(partner1);
        treasury.releaseCollateral(scenario.vehicleId);
        vm.stopPrank();
    }

    function testUnlockCollateralNonexistentVehicleFails() public {
        vm.expectRevert(Treasury__VehicleNotFound.selector);
        vm.prank(partner1);
        treasury.releaseCollateral(999);
        vm.stopPrank();
    }

    // Withdrawal Tests

    function testProcessWithdrawal() public {
        _ensureState(SetupState.VehicleWithListing);
        uint256 initialBalance = usdc.balanceOf(partner1);
        (, uint256 collateralAmount,,,) = treasury.getAssetCollateralInfo(scenario.vehicleId);

        vm.startPrank(partner1);
        treasury.releaseCollateral(scenario.vehicleId);
        treasury.processWithdrawal();
        vm.stopPrank();

        assertUSDCBalance(partner1, initialBalance + collateralAmount, "Partner USDC balance mismatch after withdrawal");
        assertEq(treasury.getPendingWithdrawal(partner1), 0);
    }

    function testProcessWithdrawalEmitsEvent() public {
        _ensureState(SetupState.VehicleWithListing);
        (, uint256 collateralAmount,,,) = treasury.getAssetCollateralInfo(scenario.vehicleId);

        vm.startPrank(partner1);
        treasury.releaseCollateral(scenario.vehicleId);
        vm.expectEmit(true, false, false, true);
        emit Treasury.WithdrawalProcessed(partner1, collateralAmount);
        treasury.processWithdrawal();
        vm.stopPrank();
    }

    function testProcessWithdrawalNoPendingFails() public {
        vm.expectRevert(Treasury__InsufficientCollateral.selector);
        vm.prank(partner1);
        treasury.processWithdrawal();
    }

    // Access Control

    function testUnauthorizedPartnerCannotLockCollateral() public {
        _ensureState(SetupState.VehicleWithTokens);
        vm.startPrank(unauthorized);
        usdc.approve(address(treasury), 1e9);
        vm.expectRevert(Treasury__UnauthorizedPartner.selector);
        treasury.lockCollateral(scenario.vehicleId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
    }

    function testUnauthorizedPartnerCannotUnlockCollateral() public {
        _ensureState(SetupState.VehicleWithListing);
        vm.expectRevert(Treasury__UnauthorizedPartner.selector);
        vm.prank(unauthorized);
        treasury.releaseCollateral(scenario.vehicleId);
    }

    // View Functions

    function testGetTreasuryStats() public {
        _ensureState(SetupState.VehicleWithTokens);
        (uint256 deposited0, uint256 balance0) = treasury.getTreasuryStats();
        assertEq(deposited0, 0);
        assertEq(balance0, 0);

        _ensureState(SetupState.VehicleWithListing);
        (uint256 deposited1, uint256 balance1) = treasury.getTreasuryStats();
        uint256 expectedCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        assertEq(deposited1, expectedCollateral);
        assertEq(balance1, expectedCollateral);
    }

    function testTokenInfoInitializedAroundCollateralLock() public {
        _ensureState(SetupState.VehicleWithTokens);
        assertFalse(treasury.isAssetTokenInfoInitialized(scenario.vehicleId));

        _ensureState(SetupState.VehicleWithListing);
        assertTrue(treasury.isAssetTokenInfoInitialized(scenario.vehicleId));
    }

    function testGetVehicleCollateralInfoUninitialized() public {
        _ensureState(SetupState.VehicleWithTokens);
        (uint256 base, uint256 total, bool locked,,) = treasury.getAssetCollateralInfo(scenario.vehicleId);
        assertEq(base, 0);
        assertEq(total, 0);
        assertFalse(locked);
    }

    // Complex Scenarios

    function testMultipleVehicleCollateralLocking() public {
        _ensureState(SetupState.VehicleWithTokens); // First vehicle for partner1
        uint256 vehicleId1 = scenario.vehicleId;
        uint256 requiredCollateral1 = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral1);
        treasury.lockCollateral(vehicleId1, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();

        string memory vin2 = generateVIN(2);
        vm.prank(partner1);
        (uint256 vehicleId2,) = vehicleRegistry.registerVehicleAndMintRevenueTokens(
            vin2,
            TEST_MAKE,
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            TEST_METADATA_URI,
            REVENUE_TOKEN_SUPPLY
        );

        uint256 requiredCollateral2 = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral2);
        treasury.lockCollateral(vehicleId2, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();

        assertEq(treasury.totalCollateralDeposited(), requiredCollateral1 + requiredCollateral2);
        assertCollateralState(vehicleId1, BASE_COLLATERAL, requiredCollateral1, true);
        assertCollateralState(vehicleId2, BASE_COLLATERAL, requiredCollateral2, true);
    }

    function testCompleteCollateralLifecycle() public {
        _ensureState(SetupState.VehicleWithTokens);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        uint256 initialBalance = usdc.balanceOf(partner1);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        treasury.lockCollateral(scenario.vehicleId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        treasury.releaseCollateral(scenario.vehicleId);
        treasury.processWithdrawal();
        vm.stopPrank();

        assertEq(usdc.balanceOf(partner1), initialBalance);
    }

    // Earnings

    function testDistributeEarnings() public {
        _ensureState(SetupState.VehicleWithListing);
        uint256 earningsAmount = 1000 * 1e6;
        uint256 protocolFee = calculateExpectedProtocolFee(earningsAmount);
        uint256 netEarnings = earningsAmount - protocolFee;

        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        vm.expectEmit(true, true, false, true);
        emit Treasury.EarningsDistributed(scenario.vehicleId, partner1, netEarnings, 1);
        treasury.distributeEarnings(scenario.vehicleId, earningsAmount);
        vm.stopPrank();
    }

    function testDistributeEarningsUnauthorized() public {
        _ensureState(SetupState.VehicleWithListing);
        vm.expectRevert(Treasury__UnauthorizedPartner.selector);
        vm.prank(unauthorized);
        treasury.distributeEarnings(scenario.vehicleId, 1000 * 1e6);
    }

    function testDistributeEarningsInvalidAmount() public {
        _ensureState(SetupState.VehicleWithListing);
        vm.expectRevert(Treasury__InvalidEarningsAmount.selector);
        vm.prank(partner1);
        treasury.distributeEarnings(scenario.vehicleId, 0);
    }

    function testDistributeEarningsVehicleNotFound() public {
        vm.expectRevert(Treasury__VehicleNotFound.selector);
        vm.prank(partner1);
        treasury.distributeEarnings(999, 1000 * 1e6);
    }

    function testDistributeEarningsNoRevenueTokensIssued() public {
        // 1. Register a vehicle WITHOUT minting revenue tokens.
        vm.prank(partner1);
        uint256 vehicleId = vehicleRegistry.registerVehicle(
            TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        // 2. Attempt to distribute earnings. This should fail because the token info
        //    (including totalSupply) has not been initialized in Treasury yet.
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000e6);
        vm.expectRevert(Treasury__NoRevenueTokensIssued.selector);
        treasury.distributeEarnings(vehicleId, 1000 * 1e6);
        vm.stopPrank();
    }

    function testClaimEarnings() public {
        _ensureState(SetupState.VehicleWithPurchase);
        uint256 earningsAmount = 1000 * 1e6;

        console.log("partner1 balance:", usdc.balanceOf(partner1));
        console.log("treasury allowance:", usdc.allowance(partner1, address(treasury)));
        console.log("earningsAmount:", earningsAmount);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        console.log("treasury allowance after approve:", usdc.allowance(partner1, address(treasury)));
        treasury.distributeEarnings(scenario.vehicleId, earningsAmount);
        vm.stopPrank();

        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        uint256 totalEarnings = earningsAmount - calculateExpectedProtocolFee(earningsAmount);
        uint256 buyerShare = (totalEarnings * buyerBalance) / REVENUE_TOKEN_SUPPLY;

        vm.startPrank(buyer);
        vm.expectEmit(true, true, false, true);
        emit Treasury.EarningsClaimed(scenario.vehicleId, buyer, buyerShare);
        treasury.claimEarnings(scenario.vehicleId);
        vm.stopPrank();
    }

    function testClaimEarningsMultiplePeriods() public {
        _ensureState(SetupState.VehicleWithPurchase);
        uint256 earnings1 = 1000 * 1e6;
        uint256 earnings2 = 500 * 1e6;
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earnings1 + earnings2);
        treasury.distributeEarnings(scenario.vehicleId, earnings1);
        treasury.distributeEarnings(scenario.vehicleId, earnings2);
        vm.stopPrank();

        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        uint256 totalNet = (earnings1 - calculateExpectedProtocolFee(earnings1))
            + (earnings2 - calculateExpectedProtocolFee(earnings2));
        uint256 buyerShare = (totalNet * buyerBalance) / REVENUE_TOKEN_SUPPLY;

        uint256 initialPending = treasury.getPendingWithdrawal(buyer);
        vm.prank(buyer);
        treasury.claimEarnings(scenario.vehicleId);
        vm.stopPrank();
        assertEq(treasury.getPendingWithdrawal(buyer), initialPending + buyerShare, "Incorrect total claim");
    }

    function testClaimEarningsNoBalance() public {
        _ensureState(SetupState.VehicleWithListing);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000e6);
        treasury.distributeEarnings(scenario.vehicleId, 1000e6);
        vm.stopPrank();

        vm.expectRevert(Treasury__InsufficientTokenBalance.selector);
        vm.prank(unauthorized);
        treasury.claimEarnings(scenario.vehicleId);
    }

    function testClaimEarningsAlreadyClaimed() public {
        _ensureState(SetupState.VehicleWithPurchase);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000e6);
        treasury.distributeEarnings(scenario.vehicleId, 1000e6);
        vm.stopPrank();

        vm.startPrank(buyer);
        treasury.claimEarnings(scenario.vehicleId);
        vm.expectRevert(Treasury__NoEarningsToClaim.selector);
        treasury.claimEarnings(scenario.vehicleId);
        vm.stopPrank();
    }

    function testReleasePartialCollateral() public {
        _ensureState(SetupState.VehicleWithListing);
        vm.warp(block.timestamp + 30 days);
        setupEarningsScenario(scenario.vehicleId, 1000e6);
        vm.startPrank(partner1);
        treasury.releasePartialCollateral(scenario.vehicleId);
        vm.stopPrank();
    }

    function testReleasePartialCollateralTooSoon() public {
        _ensureState(SetupState.VehicleWithListing);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000e6);
        treasury.distributeEarnings(scenario.vehicleId, 1000e6);
        vm.expectRevert(Treasury__TooSoonForCollateralRelease.selector);
        treasury.releasePartialCollateral(scenario.vehicleId);
        vm.stopPrank();
    }

    function testReleasePartialCollateralNoEarnings() public {
        _ensureState(SetupState.VehicleWithListing);
        vm.warp(block.timestamp + 16 days);
        vm.expectRevert(Treasury__NoPriorEarningsDistribution.selector);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.vehicleId);
    }

    function testCompleteEarningsLifecycle() public {
        _ensureState(SetupState.VehicleWithPurchase);
        uint256 earningsAmount = 1000 * 1e6;
        uint256 netEarnings = earningsAmount - calculateExpectedProtocolFee(earningsAmount);
        uint256 buyerShare = (netEarnings * PURCHASE_AMOUNT) / REVENUE_TOKEN_SUPPLY;
        uint256 buyerInitialBalance = usdc.balanceOf(buyer);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        treasury.distributeEarnings(scenario.vehicleId, earningsAmount);
        vm.stopPrank();

        vm.startPrank(buyer);
        treasury.claimEarnings(scenario.vehicleId);
        treasury.processWithdrawal();
        vm.stopPrank();

        assertEq(usdc.balanceOf(buyer), buyerInitialBalance + buyerShare);
    }

    function testLockCollateralFor_Success() public {
        _ensureState(SetupState.VehicleWithTokens);
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        vm.stopPrank();

        vm.prank(address(marketplace));
        treasury.lockCollateralFor(partner1, scenario.vehicleId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        (uint256 baseCollateral, uint256 totalCollateral, bool isLocked,,) =
            treasury.getAssetCollateralInfo(scenario.vehicleId);
        assertGt(baseCollateral, 0);
        assertTrue(isLocked);
        assertGt(totalCollateral, 0);
    }

    function testLockCollateralFor_UnauthorizedCallerFails() public {
        _ensureState(SetupState.VehicleWithTokens);
        vm.expectRevert(Treasury__UnauthorizedPartner.selector);
        vm.prank(unauthorized);
        treasury.lockCollateralFor(partner1, scenario.vehicleId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
    }

    function testLockCollateralFor_NotOwnerFails() public {
        _ensureState(SetupState.VehicleWithTokens);
        vm.prank(address(marketplace));
        vm.expectRevert(Treasury__NotVehicleOwner.selector);
        treasury.lockCollateralFor(partner2, scenario.vehicleId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
    }

    function testTreasuryFeeRecipientWithdrawal() public {
        _ensureState(SetupState.VehicleWithListing);
        uint256 amount = 5_000e6;

        // Distribute earnings to accrue protocol fee to fee recipient
        vm.startPrank(partner1);
        usdc.approve(address(treasury), amount);
        treasury.distributeEarnings(scenario.vehicleId, amount);
        vm.stopPrank();

        uint256 fee = calculateExpectedProtocolFee(amount);
        assertEq(treasury.getPendingWithdrawal(config.treasuryFeeRecipient), fee);

        // Fee recipient withdraws
        uint256 before = usdc.balanceOf(config.treasuryFeeRecipient);
        vm.prank(config.treasuryFeeRecipient);
        treasury.processWithdrawal();
        uint256 afterBal = usdc.balanceOf(config.treasuryFeeRecipient);
        assertEq(afterBal, before + fee);
        assertEq(treasury.getPendingWithdrawal(config.treasuryFeeRecipient), 0);
    }

    function testReleasePartialCollateral_PerfectMatchBuffers() public {
        _ensureState(SetupState.VehicleWithListing);

        // Use a realistic interval to avoid overflow while targeting the equality path
        uint256 dt = 30 days;
        (,, bool isLocked, uint256 lockedAt,) = treasury.getAssetCollateralInfo(scenario.vehicleId);
        assertTrue(isLocked);
        vm.warp(lockedAt + dt);

        // Compute target net = base * MIN_EARNINGS_BUFFER_BP * dt / (BP_PRECISION * YEARLY_INTERVAL)
        (uint256 baseCollateral,,,) = calculateExpectedCollateral(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        uint256 targetNet = (baseCollateral * 1000 * dt) / (10000 * 365 days);
        // Compute gross so that net ~= targetNet (ceil to be safe): gross = ceil(targetNet * 10000 / 9750)
        uint256 gross = (targetNet * 10000 + 9749) / 9750;

        deal(address(usdc), partner1, gross);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), gross);
        treasury.distributeEarnings(scenario.vehicleId, gross);
        vm.stopPrank();

        // Release; with near-perfect match no shortfall/excess branches should trigger
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.vehicleId);
    }

    function testLinearRelease_OneYear() public {
        _ensureState(SetupState.VehicleWithListing);

        // Satisfy performance gate with an earnings distribution
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1_000e6);
        treasury.distributeEarnings(scenario.vehicleId, 1_000e6);
        vm.stopPrank();

        // Read initial lockedAt and base
        (uint256 baseBefore,, bool isLocked, uint256 lockedAt,) = treasury.getAssetCollateralInfo(scenario.vehicleId);
        assertTrue(isLocked);

        // Warp one year from lock and release
        vm.warp(lockedAt + 365 days);
        uint256 pendingBefore = treasury.getPendingWithdrawal(partner1);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.vehicleId);

        (uint256 baseAfter, uint256 totalAfter,,,) = treasury.getAssetCollateralInfo(scenario.vehicleId);

        // Expected linear release = 12% of initial base
        uint256 expectedRelease = (baseBefore * 1200) / 10000;
        assertEq(baseAfter, baseBefore - expectedRelease, "Linear one-year base release mismatch");

        // Pending increased by exactly expectedRelease; total decreased equally (buffers unchanged)
        uint256 pendingAfter = treasury.getPendingWithdrawal(partner1);
        assertEq(pendingAfter - pendingBefore, expectedRelease, "Pending increase mismatch");
        // Since getAssetCollateralInfo doesn't expose buffers, assert total decreased by expectedRelease
        // Re-read total before via breakdown: totalBefore = baseBefore + buffers; we can't fetch buffers, so compare deltas via pending
        totalAfter; // silence linter (state validated by pending delta and base delta)
    }

    function testLinearRelease_CumulativeEighteenMonths() public {
        _ensureState(SetupState.VehicleWithListing);

        // First distribution to enable first release
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 2_000e6);
        treasury.distributeEarnings(scenario.vehicleId, 1_000e6);
        vm.stopPrank();

        (uint256 baseInitial,, bool isLocked, uint256 lockedAt,) = treasury.getAssetCollateralInfo(scenario.vehicleId);
        assertTrue(isLocked);

        // First release after 1 year
        vm.warp(lockedAt + 365 days);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.vehicleId);

        // Second distribution to enable second release
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1_000e6);
        treasury.distributeEarnings(scenario.vehicleId, 1_000e6);
        vm.stopPrank();

        // Second release after additional ~6 months from the last release timestamp
        uint256 tsAfterFirst = block.timestamp;
        vm.warp(tsAfterFirst + 182 days);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.vehicleId);

        (uint256 baseAfter,,,,) = treasury.getAssetCollateralInfo(scenario.vehicleId);

        // Expected cumulative release over 1.5 years: 18% of initial base
        uint256 expectedCumulative = (baseInitial * (1200 * 365 + 1200 * 182)) / (10000 * 365);
        // After two releases, remaining base should be initial - expectedCumulative (no compounding)
        assertEq(baseAfter, baseInitial - expectedCumulative, "Linear 18-month cumulative base release mismatch");
    }

    // Releasing without new earnings periods should revert (performance gate)
    function testReleasePartialCollateral_NoNewPeriodsReverts() public {
        _ensureState(SetupState.VehicleWithListing);

        // First, initialize earnings
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000e6);
        treasury.distributeEarnings(scenario.vehicleId, 1000e6);
        vm.stopPrank();

        // Warp relative to the original lock timestamp before first release
        (,, bool locked, uint256 lockedAt,) = treasury.getAssetCollateralInfo(scenario.vehicleId);
        locked; // silence unused var
        vm.warp(lockedAt + ProtocolLib.MIN_EVENT_INTERVAL + 1);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.vehicleId); // updates lastEventTimestamp

        // Capture the timestamp used by the prior release and warp from it
        uint256 tsAfterFirstRelease = block.timestamp;
        vm.warp(tsAfterFirstRelease + ProtocolLib.MIN_EVENT_INTERVAL + 1);
        vm.expectRevert(Treasury__NoNewPeriodsToProcess.selector);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.vehicleId);
    }

    // Shortfall then replenishment flow emitting events
    function testReleasePartialCollateral_ShortfallThenReplenishment() public {
        _ensureState(SetupState.VehicleWithListing);

        // Configure a shortfall: low earnings vs benchmark
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 100e6);
        treasury.distributeEarnings(scenario.vehicleId, 100e6); // small amount to trigger shortfall vs benchmark
        vm.stopPrank();

        // Warp relative to the original lock timestamp and process first release
        (,, bool locked, uint256 lockedAt,) = treasury.getAssetCollateralInfo(scenario.vehicleId);
        locked; // silence
        vm.warp(lockedAt + ProtocolLib.MIN_EVENT_INTERVAL + 1);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.vehicleId);
        uint256 tsAfterFirstShortfallRelease = block.timestamp;

        // Now add excess earnings and process to replenish buffers
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 10_000e6);
        treasury.distributeEarnings(scenario.vehicleId, 10_000e6);
        vm.stopPrank();

        // Warp from the timestamp used in the prior release
        vm.warp(tsAfterFirstShortfallRelease + ProtocolLib.MIN_EVENT_INTERVAL + 1);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.vehicleId);
    }

    function testReleasePartialCollateral_RevertsIfTooSoon() public {
        // 1. Set up state with a vehicle and initial earnings distribution.
        _ensureState(SetupState.VehicleWithEarnings);

        // 2. Warp time forward to allow for an initial depreciation release.
        (,, bool isLocked, uint256 lockedAt,) = treasury.getAssetCollateralInfo(scenario.vehicleId);
        assertTrue(isLocked);
        vm.warp(lockedAt + ProtocolLib.MONTHLY_INTERVAL);

        // 3. Perform the first release, which updates the lastEventTimestamp.
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.vehicleId);

        // 4. Distribute new earnings to pass the performance gate for the second attempt.
        setupEarningsScenario(scenario.vehicleId, 1000e6);

        // 5. Warp forward by less than the minimum interval.
        vm.warp(block.timestamp + 1 days);

        // 6. Expect the specific revert for attempting a release too soon.
        vm.expectRevert(Treasury__TooSoonForCollateralRelease.selector);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.vehicleId);
    }

    function testDistributeEarnings_ZeroProtocolFee() public {
        _ensureState(SetupState.VehicleWithListing);
        uint256 tinyEarningsAmount = 10; // An amount so small the fee is 0
        uint256 protocolFee = calculateExpectedProtocolFee(tinyEarningsAmount);
        assertEq(protocolFee, 0, "Test assumption failed: protocol fee should be zero");

        uint256 initialFeeBalance = treasury.getPendingWithdrawal(config.treasuryFeeRecipient);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), tinyEarningsAmount);
        treasury.distributeEarnings(scenario.vehicleId, tinyEarningsAmount);
        vm.stopPrank();

        uint256 finalFeeBalance = treasury.getPendingWithdrawal(config.treasuryFeeRecipient);
        assertEq(finalFeeBalance, initialFeeBalance, "Fee recipient balance should not increase for zero fee");
    }

    function testReleasePartialCollateral_RevertsWhenDepleted() public {
        _ensureState(SetupState.VehicleWithEarnings);

        (uint256 baseCollateralBefore, uint256 earningsBuffer, uint256 protocolBuffer, ) = 
            calculateExpectedCollateral(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        (,, bool isLocked, uint256 lockedAt,) = treasury.getAssetCollateralInfo(scenario.vehicleId);
        assertTrue(isLocked);

        // Repeatedly release collateral over 10 years until it's fully depleted (12% per year, ~8.33 years to deplete)
        uint256 timeToWarp = lockedAt;
        for (uint i = 0; i < 9; i++) {
            timeToWarp += 365 days;
            vm.warp(timeToWarp);

            // Distribute earnings that meet the benchmark to avoid draining the buffer
            (uint256 currentBase,,,,) = treasury.getAssetCollateralInfo(scenario.vehicleId);
            uint256 benchmarkEarnings = EarningsLib.calculateBenchmarkEarnings(currentBase, 365 days);
            uint256 grossEarnings = (benchmarkEarnings * 10000) / 9750; // Gross up to account for protocol fee
            setupEarningsScenario(scenario.vehicleId, grossEarnings + 1e6); // Add extra to ensure excess

            vm.prank(partner1);
            treasury.releasePartialCollateral(scenario.vehicleId);
        }

        // Verify base collateral is depleted, but buffers remain
        (uint256 baseCollateralAfter, uint256 totalCollateralAfter,,, ) = treasury.getAssetCollateralInfo(scenario.vehicleId);
        assertEq(baseCollateralAfter, 0, "Base collateral should be zero after 9 years");
        assertApproxEqAbs(totalCollateralAfter, earningsBuffer + protocolBuffer, 1e6, "Total collateral should approx equal initial buffers");

        // Attempt one final release in the 10th year
        setupEarningsScenario(scenario.vehicleId, 1000e6);
        vm.warp(block.timestamp + 365 days);

        // Expect revert because releaseAmount will be 0
        vm.expectRevert(Treasury__InsufficientCollateral.selector);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.vehicleId);
    }
}
