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
            0,                          // Buyer USDC change
            0,                          // Treasury Fee Recipient USDC change
            int256(requiredCollateral), // Treasury Contract USDC change
            0,                          // Partner token change
            0                           // Buyer token change
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
        _ensureState(SetupState.VehicleWithListing);
        (uint256 deposited, uint256 balance) = treasury.getTreasuryStats();
        uint256 expectedCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        assertEq(deposited, expectedCollateral);
        assertEq(balance, expectedCollateral);
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
        (uint256 vehicleId2, ) = vehicleRegistry.registerVehicleAndMintRevenueTokens(
            vin2, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI, REVENUE_TOKEN_SUPPLY
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
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000e6);
        treasury.distributeEarnings(scenario.vehicleId, 1000e6);
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
}
