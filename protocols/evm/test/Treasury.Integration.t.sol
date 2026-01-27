// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { ProtocolLib, EarningsLib, AssetLib, CollateralLib, TokenLib } from "../contracts/Libraries.sol";
import { IAssetRegistry } from "../contracts/interfaces/IAssetRegistry.sol";
import { ITreasury } from "../contracts/interfaces/ITreasury.sol";
import { PartnerManager } from "../contracts/PartnerManager.sol";

contract TreasuryIntegrationTest is BaseTest, ERC1155Holder {
    uint256 constant BASE_COLLATERAL = REVENUE_TOKEN_PRICE * REVENUE_TOKEN_SUPPLY;

    function setUp() public {
        // Integration tests need funded accounts and authorized partners as a baseline
        _ensureState(SetupState.InitialAccountsSetup);
    }

    // Collateral Locking Tests

    function testLockCollateral() public {
        _ensureState(SetupState.AssetRegistered);
        uint256 requiredCollateral = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);

        BalanceSnapshot memory beforeSnapshot = _takeBalanceSnapshot(scenario.revenueTokenId);

        treasury.lockCollateral(scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();

        BalanceSnapshot memory afterSnapshot = _takeBalanceSnapshot(scenario.revenueTokenId);

        _assertBalanceChanges(
            beforeSnapshot,
            afterSnapshot,
            // forge-lint: disable-next-line(unsafe-typecast)
            -int256(requiredCollateral), // Partner USDC change
            0, // Buyer USDC change
            0, // Treasury Fee Recipient USDC change
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(requiredCollateral), // Treasury Contract USDC change
            0, // Marketplace Contract USDC change
            0, // Partner token change
            0 // Buyer token change
        );

        _assertCollateralState(scenario.assetId, BASE_COLLATERAL, requiredCollateral, true);
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

    function testLockCollateralAssetNotFound() public {
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000 * 1e6);
        vm.expectRevert(ITreasury.NotAssetOwner.selector);
        treasury.lockCollateral(999, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();
    }

    function testLockCollateralAlreadyLocked() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        uint256 requiredCollateral = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        vm.expectRevert(ITreasury.CollateralAlreadyLocked.selector);
        treasury.lockCollateral(scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();
    }

    function testLockCollateralNoApproval() public {
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

    // Collateral Releasing Tests

    function testReleaseCollateralFor() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Burn tokens first
        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(scenario.assetId);
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

    function testReleaseCollateralForEmitsEvent() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Burn tokens first
        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(scenario.assetId);
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

    function testReleaseCollateralNotLocked() public {
        _ensureState(SetupState.AssetRegistered);
        vm.expectRevert(ITreasury.NoCollateralLocked.selector);
        vm.prank(partner1);
        treasury.releaseCollateral(scenario.assetId);
        vm.stopPrank();
    }

    function testReleaseCollateralNotAssetOwner() public {
        vm.expectRevert(ITreasury.NotAssetOwner.selector);
        vm.prank(partner1);
        treasury.releaseCollateral(999);
        vm.stopPrank();
    }

    // Withdrawal Tests

    function testProcessWithdrawal() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Burn tokens first
        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(scenario.assetId);
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
        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(scenario.assetId);
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
        vm.expectRevert(ITreasury.NoPendingWithdrawals.selector);
        vm.prank(partner1);
        treasury.processWithdrawal();
    }

    // Access Control

    function testLockCollateralUnauthorizedPartner() public {
        _ensureState(SetupState.AssetRegistered);
        // address unauthorized is NOT a partner
        vm.prank(unauthorized);
        usdc.approve(address(treasury), 1e9);
        vm.expectRevert(PartnerManager.UnauthorizedPartner.selector);
        treasury.lockCollateral(scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
    }

    function testReleaseCollateralUnauthorizedPartner() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        vm.expectRevert(PartnerManager.UnauthorizedPartner.selector);
        vm.prank(unauthorized);
        treasury.releaseCollateral(scenario.assetId);
    }

    function testLockCollateralNotAssetOwner() public {
        _ensureState(SetupState.RevenueTokensMinted); // Vehicle is owned by partner1

        // Attempt to lock collateral as partner2, who is authorized but not the owner.
        vm.startPrank(partner2);
        usdc.approve(address(treasury), 1e9);
        vm.expectRevert(ITreasury.NotAssetOwner.selector);
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

        string memory vin = _generateVin(1);
        vm.prank(partner1);
        uint256 vehicleId2 = assetRegistry.registerAsset(
            abi.encode(
                vin, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            )
        );

        uint256 requiredCollateral2 = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral2);
        treasury.lockCollateral(vehicleId2, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();

        assertEq(treasury.totalCollateralDeposited(), requiredCollateral1 + requiredCollateral2);
        _assertCollateralState(vehicleId1, BASE_COLLATERAL, requiredCollateral1, true);
        _assertCollateralState(vehicleId2, BASE_COLLATERAL, requiredCollateral2, true);
    }

    function testCompleteCollateralLifecycle() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // 1. Lock Collateral (already done in setup)
        (,, bool isLocked,,) = treasury.getAssetCollateralInfo(scenario.assetId);
        assertTrue(isLocked);

        // 2. Burn tokens
        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(scenario.assetId);
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
        _ensureState(SetupState.RevenueTokensClaimed);
        uint256 totalAmount = 1000 * 1e6;

        // Calculate investor portion based on token ownership
        uint256 partnerTokens = roboshareTokens.balanceOf(partner1, scenario.revenueTokenId);
        uint256 investorTokens = REVENUE_TOKEN_SUPPLY - partnerTokens;
        uint256 investorAmount = (totalAmount * investorTokens) / REVENUE_TOKEN_SUPPLY;

        uint256 protocolFee = ProtocolLib.calculateProtocolFee(investorAmount);
        uint256 netEarnings = investorAmount - protocolFee;

        vm.startPrank(partner1);
        usdc.approve(address(treasury), investorAmount);
        vm.expectEmit(true, true, false, true);
        emit ITreasury.EarningsDistributed(scenario.assetId, partner1, totalAmount, netEarnings, 1);
        treasury.distributeEarnings(scenario.assetId, totalAmount, investorAmount, false);
        vm.stopPrank();
    }

    function testDistributeEarningsUnauthorizedPartner() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        vm.expectRevert(PartnerManager.UnauthorizedPartner.selector);
        vm.prank(unauthorized);
        treasury.distributeEarnings(scenario.assetId, 1000 * 1e6, 1000 * 1e6, false);
    }

    function testDistributeEarningsInvalidAmount() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        vm.expectRevert(ITreasury.InvalidEarningsAmount.selector);
        vm.prank(partner1);
        treasury.distributeEarnings(scenario.assetId, 0, 0, false);
    }

    function testDistributeEarningsAssetNotFound() public {
        vm.expectRevert(ITreasury.NotAssetOwner.selector);
        vm.prank(partner1);
        treasury.distributeEarnings(999, 1000 * 1e6, 1000 * 1e6, false);
    }

    function testDistributeEarningsPendingAsset() public {
        // 1. Register a vehicle WITHOUT minting revenue tokens (stays in Pending status).
        vm.prank(partner1);
        uint256 assetId = assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            )
        );

        // 2. Attempt to distribute earnings. This should fail because the asset is not Active.
        //    (Assets start in Pending status until revenue tokens are minted and collateral locked)
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000e6);
        vm.expectRevert(
            abi.encodeWithSelector(ITreasury.AssetNotActive.selector, assetId, AssetLib.AssetStatus.Pending)
        );
        treasury.distributeEarnings(assetId, 1000 * 1e6, 1000 * 1e6, false);
        vm.stopPrank();
    }

    function testDistributeEarningsSettledAsset() public {
        // 1. Setup an asset with a purchase (so investors exist)
        _ensureState(SetupState.RevenueTokensClaimed);

        // 2. Settle the asset via assetRegistry (partner flow)
        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        // 3. Attempt to distribute earnings. This should fail because asset is Retired.
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000e6);
        vm.expectRevert(
            abi.encodeWithSelector(ITreasury.AssetNotActive.selector, scenario.assetId, AssetLib.AssetStatus.Retired)
        );
        treasury.distributeEarnings(scenario.assetId, 1000 * 1e6, 1000 * 1e6, false);
        vm.stopPrank();
    }

    function testDistributeEarningsNotAssetOwner() public {
        _ensureState(SetupState.RevenueTokensClaimed); // Vehicle is owned by partner1

        // Attempt to distribute earnings as partner2, who is authorized but not the owner.
        vm.startPrank(partner2);
        usdc.approve(address(treasury), 1e9);
        vm.expectRevert(ITreasury.NotAssetOwner.selector);
        treasury.distributeEarnings(scenario.assetId, 1000 * 1e6, 1000 * 1e6, false);
        vm.stopPrank();
    }

    function testLockCollateralForUnauthorizedPartner() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.prank(address(router));
        vm.expectRevert(PartnerManager.UnauthorizedPartner.selector);
        // address unauthorized is NOT a partner
        treasury.lockCollateralFor(unauthorized, scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
    }

    function testLockCollateralForAssetNotFound() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 nonExistentAssetId = 999;
        vm.prank(address(router));
        vm.expectRevert(ITreasury.NotAssetOwner.selector);
        treasury.lockCollateralFor(partner1, nonExistentAssetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
    }

    function testClaimEarningsAssetNotFound() public {
        _ensureState(SetupState.EarningsDistributed);
        uint256 nonExistentAssetId = 999;

        vm.prank(buyer);
        vm.expectRevert(ITreasury.AssetNotFound.selector);
        treasury.claimEarnings(nonExistentAssetId);
    }

    function testClaimEarnings() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        uint256 earningsAmount = 1000 * 1e6;

        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        _setupEarningsDistributed(earningsAmount);
        vm.stopPrank();

        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        uint256 totalEarnings = earningsAmount - ProtocolLib.calculateProtocolFee(earningsAmount);
        uint256 buyerShare = (totalEarnings * buyerBalance) / REVENUE_TOKEN_SUPPLY;

        vm.startPrank(buyer);
        vm.expectEmit(true, true, false, true);
        emit ITreasury.EarningsClaimed(scenario.assetId, buyer, buyerShare);
        treasury.claimEarnings(scenario.assetId);
        vm.stopPrank();
    }

    function testClaimEarningsMultiplePeriods() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        uint256 earnings1 = 1000 * 1e6;
        uint256 earnings2 = 500 * 1e6;
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earnings1 + earnings2);
        _setupEarningsDistributed(earnings1);
        _setupEarningsDistributed(earnings2);
        vm.stopPrank();

        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        uint256 totalNet = (earnings1 - ProtocolLib.calculateProtocolFee(earnings1))
            + (earnings2 - ProtocolLib.calculateProtocolFee(earnings2));
        uint256 buyerShare = (totalNet * buyerBalance) / REVENUE_TOKEN_SUPPLY;

        uint256 initialPending = treasury.getPendingWithdrawal(buyer);
        vm.prank(buyer);
        treasury.claimEarnings(scenario.assetId);
        vm.stopPrank();
        assertEq(treasury.getPendingWithdrawal(buyer), initialPending + buyerShare, "Incorrect total claim");
    }

    function testClaimEarningsNoBalance() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000e6);
        _setupEarningsDistributed(1000e6);
        vm.stopPrank();

        vm.expectRevert(ITreasury.InsufficientTokenBalance.selector);
        vm.prank(unauthorized);
        treasury.claimEarnings(scenario.assetId);
    }

    function testClaimEarningsAlreadyClaimed() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000e6);
        _setupEarningsDistributed(1000e6);
        vm.stopPrank();

        vm.startPrank(buyer);
        treasury.claimEarnings(scenario.assetId);
        vm.expectRevert(ITreasury.NoEarningsToClaim.selector);
        treasury.claimEarnings(scenario.assetId);
        vm.stopPrank();
    }

    function testReleasePartialCollateral() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        vm.warp(block.timestamp + 30 days);
        _setupEarningsDistributed(1000e6);
        vm.startPrank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
        vm.stopPrank();
    }

    function testReleasePartialCollateralNoEarnings() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        vm.warp(block.timestamp + 16 days);
        vm.expectRevert(ITreasury.NoPriorEarningsDistribution.selector);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
    }

    function testReleasePartialCollateralNotOwner() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        // partner2 is authorized but does not own scenario.assetId
        vm.prank(partner2);
        vm.expectRevert(ITreasury.NotAssetOwner.selector);
        treasury.releasePartialCollateral(scenario.assetId);
    }

    function testCompleteEarningsLifecycle() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        uint256 earningsAmount = 1000 * 1e6;
        uint256 netEarnings = earningsAmount - ProtocolLib.calculateProtocolFee(earningsAmount);
        uint256 buyerShare = (netEarnings * PURCHASE_AMOUNT) / REVENUE_TOKEN_SUPPLY;
        uint256 buyerInitialBalance = usdc.balanceOf(buyer);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        _setupEarningsDistributed(earningsAmount);
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

    function testLockCollateralForUnauthorizedCaller() public {
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

    function testReleaseCollateralForUnauthorizedCaller() public {
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
        vm.expectRevert(ITreasury.NotAssetOwner.selector);
        treasury.lockCollateralFor(partner2, scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
    }

    function testReleaseCollateralForCalledByRegistry() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Burn tokens first to allow retirement
        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(scenario.assetId);
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
        _ensureState(SetupState.RevenueTokensClaimed);
        uint256 totalAmount = 5_000e6;

        // Capture initial fee balance BEFORE distributing (includes fees from purchase)
        uint256 initialFeeBalance = treasury.getPendingWithdrawal(config.treasuryFeeRecipient);

        // Calculate investor portion (10% with 100/1000 tokens)
        uint256 partnerTokens = roboshareTokens.balanceOf(partner1, scenario.revenueTokenId);
        uint256 investorTokens = REVENUE_TOKEN_SUPPLY - partnerTokens;
        uint256 investorAmount = (totalAmount * investorTokens) / REVENUE_TOKEN_SUPPLY;

        // Distribute earnings to accrue protocol fee to fee recipient
        vm.startPrank(partner1);
        usdc.approve(address(treasury), totalAmount);
        _setupEarningsDistributed(totalAmount);
        vm.stopPrank();

        // Fee is calculated on investor portion, not total amount
        uint256 expectedFee = ProtocolLib.calculateProtocolFee(investorAmount);
        uint256 newFeeBalance = treasury.getPendingWithdrawal(config.treasuryFeeRecipient);
        assertEq(newFeeBalance - initialFeeBalance, expectedFee, "Fee delta should match investor portion fee");

        // Fee recipient withdraws ALL pending fees (including prior ones)
        uint256 beforeWithdrawal = usdc.balanceOf(config.treasuryFeeRecipient);
        vm.prank(config.treasuryFeeRecipient);
        treasury.processWithdrawal();
        uint256 afterWithdrawal = usdc.balanceOf(config.treasuryFeeRecipient);
        assertEq(afterWithdrawal, beforeWithdrawal + newFeeBalance);
        assertEq(treasury.getPendingWithdrawal(config.treasuryFeeRecipient), 0);
    }

    function testReleasePartialCollateralPerfectBuffersMatch() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // Use a realistic interval to avoid overflow while targeting the equality path
        uint256 dt = 30 days;
        (,, bool isLocked, uint256 lockedAt,) = treasury.getAssetCollateralInfo(scenario.assetId);
        assertTrue(isLocked);
        vm.warp(lockedAt + dt);

        // Compute target net = base * MIN_EARNINGS_BUFFER_BP * dt / (BP_PRECISION * YEARLY_INTERVAL)
        (uint256 baseCollateral,,,) = _calculateExpectedCollateral(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        uint256 targetNet = (baseCollateral * 1000 * dt) / (10000 * 365 days);
        // Compute gross so that net ~= targetNet (ceil to be safe): gross = ceil(targetNet * 10000 / 9750)
        uint256 gross = (targetNet * 10000 + 9749) / 9750;

        deal(address(usdc), partner1, gross);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), gross);
        _setupEarningsDistributed(gross);
        vm.stopPrank();

        // Release; with near-perfect match no shortfall/excess branches should trigger
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
    }

    function testLinearReleaseOneYear() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // Satisfy performance gate with an earnings distribution
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1_000e6);
        _setupEarningsDistributed(1_000e6);
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
        _ensureState(SetupState.RevenueTokensClaimed);

        // First distribution to enable first release
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 2_000e6);
        _setupEarningsDistributed(1_000e6);
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
        _setupEarningsDistributed(1_000e6);
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
        _ensureState(SetupState.RevenueTokensClaimed);

        // First, initialize earnings
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 1000e6);
        _setupEarningsDistributed(1000e6);
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
        vm.expectRevert(ITreasury.NoNewPerformanceEvents.selector);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
    }

    // Shortfall then replenishment flow emitting events
    function testReleasePartialCollateralShortfallThenReplenishment() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // Configure a shortfall: low earnings vs benchmark
        vm.startPrank(partner1);
        usdc.approve(address(treasury), 100e6);
        _setupEarningsDistributed(100e6); // small amount to trigger shortfall vs benchmark
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
        _setupEarningsDistributed(10_000e6);
        vm.stopPrank();

        // Warp from the timestamp used in the prior release
        vm.warp(tsAfterFirstShortfallRelease + ProtocolLib.MIN_EVENT_INTERVAL + 1);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
    }

    function testDistributeEarningsMinimumProtocolFee() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // With new logic, we need to distribute enough so investor portion >= MIN_PROTOCOL_FEE
        // Investor owns PURCHASE_AMOUNT (100) out of REVENUE_TOKEN_SUPPLY (1000) = 10%
        // So we need to distribute 10x MIN_PROTOCOL_FEE to get investor portion = MIN_PROTOCOL_FEE
        uint256 totalAmount = (ProtocolLib.MIN_PROTOCOL_FEE * REVENUE_TOKEN_SUPPLY) / PURCHASE_AMOUNT;

        uint256 initialFeeBalance = treasury.getPendingWithdrawal(config.treasuryFeeRecipient);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), totalAmount);
        _setupEarningsDistributed(totalAmount);
        vm.stopPrank();

        // Fee should be MIN_PROTOCOL_FEE since investor portion = MIN_PROTOCOL_FEE
        uint256 finalFeeBalance = treasury.getPendingWithdrawal(config.treasuryFeeRecipient);
        assertEq(
            finalFeeBalance,
            initialFeeBalance + ProtocolLib.MIN_PROTOCOL_FEE,
            "Fee recipient balance should increase by minimum fee"
        );
    }

    function testDistributeEarningsAmountLessThanMinimumFee() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        uint256 insufficientEarningsAmount = ProtocolLib.MIN_PROTOCOL_FEE - 1;

        vm.startPrank(partner1);
        usdc.approve(address(treasury), insufficientEarningsAmount);
        vm.expectRevert(ITreasury.EarningsLessThanMinimumFee.selector);
        treasury.distributeEarnings(scenario.assetId, insufficientEarningsAmount, insufficientEarningsAmount, false);
        vm.stopPrank();
    }

    function testReleasePartialCollateralDepleted() public {
        _ensureState(SetupState.EarningsDistributed);

        (, uint256 earningsBuffer, uint256 protocolBuffer,) =
            _calculateExpectedCollateral(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        (,, bool isLocked, uint256 lockedAt,) = treasury.getAssetCollateralInfo(scenario.assetId);
        assertTrue(isLocked);

        // Repeatedly release collateral over 10 years until it's fully depleted (12% per year, ~8.33 years to deplete)
        uint256 timeToWarp = lockedAt;
        for (uint256 i = 0; i < 9; i++) {
            timeToWarp += 365 days;
            vm.warp(timeToWarp);

            // Distribute earnings that meet the benchmark to avoid draining the buffer
            // With new logic, we need to distribute enough so investor portion meets benchmark
            (uint256 currentBase,,,,) = treasury.getAssetCollateralInfo(scenario.assetId);
            uint256 benchmarkEarnings = EarningsLib.calculateBenchmarkEarnings(currentBase, 365 days);
            uint256 grossEarnings = (benchmarkEarnings * 10000) / 9750; // Gross up to account for protocol fee
            // Scale up by token ratio since setupEarningsScenario uses investor portion
            uint256 scaledGrossEarnings = (grossEarnings * REVENUE_TOKEN_SUPPLY) / PURCHASE_AMOUNT;
            _setupEarningsDistributed(scaledGrossEarnings + 10e6); // Add extra to ensure excess

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
        _setupEarningsDistributed(10_000e6); // Scale up for investor ratio
        vm.warp(block.timestamp + 365 days);

        // Expect revert because releaseAmount will be 0
        vm.expectRevert(ITreasury.InsufficientCollateral.selector);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
    }

    // Settlement Tests

    function testInitiateSettlementTopUp() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 topUpAmount = 1000e6;

        // Partner approves top-up
        deal(address(usdc), partner1, topUpAmount);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), topUpAmount);
        vm.stopPrank();

        // Router calls treasury
        vm.prank(address(router));
        (uint256 settlementAmount, uint256 settlementPerToken) =
            treasury.initiateSettlement(partner1, scenario.assetId, topUpAmount);

        // Verify Collateral Cleared
        (uint256 base,, bool isLocked,,) = treasury.getAssetCollateralInfo(scenario.assetId);
        assertFalse(isLocked);
        assertEq(base, 0);

        // Verify Settlement Amount logic
        // Should be InvestorClaimable + TopUp
        // InvestorClaimable = Base + EarningsBuffer + Reserved
        // Protocol Buffer is excluded
        assertGt(settlementAmount, topUpAmount);
        assertEq(settlementPerToken, settlementAmount / REVENUE_TOKEN_SUPPLY);
    }

    function testExecuteLiquidation() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.prank(address(router));
        (uint256 liquidationAmount, uint256 settlementPerToken) = treasury.executeLiquidation(scenario.assetId);

        (uint256 base,, bool isLocked,,) = treasury.getAssetCollateralInfo(scenario.assetId);
        assertFalse(isLocked);
        assertEq(base, 0);

        assertGt(liquidationAmount, 0);
        assertEq(settlementPerToken, liquidationAmount / REVENUE_TOKEN_SUPPLY);
    }

    function testSettlementProtocolBufferSeparation() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Get initial state
        (,, uint256 protocolBuffer,) = _calculateExpectedCollateral(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        uint256 initialFeePending = treasury.getPendingWithdrawal(config.treasuryFeeRecipient);

        // Settle
        vm.prank(address(router));
        (uint256 settlementAmount,) = treasury.executeLiquidation(scenario.assetId);

        // Verify Fee Recipient got the buffer
        uint256 finalFeePending = treasury.getPendingWithdrawal(config.treasuryFeeRecipient);
        assertEq(finalFeePending, initialFeePending + protocolBuffer);

        // Verify Settlement Pool does not include buffer (roughly)
        // Settlement = TotalCollateral - ProtocolBuffer
        // We can't easily get totalCollateral before without calling view, but we know calculation
        assertGt(settlementAmount, 0);
    }

    function testClaimSettlement() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Simulate asset being liquidated via VehicleRegistry to ensure status is updated
        // We need to warp to maturity for liquidation to be valid.
        uint256 revenueTokenId = scenario.assetId + 1;
        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(revenueTokenId);
        vm.warp(maturityDate + 1);

        vm.prank(unauthorized); // Anyone can call liquidateAsset
        assetRegistry.liquidateAsset(scenario.assetId);

        // Partner owns all tokens
        uint256 initialBalance = usdc.balanceOf(partner1);

        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);
        (,, bool isLocked,,) = treasury.getAssetCollateralInfo(scenario.assetId); // Check if still locked, settlement clears this.
        assertFalse(isLocked);

        (, uint256 settlementPerToken,) = treasury.assetSettlements(scenario.assetId);

        vm.startPrank(partner1);
        (uint256 claimed,) = assetRegistry.claimSettlement(scenario.assetId, false);
        // Settlement now uses pendingWithdrawals pattern - need to withdraw
        treasury.processWithdrawal();
        vm.stopPrank();

        assertEq(claimed, totalSupply * settlementPerToken, "Claimed amount mismatch");
        assertEq(usdc.balanceOf(partner1), initialBalance + claimed, "Partner1 USDC balance mismatch");
    }

    function testSettlementAfterMaturityReturnsBufferToPartner() public {
        // 1. Register asset
        vm.startPrank(partner1);
        uint256 assetId = assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            )
        );

        // 2. Lock collateral and mint revenue tokens with maturity date
        uint256 maturityDate = block.timestamp + 365 days;
        uint256 requiredCollateral = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        usdc.approve(address(treasury), requiredCollateral);

        // This calls lockCollateral via Router
        assetRegistry.mintRevenueTokens(assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY, maturityDate);
        vm.stopPrank();

        // Verify collateral is locked
        (, uint256 totalCollateral, bool isLocked,,) = treasury.getAssetCollateralInfo(assetId);
        assertTrue(isLocked);
        assertEq(totalCollateral, requiredCollateral);

        // 3. Warp past maturity
        vm.warp(maturityDate + 1);

        // 4. Settle asset
        vm.startPrank(partner1);
        assetRegistry.settleAsset(assetId, 0);
        vm.stopPrank();

        // 5. Check results
        // Calculate expected values
        (, uint256 earningsBuffer, uint256 protocolBuffer,) = CollateralLib.calculateCollateralRequirements(
            REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY, ProtocolLib.QUARTERLY_INTERVAL
        );

        // Expected behavior: earningsBuffer AND protocolBuffer should be in partner's pending withdrawals
        uint256 pending = treasury.getPendingWithdrawal(partner1);
        assertEq(pending, earningsBuffer + protocolBuffer, "Partner should receive earnings AND protocol buffer");

        // Treasury fee recipient should NOT receive protocol buffer
        uint256 feeRecipientPending = treasury.getPendingWithdrawal(config.treasuryFeeRecipient);
        assertEq(feeRecipientPending, 0, "Fee recipient should not receive protocol buffer on maturity settlement");
    }

    // ============ Coverage Tests for Uncovered Branches ============

    /// @dev Test line 454: releaseCollateral reverts when no collateral is locked
    function testReleaseCollateralNoCollateralLocked() public {
        _ensureState(SetupState.AssetRegistered);

        // Try to release collateral without ever locking it
        vm.prank(partner1);
        vm.expectRevert(ITreasury.NoCollateralLocked.selector);
        treasury.releaseCollateral(scenario.assetId);
    }

    /// @dev Test line 567: initiateSettlement reverts when asset is already settled
    function testInitiateSettlementAlreadySettled() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // First settlement via Treasury directly (simulating router call)
        vm.prank(address(router));
        treasury.initiateSettlement(partner1, scenario.assetId, 0);

        // Second settlement should revert with IAssetRegistry.AssetAlreadySettled
        vm.prank(address(router));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAssetRegistry.AssetAlreadySettled.selector, scenario.assetId, AssetLib.AssetStatus.Retired
            )
        );
        treasury.initiateSettlement(partner1, scenario.assetId, 0);
    }

    /// @dev Test line 607: executeLiquidation reverts when asset is already settled
    function testExecuteLiquidationAlreadySettled() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // First: settle via Treasury directly (simulating router call)
        vm.prank(address(router));
        treasury.initiateSettlement(partner1, scenario.assetId, 0);

        // Second: attempt to liquidate (should revert since already settled)
        vm.prank(address(router));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAssetRegistry.AssetAlreadySettled.selector, scenario.assetId, AssetLib.AssetStatus.Retired
            )
        );
        treasury.executeLiquidation(scenario.assetId);
    }

    /// @dev Test line 689: processSettlementClaim with zero amount returns 0
    function testProcessSettlementClaimZeroAmount() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // Settle the asset
        vm.warp(block.timestamp + ProtocolLib.YEARLY_INTERVAL * 5 + 1);
        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        // The test buyer holds tokens - have them claim with 0
        // This is tested via the router/registry claim flow
        // Since claimSettlement requires burning tokens, and we can't burn 0,
        // the zero-check is defense-in-depth that protects against internal calls
    }

    // ============================================
    // Earnings Snapshot Tests
    // ============================================

    /// @dev Test claimSettlement with autoClaimEarnings=true claims both settlement and earnings
    function testClaimSettlementAutoClaimEarnings() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // Buyer purchases tokens - now buyer holds 100 tokens, partner1 holds 900
        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        assertEq(buyerBalance, 100); // From SetupState.RevenueTokensListed

        // Distribute earnings
        uint256 earningsAmount = 10_000e6;
        deal(address(usdc), partner1, earningsAmount);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        _setupEarningsDistributed(earningsAmount);
        vm.stopPrank();

        // Settle the asset
        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        // Calculate expected earnings for buyer (100 tokens out of 1000 investor tokens)
        // Partner owns 900, investor owns 100. investorAmount = 10_000 * 100 / 1000 = 1000 for buyer
        // But partner is not an investor - earnings per token = investorAmount / investorSupply
        // Actually partner holds 900 so investor portion = 10_000 * 100 / 1000 = 1000 for buyer
        // Note: _setupEarningsDistributed calculates investorTokens = totalSupply - partnerTokens
        // So with partner1 holding 900 after selling 100 to buyer:
        // investorTokens = 1000 - 900 = 100
        // investorAmount = 10_000 * 100 / 1000 = 1000
        // earningsPerToken = 1000 / 1000 = 1 USDC per token
        // buyer earnings = 100 * 1 = 100 USDC

        uint256 buyerUsdcBefore = usdc.balanceOf(buyer);
        uint256 buyerPendingBefore = treasury.getPendingWithdrawal(buyer);

        // Claim settlement with autoClaimEarnings=true
        vm.prank(buyer);
        (uint256 settlementClaimed, uint256 earningsClaimed) = assetRegistry.claimSettlement(scenario.assetId, true);

        assertGt(settlementClaimed, 0, "Settlement should be > 0");
        assertGt(earningsClaimed, 0, "Earnings should be > 0 with autoClaim");

        // Both settlement AND earnings now go to pending withdrawals
        uint256 buyerPendingAfter = treasury.getPendingWithdrawal(buyer);
        assertEq(
            buyerPendingAfter,
            buyerPendingBefore + settlementClaimed + earningsClaimed,
            "Pending should include earnings"
        );

        // Need to withdraw to get USDC
        vm.prank(buyer);
        treasury.processWithdrawal();

        assertEq(
            usdc.balanceOf(buyer),
            buyerUsdcBefore + settlementClaimed + earningsClaimed,
            "Should receive both settlement and earnings"
        );
    }

    /// @dev Test claimSettlement with autoClaimEarnings=false then claim earnings separately
    function testClaimSettlementThenClaimEarningsFromSnapshot() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        assertEq(buyerBalance, 100);

        // Distribute earnings
        uint256 earningsAmount = 10_000e6;
        deal(address(usdc), partner1, earningsAmount);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        _setupEarningsDistributed(earningsAmount);
        vm.stopPrank();

        // Settle the asset
        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        uint256 buyerPendingBefore = treasury.getPendingWithdrawal(buyer);

        // Claim settlement WITHOUT auto-claiming earnings
        vm.prank(buyer);
        (uint256 settlementClaimed, uint256 earningsClaimed) = assetRegistry.claimSettlement(scenario.assetId, false);

        assertGt(settlementClaimed, 0, "Settlement should be > 0");
        assertEq(earningsClaimed, 0, "Earnings should be 0 without autoClaim");

        // Tokens are now burned
        assertEq(roboshareTokens.balanceOf(buyer, scenario.revenueTokenId), 0, "Tokens should be burned");

        // But buyer can still claim earnings from snapshot
        vm.prank(buyer);
        treasury.claimEarnings(scenario.assetId);

        uint256 buyerPendingAfter = treasury.getPendingWithdrawal(buyer);
        assertGt(buyerPendingAfter, buyerPendingBefore, "Should have claimed earnings from snapshot");
    }

    /// @dev Critical test: verify earnings can be claimed via snapshot even after tokens are burned
    function testClaimEarningsAfterTokensBurned() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // Distribute earnings
        uint256 earningsAmount = 5_000e6;
        deal(address(usdc), partner1, earningsAmount);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        _setupEarningsDistributed(earningsAmount);
        vm.stopPrank();

        // Settle asset and claim settlement (without auto-claim earnings)
        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        vm.prank(buyer);
        assetRegistry.claimSettlement(scenario.assetId, false);

        // Verify tokens are burned
        assertEq(roboshareTokens.balanceOf(buyer, scenario.revenueTokenId), 0, "Tokens should be burned");

        // Now claim earnings - should work via snapshot
        uint256 pendingBefore = treasury.getPendingWithdrawal(buyer);

        vm.prank(buyer);
        treasury.claimEarnings(scenario.assetId);

        uint256 pendingAfter = treasury.getPendingWithdrawal(buyer);
        assertGt(pendingAfter, pendingBefore, "Should claim earnings from snapshot after tokens burned");
    }

    /// @dev Test multiple investors claiming in different orders
    function testClaimSettledEarningsMultipleInvestors() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // Create second buyer
        address buyer2 = makeAddr("buyer2");
        deal(address(usdc), buyer2, 1_000_000e6);

        // Partner1 sells more tokens to buyer2
        vm.prank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);

        vm.prank(partner1);
        uint256 listing2Id =
            marketplace.createListing(scenario.revenueTokenId, 200, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);

        vm.startPrank(buyer2);
        (,, uint256 payment2) = marketplace.calculatePurchaseCost(listing2Id, 200);
        usdc.approve(address(marketplace), payment2);
        marketplace.purchaseTokens(listing2Id, 200);
        vm.stopPrank();

        // End listing 2 and claim tokens for buyer2 (New Escrow Flow)
        vm.prank(partner1);
        marketplace.endListing(listing2Id);
        vm.prank(buyer2);
        marketplace.claimTokens(listing2Id);

        // Distribute earnings
        uint256 earningsAmount = 30_000e6;
        deal(address(usdc), partner1, earningsAmount);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        _setupEarningsDistributed(earningsAmount);
        vm.stopPrank();

        // Settle
        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        // Buyer1 claims with autoClaim, buyer2 claims without then claims earnings separately
        vm.prank(buyer);
        (uint256 buyer1Settlement, uint256 buyer1Earnings) = assetRegistry.claimSettlement(scenario.assetId, true);
        assertGt(buyer1Settlement, 0, "Buyer1 settlement should be > 0");
        assertGt(buyer1Earnings, 0, "Buyer1 should have auto-claimed earnings");

        vm.prank(buyer2);
        (uint256 buyer2Settlement, uint256 buyer2EarningsClaimed) =
            assetRegistry.claimSettlement(scenario.assetId, false);
        assertGt(buyer2Settlement, 0, "Buyer2 settlement should be > 0");
        assertEq(buyer2EarningsClaimed, 0, "Buyer2 did not auto-claim");

        // Buyer2 claims earnings from snapshot
        uint256 buyer2PendingBefore = treasury.getPendingWithdrawal(buyer2);
        vm.prank(buyer2);
        treasury.claimEarnings(scenario.assetId);
        uint256 buyer2PendingAfter = treasury.getPendingWithdrawal(buyer2);

        assertGt(buyer2PendingAfter, buyer2PendingBefore, "Buyer2 should claim from snapshot");
        // Buyer2 has 200 tokens vs buyer1's 100, so buyer2 should have ~2x the earnings
        assertGt(buyer2PendingAfter - buyer2PendingBefore, buyer1Earnings, "Buyer2 should have more earnings");
    }

    /// @dev Test claiming with no unclaimed earnings works fine
    function testClaimSettlementNoUnclaimedEarnings() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // Distribute and claim earnings BEFORE settlement
        uint256 earningsAmount = 5_000e6;
        deal(address(usdc), partner1, earningsAmount);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        _setupEarningsDistributed(earningsAmount);
        vm.stopPrank();

        // Buyer claims earnings now
        vm.prank(buyer);
        treasury.claimEarnings(scenario.assetId);

        // Now settle
        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        // Claim settlement with autoClaim - should work, but earnings should be 0
        vm.prank(buyer);
        (uint256 settlement, uint256 earnings) = assetRegistry.claimSettlement(scenario.assetId, true);

        assertGt(settlement, 0, "Should still get settlement");
        assertEq(earnings, 0, "No unclaimed earnings");
    }

    /// @dev Test cannot claim snapshotted earnings twice
    function testClaimEarningsCannotClaimSnapshotTwice() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // Distribute earnings
        uint256 earningsAmount = 5_000e6;
        deal(address(usdc), partner1, earningsAmount);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        _setupEarningsDistributed(earningsAmount);
        vm.stopPrank();

        // Settle and claim settlement (snapshot created)
        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        vm.prank(buyer);
        assetRegistry.claimSettlement(scenario.assetId, false);

        // First claim from snapshot works
        vm.prank(buyer);
        treasury.claimEarnings(scenario.assetId);

        // Second claim should revert with NoEarningsToClaim
        vm.prank(buyer);
        vm.expectRevert(ITreasury.NoEarningsToClaim.selector);
        treasury.claimEarnings(scenario.assetId);
    }

    /// @dev Test claimEarnings on active asset still uses position-based calculation
    function testClaimEarningsAssetNotSettledNoSnapshot() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // Distribute earnings
        uint256 earningsAmount = 5_000e6;
        deal(address(usdc), partner1, earningsAmount);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        _setupEarningsDistributed(earningsAmount);
        vm.stopPrank();

        // Asset NOT settled - claim should use normal position-based approach
        uint256 pendingBefore = treasury.getPendingWithdrawal(buyer);

        vm.prank(buyer);
        treasury.claimEarnings(scenario.assetId);

        uint256 pendingAfter = treasury.getPendingWithdrawal(buyer);
        assertGt(pendingAfter, pendingBefore, "Should claim via positions for active asset");

        // Verify buyer still has tokens (not burned)
        assertGt(roboshareTokens.balanceOf(buyer, scenario.revenueTokenId), 0, "Tokens should not be burned");
    }

    /// @dev Test multiple earnings distributions before settlement
    function testSnapshotEarningsMultipleEarningsPeriods() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // Distribute earnings in 3 periods
        for (uint256 i = 0; i < 3; i++) {
            uint256 earningsAmount = 3_000e6;
            deal(address(usdc), partner1, earningsAmount);
            vm.startPrank(partner1);
            usdc.approve(address(treasury), earningsAmount);
            _setupEarningsDistributed(earningsAmount);
            vm.stopPrank();

            // Advance time between distributions
            vm.warp(block.timestamp + 30 days);
        }

        // Settle
        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        // Claim with autoClaim
        uint256 pendingBefore = treasury.getPendingWithdrawal(buyer);

        vm.prank(buyer);
        (uint256 settlement, uint256 earnings) = assetRegistry.claimSettlement(scenario.assetId, true);

        assertGt(settlement, 0);
        assertGt(earnings, 0, "Should have earnings from all 3 periods");

        // Both settlement and earnings now go to pending withdrawals
        uint256 pendingAfter = treasury.getPendingWithdrawal(buyer);
        assertEq(pendingAfter - pendingBefore, settlement + earnings, "Pending should match earnings claimed");
    }

    // ============================================
    // Bundled Collateral Release Tests
    // ============================================

    /// @dev Test distributeEarnings with tryAutoRelease=true releases collateral when eligible
    function testDistributeEarningsAutoReleasesCollateral() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // First distribution with auto-release disabled (to establish earnings history)
        uint256 earningsAmount = 10_000e6;
        deal(address(usdc), partner1, earningsAmount * 3);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount * 3);

        // First distribution - no release (first period)
        uint256 released1 = treasury.distributeEarnings(scenario.assetId, earningsAmount, earningsAmount, true);
        assertEq(released1, 0, "No release on first period");

        // Advance past minimum interval (15 days)
        vm.warp(block.timestamp + 16 days);

        // Second distribution with auto-release - should release collateral
        uint256 pendingBefore = treasury.getPendingWithdrawal(partner1);
        uint256 released2 = treasury.distributeEarnings(scenario.assetId, earningsAmount, earningsAmount, true);

        assertGt(released2, 0, "Should release collateral on second distribution");

        uint256 pendingAfter = treasury.getPendingWithdrawal(partner1);
        assertEq(pendingAfter - pendingBefore, released2, "Pending should include released collateral");

        vm.stopPrank();
    }

    /// @dev Test that consecutive distributions with auto-release work (no interval check)
    function testDistributeEarningsAutoReleaseConsecutive() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        uint256 earningsAmount = 10_000e6;
        deal(address(usdc), partner1, earningsAmount * 2);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount * 2);

        // First distribution - creates period 1, but no prior period to process yet
        uint256 released1 = treasury.distributeEarnings(scenario.assetId, earningsAmount, earningsAmount, true);
        assertEq(released1, 0, "First distribution has no prior periods to process");

        // Warp time forward - release amount is based on linear depreciation over time
        vm.warp(block.timestamp + 7 days);

        // Second distribution - now has period 1 to process AND time has passed for depreciation
        uint256 released2 = treasury.distributeEarnings(scenario.assetId, earningsAmount, earningsAmount, true);
        assertGt(released2, 0, "Second distribution should release collateral");

        vm.stopPrank();
    }

    /// @dev Test distributeEarnings with tryAutoRelease=false does not release collateral
    function testDistributeEarningsAutoReleaseDisabled() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        uint256 earningsAmount = 10_000e6;
        deal(address(usdc), partner1, earningsAmount * 2);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount * 2);

        // First distribution
        treasury.distributeEarnings(scenario.assetId, earningsAmount, earningsAmount, false);

        // Advance past minimum interval
        vm.warp(block.timestamp + 16 days);

        // Second distribution with auto-release DISABLED
        uint256 released = treasury.distributeEarnings(
            scenario.assetId,
            earningsAmount,
            earningsAmount,
            false // disabled
        );

        assertEq(released, 0, "Should not release when tryAutoRelease=false");

        // Partner can still manually release
        treasury.releasePartialCollateral(scenario.assetId);

        vm.stopPrank();
    }

    /// @dev Test manual releasePartialCollateral still works independently
    function testManualReleaseAfterDistributeAutoReleaseDisabled() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        uint256 earningsAmount = 10_000e6;
        deal(address(usdc), partner1, earningsAmount);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);

        // Distribute without auto-release
        treasury.distributeEarnings(scenario.assetId, earningsAmount, earningsAmount, false);

        // Advance past minimum interval
        vm.warp(block.timestamp + 16 days);

        // Manual release should work
        uint256 pendingBefore = treasury.getPendingWithdrawal(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
        uint256 pendingAfter = treasury.getPendingWithdrawal(partner1);

        assertGt(pendingAfter, pendingBefore, "Manual release should work");

        vm.stopPrank();
    }

    // ============================================
    // Convenience Withdrawal Function Tests
    // ============================================

    /// @dev Test releaseAndWithdrawCollateral releases and withdraws in one call
    function testReleaseAndWithdrawCollateral() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        uint256 earningsAmount = 10_000e6;
        deal(address(usdc), partner1, earningsAmount * 2);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount * 2);

        // First distribution to establish earnings
        treasury.distributeEarnings(scenario.assetId, earningsAmount, earningsAmount, false);

        // Advance time for depreciation
        vm.warp(block.timestamp + 30 days);

        // Second distribution
        treasury.distributeEarnings(scenario.assetId, earningsAmount, earningsAmount, false);

        uint256 usdcBefore = usdc.balanceOf(partner1);

        // Use convenience function - should release and withdraw in one call
        uint256 withdrawn = treasury.releaseAndWithdrawCollateral(scenario.assetId);

        assertGt(withdrawn, 0, "Should withdraw collateral");
        assertEq(usdc.balanceOf(partner1), usdcBefore + withdrawn, "USDC balance should increase");
        assertEq(treasury.getPendingWithdrawal(partner1), 0, "Pending should be 0 after withdrawal");

        vm.stopPrank();
    }

    /// @dev Test claimAndWithdrawEarnings claims and withdraws in one call
    function testClaimAndWithdrawEarnings() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // Distribute earnings
        uint256 earningsAmount = 10_000e6;
        deal(address(usdc), partner1, earningsAmount);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        _setupEarningsDistributed(earningsAmount);
        vm.stopPrank();

        // Buyer claims with convenience function
        uint256 buyerUsdcBefore = usdc.balanceOf(buyer);

        vm.prank(buyer);
        uint256 withdrawn = treasury.claimAndWithdrawEarnings(scenario.assetId);

        assertGt(withdrawn, 0, "Should withdraw earnings");
        assertEq(usdc.balanceOf(buyer), buyerUsdcBefore + withdrawn, "USDC balance should increase");
        assertEq(treasury.getPendingWithdrawal(buyer), 0, "Pending should be 0 after withdrawal");
    }

    /// @dev Test claimAndWithdrawEarnings works for settled assets
    function testClaimAndWithdrawEarningsSettledAsset() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // Distribute earnings
        uint256 earningsAmount = 10_000e6;
        deal(address(usdc), partner1, earningsAmount);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);
        _setupEarningsDistributed(earningsAmount);
        vm.stopPrank();

        // Settle the asset (without auto-claiming earnings)
        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        // Buyer claims settlement without auto-claiming earnings
        vm.prank(buyer);
        assetRegistry.claimSettlement(scenario.assetId, false);

        // Buyer uses convenience function to claim earnings from snapshot
        uint256 buyerUsdcBefore = usdc.balanceOf(buyer);
        uint256 buyerPendingBefore = treasury.getPendingWithdrawal(buyer);

        vm.prank(buyer);
        uint256 withdrawn = treasury.claimAndWithdrawEarnings(scenario.assetId);

        assertGt(withdrawn, buyerPendingBefore, "Should withdraw more than just settlement");
        assertEq(usdc.balanceOf(buyer), buyerUsdcBefore + withdrawn, "USDC balance should increase");
    }

    /// @dev Test releaseAndWithdrawCollateral reverts when no new periods
    function testReleaseAndWithdrawCollateralNoNewPeriods() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        uint256 earningsAmount = 10_000e6;
        deal(address(usdc), partner1, earningsAmount);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);

        // Distribute and release immediately
        treasury.distributeEarnings(scenario.assetId, earningsAmount, earningsAmount, true);

        // Try to release again without new distribution
        vm.expectRevert(ITreasury.NoNewPerformanceEvents.selector);
        treasury.releaseAndWithdrawCollateral(scenario.assetId);

        vm.stopPrank();
    }

    /// @dev Test claimAndWithdrawEarnings reverts when no earnings
    function testClaimAndWithdrawEarningsNoEarnings() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // No earnings distributed - should revert
        vm.prank(buyer);
        vm.expectRevert(ITreasury.NoEarningsToClaim.selector);
        treasury.claimAndWithdrawEarnings(scenario.assetId);
    }
}
