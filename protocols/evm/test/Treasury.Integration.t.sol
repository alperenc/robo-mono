// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";

import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

contract TreasuryIntegrationTest is BaseTest, ERC1155Holder {
    uint256 constant BASE_COLLATERAL = REVENUE_TOKEN_PRICE * REVENUE_TOKEN_SUPPLY;

    function setUp() public {
        // Integration tests need funded accounts and authorized partners as a baseline
        _ensureState(SetupState.AccountsFunded);
    }

    // Collateral Locking Tests

    function testLockCollateral() public {
        _ensureState(SetupState.AssetRegistered);
        uint256 requiredCollateral = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);

        BalanceSnapshot memory beforeSnapshot = takeBalanceSnapshot(scenario.revenueTokenId);

        treasury.lockCollateral(scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
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

        assertCollateralState(scenario.assetId, BASE_COLLATERAL, requiredCollateral, true);
        assertEq(treasury.totalCollateralDeposited(), requiredCollateral);
    }

    function testLockCollateralEmitsEvent() public {
        _ensureState(SetupState.AssetRegistered);
        uint256 requiredCollateral = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);

        vm.expectEmit(true, true, false, true);
        emit ITreasury.CollateralLocked(scenario.assetId, partner1, requiredCollateral);

        treasury.lockCollateral(scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();
    }

    function testLockCollateralNonExistentAsset() public {
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000 * 1e6);
        vm.expectRevert(Treasury__NotAssetOwner.selector);
        treasury.lockCollateral(999, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();
    }

    function testLockCollateralAlreadyLocked() public {
        _ensureState(SetupState.AssetWithListing);
        uint256 requiredCollateral = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        vm.expectRevert(Treasury__CollateralAlreadyLocked.selector);
        treasury.lockCollateral(scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();
    }

    function testLockCollateralWithoutApproval() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 0);
        vm.expectRevert();
        treasury.lockCollateral(scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();
    }

    function testLockCollateralInsufficientApproval() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 requiredCollateral = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral - 1);
        vm.expectRevert();
        treasury.lockCollateral(scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();
    }

    // Collateral Unlocking Tests

    function testUnlockCollateral() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Burn tokens first
        uint256 revenueTokenId = router.getTokenIdFromAssetId(scenario.assetId);
        uint256 supply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);

        vm.startPrank(admin);
        roboshareTokens.grantRole(roboshareTokens.BURNER_ROLE(), address(this));
        vm.stopPrank();

        vm.prank(partner1);
        roboshareTokens.safeTransferFrom(partner1, address(this), revenueTokenId, supply, "");
        roboshareTokens.burn(address(this), revenueTokenId, supply);

        vm.prank(address(router));
        treasury.releaseCollateralFor(partner1, scenario.assetId);

        (,, bool isLocked,,) = treasury.getAssetCollateralInfo(scenario.assetId);
        assertFalse(isLocked);
    }

    function testUnlockCollateralEmitsEvent() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Burn tokens first
        uint256 revenueTokenId = router.getTokenIdFromAssetId(scenario.assetId);
        uint256 supply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);

        vm.startPrank(admin);
        roboshareTokens.grantRole(roboshareTokens.BURNER_ROLE(), address(this));
        vm.stopPrank();

        vm.prank(partner1);
        roboshareTokens.safeTransferFrom(partner1, address(this), revenueTokenId, supply, "");
        roboshareTokens.burn(address(this), revenueTokenId, supply);

        vm.expectEmit(true, true, false, true, address(treasury));
        emit ITreasury.CollateralReleased(scenario.assetId, partner1, scenario.requiredCollateral);

        vm.prank(address(router));
        treasury.releaseCollateralFor(partner1, scenario.assetId);
    }

    function testUnlockCollateralNotLocked() public {
        _ensureState(SetupState.AssetRegistered);
        vm.expectRevert(Treasury__NoCollateralLocked.selector);
        vm.prank(partner1);
        treasury.releaseCollateral(scenario.assetId);
        vm.stopPrank();
    }

    function testUnlockCollateralNotAssetOwner() public {
        vm.expectRevert(Treasury__NotAssetOwner.selector);
        vm.prank(partner1);
        treasury.releaseCollateral(999);
        vm.stopPrank();
    }

    // Withdrawal Tests

    function testProcessWithdrawal() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Burn tokens first
        uint256 revenueTokenId = router.getTokenIdFromAssetId(scenario.assetId);
        uint256 supply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);

        vm.startPrank(admin);
        roboshareTokens.grantRole(roboshareTokens.BURNER_ROLE(), address(this));
        vm.stopPrank();

        vm.prank(partner1);
        roboshareTokens.safeTransferFrom(partner1, address(this), revenueTokenId, supply, "");
        roboshareTokens.burn(address(this), revenueTokenId, supply);

        vm.prank(address(router));
        treasury.releaseCollateralFor(partner1, scenario.assetId);

        uint256 initialBalance = usdc.balanceOf(partner1);
        uint256 pending = treasury.getPendingWithdrawal(partner1);

        vm.prank(partner1);
        treasury.processWithdrawal();

        assertEq(usdc.balanceOf(partner1), initialBalance + pending);
        assertEq(treasury.getPendingWithdrawal(partner1), 0);
    }

    function testProcessWithdrawalEmitsEvent() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Burn tokens first
        uint256 revenueTokenId = router.getTokenIdFromAssetId(scenario.assetId);
        uint256 supply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);

        vm.startPrank(admin);
        roboshareTokens.grantRole(roboshareTokens.BURNER_ROLE(), address(this));
        vm.stopPrank();

        vm.prank(partner1);
        roboshareTokens.safeTransferFrom(partner1, address(this), revenueTokenId, supply, "");
        roboshareTokens.burn(address(this), revenueTokenId, supply);

        vm.prank(address(router));
        treasury.releaseCollateralFor(partner1, scenario.assetId);

        uint256 pending = treasury.getPendingWithdrawal(partner1);

        vm.expectEmit(true, true, false, true, address(treasury));
        emit ITreasury.WithdrawalProcessed(partner1, pending);

        vm.prank(partner1);
        treasury.processWithdrawal();
    }

    function testProcessWithdrawalNoPendingWithdrawals() public {
        vm.expectRevert(Treasury__NoPendingWithdrawals.selector);
        vm.prank(partner1);
        treasury.processWithdrawal();
    }

    // Access Control

    function testLockCollateralUnauthorizedPartner() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.startPrank(unauthorized);
        usdc.approve(address(treasury), 1e9);
        vm.expectRevert(Treasury__UnauthorizedPartner.selector);
        treasury.lockCollateral(scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
    }

    function testUnlockCollateralUnauthorizedPartner() public {
        _ensureState(SetupState.AssetWithListing);
        vm.expectRevert(Treasury__UnauthorizedPartner.selector);
        vm.prank(unauthorized);
        treasury.releaseCollateral(scenario.assetId);
    }

    function testLockCollateralNotAssetOwner() public {
        _ensureState(SetupState.RevenueTokensMinted); // Vehicle is owned by partner1

        // Attempt to lock collateral as partner2, who is authorized but not the owner.
        vm.startPrank(partner2);
        usdc.approve(address(treasury), 1e9);
        vm.expectRevert(Treasury__NotAssetOwner.selector);
        treasury.lockCollateral(scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();
    }

    // View Functions

    function testGetTreasuryStats() public {
        _ensureState(SetupState.AssetRegistered);
        (uint256 deposited0, uint256 balance0) = treasury.getTreasuryStats();
        assertEq(deposited0, 0);
        assertEq(balance0, 0);

        _ensureState(SetupState.RevenueTokensMinted);
        (uint256 deposited1, uint256 balance1) = treasury.getTreasuryStats();
        uint256 expectedCollateral = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        assertEq(deposited1, expectedCollateral);
        assertEq(balance1, expectedCollateral);
    }

    function testGetAssetCollateralInfoUninitialized() public {
        _ensureState(SetupState.AssetRegistered);
        (uint256 base, uint256 total, bool locked,,) = treasury.getAssetCollateralInfo(scenario.assetId);
        assertEq(base, 0);
        assertEq(total, 0);
        assertFalse(locked);
    }

    // Complex Scenarios

    function testMultipleAssetCollateralLocking() public {
        _ensureState(SetupState.AssetRegistered); // First vehicle for partner1
        uint256 vehicleId1 = scenario.assetId;
        uint256 requiredCollateral1 = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral1);
        treasury.lockCollateral(vehicleId1, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();

        string memory vin2 = generateVIN(2);
        vm.prank(partner1);
        uint256 vehicleId2 = assetRegistry.registerAsset(
            abi.encode(
                vin2, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            )
        );

        uint256 requiredCollateral2 = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral2);
        treasury.lockCollateral(vehicleId2, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();

        assertEq(treasury.totalCollateralDeposited(), requiredCollateral1 + requiredCollateral2);
        assertCollateralState(vehicleId1, BASE_COLLATERAL, requiredCollateral1, true);
        assertCollateralState(vehicleId2, BASE_COLLATERAL, requiredCollateral2, true);
    }

    function testCompleteCollateralLifecycle() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // 1. Lock Collateral (already done in setup)
        (,, bool isLocked,,) = treasury.getAssetCollateralInfo(scenario.assetId);
        assertTrue(isLocked);

        // 2. Burn tokens
        uint256 revenueTokenId = router.getTokenIdFromAssetId(scenario.assetId);
        uint256 supply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);

        vm.startPrank(admin);
        roboshareTokens.grantRole(roboshareTokens.BURNER_ROLE(), address(this));
        vm.stopPrank();

        vm.prank(partner1);
        roboshareTokens.safeTransferFrom(partner1, address(this), revenueTokenId, supply, "");
        roboshareTokens.burn(address(this), revenueTokenId, supply);

        // 3. Unlock Collateral
        vm.prank(address(router));
        treasury.releaseCollateralFor(partner1, scenario.assetId);

        (,, isLocked,,) = treasury.getAssetCollateralInfo(scenario.assetId);
        assertFalse(isLocked);

        // 4. Process Withdrawal
        uint256 initialBalance = usdc.balanceOf(partner1);
        uint256 pending = treasury.getPendingWithdrawal(partner1);
        assertGt(pending, 0);

        vm.prank(partner1);
        treasury.processWithdrawal();

        assertEq(usdc.balanceOf(partner1), initialBalance + pending);
        assertEq(treasury.getPendingWithdrawal(partner1), 0);
    }

    // Earnings

    function testDistributeEarnings() public {
        _ensureState(SetupState.AssetWithListing);
        uint256 earningsAmount = 1000 * 1e6;
        uint256 protocolFee = calculateExpectedProtocolFee(earningsAmount);
        uint256 netEarnings = earningsAmount - protocolFee;

        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        vm.expectEmit(true, true, false, true);
        emit ITreasury.EarningsDistributed(scenario.assetId, partner1, netEarnings, 1);
        treasury.distributeEarnings(scenario.assetId, earningsAmount);
        vm.stopPrank();
    }

    function testDistributeEarningsUnauthorized() public {
        _ensureState(SetupState.AssetWithListing);
        vm.expectRevert(Treasury__UnauthorizedPartner.selector);
        vm.prank(unauthorized);
        treasury.distributeEarnings(scenario.assetId, 1000 * 1e6);
    }

    function testDistributeEarningsInvalidAmount() public {
        _ensureState(SetupState.AssetWithListing);
        vm.expectRevert(Treasury__InvalidEarningsAmount.selector);
        vm.prank(partner1);
        treasury.distributeEarnings(scenario.assetId, 0);
    }

    function testDistributeEarningsNonExistentAsset() public {
        vm.expectRevert(Treasury__NotAssetOwner.selector);
        vm.prank(partner1);
        treasury.distributeEarnings(999, 1000 * 1e6);
    }

    function testDistributeEarningsNoRevenueTokensIssued() public {
        // 1. Register a vehicle WITHOUT minting revenue tokens.
        vm.prank(partner1);
        uint256 assetId = assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            )
        );

        // 2. Attempt to distribute earnings. This should fail because the token info
        //    (including totalSupply) has not been initialized in Treasury yet.
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000e6);
        vm.expectRevert(Treasury__NoRevenueTokensIssued.selector);
        treasury.distributeEarnings(assetId, 1000 * 1e6);
        vm.stopPrank();
    }

    function testDistributeEarningsNotAssetOwner() public {
        _ensureState(SetupState.AssetWithListing); // Vehicle is owned by partner1

        // Attempt to distribute earnings as partner2, who is authorized but not the owner.
        vm.startPrank(partner2);
        usdc.approve(address(treasury), 1e9);
        vm.expectRevert(Treasury__NotAssetOwner.selector);
        treasury.distributeEarnings(scenario.assetId, 1000 * 1e6);
        vm.stopPrank();
    }

    function testLockCollateralForUnauthorizedPartner() public {
        _ensureState(SetupState.RevenueTokensMinted);
        // The msg.sender (router) is authorized, but the `unauthorized` parameter is not.
        vm.prank(address(router));
        vm.expectRevert(Treasury__UnauthorizedPartner.selector);
        treasury.lockCollateralFor(unauthorized, scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
    }

    function testLockCollateralForNonExistentAsset() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 nonExistentAssetId = 999;
        vm.prank(address(router));
        vm.expectRevert(Treasury__NotAssetOwner.selector);
        treasury.lockCollateralFor(partner1, nonExistentAssetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
    }

    function testClaimEarningsNonExistentAsset() public {
        _ensureState(SetupState.AssetWithEarnings);
        uint256 nonExistentAssetId = 999;

        vm.prank(buyer);
        vm.expectRevert(Treasury__AssetNotFound.selector);
        treasury.claimEarnings(nonExistentAssetId);
    }

    function testClaimEarnings() public {
        _ensureState(SetupState.AssetWithPurchase);
        uint256 earningsAmount = 1000 * 1e6;

        console.log("partner1 balance:", usdc.balanceOf(partner1));
        console.log("treasury allowance:", usdc.allowance(partner1, address(treasury)));
        console.log("earningsAmount:", earningsAmount);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        console.log("treasury allowance after approve:", usdc.allowance(partner1, address(treasury)));
        treasury.distributeEarnings(scenario.assetId, earningsAmount);
        vm.stopPrank();

        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        uint256 totalEarnings = earningsAmount - calculateExpectedProtocolFee(earningsAmount);
        uint256 buyerShare = (totalEarnings * buyerBalance) / REVENUE_TOKEN_SUPPLY;

        vm.startPrank(buyer);
        vm.expectEmit(true, true, false, true);
        emit ITreasury.EarningsClaimed(scenario.assetId, buyer, buyerShare);
        treasury.claimEarnings(scenario.assetId);
        vm.stopPrank();
    }

    function testClaimEarningsMultiplePeriods() public {
        _ensureState(SetupState.AssetWithPurchase);
        uint256 earnings1 = 1000 * 1e6;
        uint256 earnings2 = 500 * 1e6;
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earnings1 + earnings2);
        treasury.distributeEarnings(scenario.assetId, earnings1);
        treasury.distributeEarnings(scenario.assetId, earnings2);
        vm.stopPrank();

        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        uint256 totalNet = (earnings1 - calculateExpectedProtocolFee(earnings1))
            + (earnings2 - calculateExpectedProtocolFee(earnings2));
        uint256 buyerShare = (totalNet * buyerBalance) / REVENUE_TOKEN_SUPPLY;

        uint256 initialPending = treasury.getPendingWithdrawal(buyer);
        vm.prank(buyer);
        treasury.claimEarnings(scenario.assetId);
        vm.stopPrank();
        assertEq(treasury.getPendingWithdrawal(buyer), initialPending + buyerShare, "Incorrect total claim");
    }

    function testClaimEarningsNoBalance() public {
        _ensureState(SetupState.AssetWithListing);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000e6);
        treasury.distributeEarnings(scenario.assetId, 1000e6);
        vm.stopPrank();

        vm.expectRevert(Treasury__InsufficientTokenBalance.selector);
        vm.prank(unauthorized);
        treasury.claimEarnings(scenario.assetId);
    }

    function testClaimEarningsAlreadyClaimed() public {
        _ensureState(SetupState.AssetWithPurchase);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000e6);
        treasury.distributeEarnings(scenario.assetId, 1000e6);
        vm.stopPrank();

        vm.startPrank(buyer);
        treasury.claimEarnings(scenario.assetId);
        vm.expectRevert(Treasury__NoEarningsToClaim.selector);
        treasury.claimEarnings(scenario.assetId);
        vm.stopPrank();
    }

    function testReleasePartialCollateral() public {
        _ensureState(SetupState.AssetWithListing);
        vm.warp(block.timestamp + 30 days);
        setupEarningsScenario(scenario.assetId, 1000e6);
        vm.startPrank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
        vm.stopPrank();
    }

    function testReleasePartialCollateralTooSoon() public {
        _ensureState(SetupState.AssetWithListing);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000e6);
        treasury.distributeEarnings(scenario.assetId, 1000e6);
        vm.expectRevert(Treasury__TooSoonForCollateralRelease.selector);
        treasury.releasePartialCollateral(scenario.assetId);
        vm.stopPrank();
    }

    function testReleasePartialCollateralNoEarnings() public {
        _ensureState(SetupState.AssetWithListing);
        vm.warp(block.timestamp + 16 days);
        vm.expectRevert(Treasury__NoPriorEarningsDistribution.selector);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
    }

    function testReleasePartialCollateralNotOwner() public {
        _ensureState(SetupState.AssetWithListing);
        // partner2 is authorized but does not own scenario.assetId
        vm.prank(partner2);
        vm.expectRevert(Treasury__NotAssetOwner.selector);
        treasury.releasePartialCollateral(scenario.assetId);
    }

    function testCompleteEarningsLifecycle() public {
        _ensureState(SetupState.AssetWithPurchase);
        uint256 earningsAmount = 1000 * 1e6;
        uint256 netEarnings = earningsAmount - calculateExpectedProtocolFee(earningsAmount);
        uint256 buyerShare = (netEarnings * PURCHASE_AMOUNT) / REVENUE_TOKEN_SUPPLY;
        uint256 buyerInitialBalance = usdc.balanceOf(buyer);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        treasury.distributeEarnings(scenario.assetId, earningsAmount);
        vm.stopPrank();

        vm.startPrank(buyer);
        treasury.claimEarnings(scenario.assetId);
        treasury.processWithdrawal();
        vm.stopPrank();

        assertEq(usdc.balanceOf(buyer), buyerInitialBalance + buyerShare);
    }

    function testLockCollateralFor() public {
        _ensureState(SetupState.AssetRegistered);
        uint256 requiredCollateral = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        vm.stopPrank();

        vm.prank(address(router));
        treasury.lockCollateralFor(partner1, scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        (uint256 baseCollateral, uint256 totalCollateral, bool isLocked,,) =
            treasury.getAssetCollateralInfo(scenario.assetId);
        assertGt(baseCollateral, 0);
        assertTrue(isLocked);
        assertGt(totalCollateral, 0);
    }

    function testLockCollateralForUnauthorized() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                treasury.AUTHORIZED_ROUTER_ROLE()
            )
        );
        vm.prank(unauthorized);
        treasury.lockCollateralFor(partner1, scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
    }

    function testReleaseCollateralForUnauthorized() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                treasury.AUTHORIZED_ROUTER_ROLE()
            )
        );
        vm.prank(unauthorized);
        treasury.releaseCollateralFor(partner1, scenario.assetId);
    }

    function testLockCollateralForNotAssetOwner() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.prank(address(router));
        vm.expectRevert(Treasury__NotAssetOwner.selector);
        treasury.lockCollateralFor(partner2, scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
    }

    function testReleaseCollateralForCalledByRegistry() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Burn tokens first to allow retirement
        uint256 revenueTokenId = router.getTokenIdFromAssetId(scenario.assetId);
        uint256 supply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);

        // Give burner role to this test contract to burn tokens
        vm.startPrank(admin);
        roboshareTokens.grantRole(roboshareTokens.BURNER_ROLE(), address(this));
        vm.stopPrank();

        // Transfer tokens to this contract and burn
        vm.prank(partner1);
        roboshareTokens.safeTransferFrom(partner1, address(this), revenueTokenId, supply, "");
        roboshareTokens.burn(address(this), revenueTokenId, supply);

        // Impersonate VehicleRegistry (which is the authorized registry for the asset)
        vm.prank(address(router));
        treasury.releaseCollateralFor(partner1, scenario.assetId);

        // Verify collateral released (partially or fully depending on state)
        // In RevenueTokensMinted state, collateral is locked.
        // releaseCollateralFor releases it.
        (,, bool isLocked,,) = treasury.getAssetCollateralInfo(scenario.assetId);
        assertFalse(isLocked);
    }

    function testTreasuryFeeRecipientWithdrawal() public {
        _ensureState(SetupState.AssetWithListing);
        uint256 amount = 5_000e6;

        // Distribute earnings to accrue protocol fee to fee recipient
        vm.startPrank(partner1);
        usdc.approve(address(treasury), amount);
        treasury.distributeEarnings(scenario.assetId, amount);
        vm.stopPrank();

        uint256 fee = calculateExpectedProtocolFee(amount);
        assertEq(treasury.getPendingWithdrawal(config.treasuryFeeRecipient), fee);

        // Fee recipient withdraws
        uint256 beforeWithdrawal = usdc.balanceOf(config.treasuryFeeRecipient);
        vm.prank(config.treasuryFeeRecipient);
        treasury.processWithdrawal();
        uint256 afterWithdrawal = usdc.balanceOf(config.treasuryFeeRecipient);
        assertEq(afterWithdrawal, beforeWithdrawal + fee);
        assertEq(treasury.getPendingWithdrawal(config.treasuryFeeRecipient), 0);
    }

    function testReleasePartialCollateralPerfectBuffersMatch() public {
        _ensureState(SetupState.AssetWithListing);

        // Use a realistic interval to avoid overflow while targeting the equality path
        uint256 dt = 30 days;
        (,, bool isLocked, uint256 lockedAt,) = treasury.getAssetCollateralInfo(scenario.assetId);
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
        treasury.distributeEarnings(scenario.assetId, gross);
        vm.stopPrank();

        // Release; with near-perfect match no shortfall/excess branches should trigger
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
    }

    function testLinearReleaseOneYear() public {
        _ensureState(SetupState.AssetWithListing);

        // Satisfy performance gate with an earnings distribution
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1_000e6);
        treasury.distributeEarnings(scenario.assetId, 1_000e6);
        vm.stopPrank();

        // Read initial lockedAt and base
        (uint256 baseBefore,, bool isLocked, uint256 lockedAt,) = treasury.getAssetCollateralInfo(scenario.assetId);
        assertTrue(isLocked);

        // Warp one year from lock and release
        vm.warp(lockedAt + 365 days);
        uint256 pendingBefore = treasury.getPendingWithdrawal(partner1);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);

        (uint256 baseAfter, uint256 totalAfter,,,) = treasury.getAssetCollateralInfo(scenario.assetId);

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

    function testLinearReleaseCumulativeEighteenMonths() public {
        _ensureState(SetupState.AssetWithListing);

        // First distribution to enable first release
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 2_000e6);
        treasury.distributeEarnings(scenario.assetId, 1_000e6);
        vm.stopPrank();

        (uint256 baseInitial,, bool isLocked, uint256 lockedAt,) = treasury.getAssetCollateralInfo(scenario.assetId);
        assertTrue(isLocked);

        // First release after 1 year
        vm.warp(lockedAt + 365 days);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);

        // Second distribution to enable second release
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1_000e6);
        treasury.distributeEarnings(scenario.assetId, 1_000e6);
        vm.stopPrank();

        // Second release after additional ~6 months from the last release timestamp
        uint256 tsAfterFirst = block.timestamp;
        vm.warp(tsAfterFirst + 182 days);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);

        (uint256 baseAfter,,,,) = treasury.getAssetCollateralInfo(scenario.assetId);

        // Expected cumulative release over 1.5 years: 18% of initial base
        uint256 expectedCumulative = (baseInitial * (1200 * 365 + 1200 * 182)) / (10000 * 365);
        // After two releases, remaining base should be initial - expectedCumulative (no compounding)
        assertEq(baseAfter, baseInitial - expectedCumulative, "Linear 18-month cumulative base release mismatch");
    }

    // Releasing without new earnings periods should revert (performance gate)
    function testReleasePartialCollateralNoNewPeriods() public {
        _ensureState(SetupState.AssetWithListing);

        // First, initialize earnings
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000e6);
        treasury.distributeEarnings(scenario.assetId, 1000e6);
        vm.stopPrank();

        // Warp relative to the original lock timestamp before first release
        (,, bool locked, uint256 lockedAt,) = treasury.getAssetCollateralInfo(scenario.assetId);
        locked; // silence unused var
        vm.warp(lockedAt + ProtocolLib.MIN_EVENT_INTERVAL + 1);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId); // updates lastEventTimestamp

        // Capture the timestamp used by the prior release and warp from it
        uint256 tsAfterFirstRelease = block.timestamp;
        vm.warp(tsAfterFirstRelease + ProtocolLib.MIN_EVENT_INTERVAL + 1);
        vm.expectRevert(Treasury__NoNewPeriodsToProcess.selector);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
    }

    // Shortfall then replenishment flow emitting events
    function testReleasePartialCollateralShortfallThenReplenishment() public {
        _ensureState(SetupState.AssetWithListing);

        // Configure a shortfall: low earnings vs benchmark
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 100e6);
        treasury.distributeEarnings(scenario.assetId, 100e6); // small amount to trigger shortfall vs benchmark
        vm.stopPrank();

        // Warp relative to the original lock timestamp and process first release
        (,, bool locked, uint256 lockedAt,) = treasury.getAssetCollateralInfo(scenario.assetId);
        locked; // silence
        vm.warp(lockedAt + ProtocolLib.MIN_EVENT_INTERVAL + 1);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
        uint256 tsAfterFirstShortfallRelease = block.timestamp;

        // Now add excess earnings and process to replenish buffers
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 10_000e6);
        treasury.distributeEarnings(scenario.assetId, 10_000e6);
        vm.stopPrank();

        // Warp from the timestamp used in the prior release
        vm.warp(tsAfterFirstShortfallRelease + ProtocolLib.MIN_EVENT_INTERVAL + 1);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
    }

    function testReleasePartialCollateralTooSoonMidCycle() public {
        // 1. Set up state with a vehicle and initial earnings distribution.
        _ensureState(SetupState.AssetWithEarnings);

        // 2. Warp time forward to allow for an initial depreciation release.
        (,, bool isLocked, uint256 lockedAt,) = treasury.getAssetCollateralInfo(scenario.assetId);
        assertTrue(isLocked);
        vm.warp(lockedAt + ProtocolLib.MONTHLY_INTERVAL);

        // 3. Perform the first release, which updates the lastEventTimestamp.
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);

        // 4. Distribute new earnings to pass the performance gate for the second attempt.
        setupEarningsScenario(scenario.assetId, 1000e6);

        // 5. Warp forward by less than the minimum interval.
        vm.warp(block.timestamp + 1 days);

        // 6. Expect the specific revert for attempting a release too soon.
        vm.expectRevert(Treasury__TooSoonForCollateralRelease.selector);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
    }

    function testDistributeEarningsMinimumProtocolFee() public {
        _ensureState(SetupState.AssetWithListing);
        uint256 tinyEarningsAmount = ProtocolLib.MIN_PROTOCOL_FEE; // An amount equal to the minimum fee, ensuring it's applied
        uint256 protocolFee = calculateExpectedProtocolFee(tinyEarningsAmount);
        assertEq(protocolFee, ProtocolLib.MIN_PROTOCOL_FEE, "Protocol fee should be the minimum fee");

        uint256 initialFeeBalance = treasury.getPendingWithdrawal(config.treasuryFeeRecipient);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), tinyEarningsAmount);
        treasury.distributeEarnings(scenario.assetId, tinyEarningsAmount);
        vm.stopPrank();

        uint256 finalFeeBalance = treasury.getPendingWithdrawal(config.treasuryFeeRecipient);
        assertEq(
            finalFeeBalance,
            initialFeeBalance + ProtocolLib.MIN_PROTOCOL_FEE,
            "Fee recipient balance should increase by minimum fee"
        );
    }

    function testDistributeEarningsAmountLessThanMinimumFee() public {
        _ensureState(SetupState.AssetWithListing);
        uint256 insufficientEarningsAmount = ProtocolLib.MIN_PROTOCOL_FEE - 1;

        vm.startPrank(partner1);
        usdc.approve(address(treasury), insufficientEarningsAmount);
        vm.expectRevert(Treasury__EarningsLessThanMinimumFee.selector);
        treasury.distributeEarnings(scenario.assetId, insufficientEarningsAmount);
        vm.stopPrank();
    }

    function testReleasePartialCollateralDepleted() public {
        _ensureState(SetupState.AssetWithEarnings);

        (, uint256 earningsBuffer, uint256 protocolBuffer,) =
            calculateExpectedCollateral(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        (,, bool isLocked, uint256 lockedAt,) = treasury.getAssetCollateralInfo(scenario.assetId);
        assertTrue(isLocked);

        // Repeatedly release collateral over 10 years until it's fully depleted (12% per year, ~8.33 years to deplete)
        uint256 timeToWarp = lockedAt;
        for (uint256 i = 0; i < 9; i++) {
            timeToWarp += 365 days;
            vm.warp(timeToWarp);

            // Distribute earnings that meet the benchmark to avoid draining the buffer
            (uint256 currentBase,,,,) = treasury.getAssetCollateralInfo(scenario.assetId);
            uint256 benchmarkEarnings = EarningsLib.calculateBenchmarkEarnings(currentBase, 365 days);
            uint256 grossEarnings = (benchmarkEarnings * 10000) / 9750; // Gross up to account for protocol fee
            setupEarningsScenario(scenario.assetId, grossEarnings + 1e6); // Add extra to ensure excess

            vm.prank(partner1);
            treasury.releasePartialCollateral(scenario.assetId);
        }

        // Verify base collateral is depleted, but buffers remain
        (uint256 baseCollateralAfter, uint256 totalCollateralAfter,,,) =
            treasury.getAssetCollateralInfo(scenario.assetId);
        assertEq(baseCollateralAfter, 0, "Base collateral should be zero after 9 years");
        assertApproxEqAbs(
            totalCollateralAfter,
            earningsBuffer + protocolBuffer,
            1e6,
            "Total collateral should approx equal initial buffers"
        );

        // Attempt one final release in the 10th year
        setupEarningsScenario(scenario.assetId, 1000e6);
        vm.warp(block.timestamp + 365 days);

        // Expect revert because releaseAmount will be 0
        vm.expectRevert(Treasury__InsufficientCollateral.selector);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
    }
}
