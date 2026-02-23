// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ERC1155Holder } from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { ProtocolLib, AssetLib, TokenLib, CollateralLib, EarningsLib } from "../contracts/Libraries.sol";
import { IAssetRegistry } from "../contracts/interfaces/IAssetRegistry.sol";
import { ITreasury } from "../contracts/interfaces/ITreasury.sol";
import { PartnerManager } from "../contracts/PartnerManager.sol";
import { IMarketplace } from "../contracts/interfaces/IMarketplace.sol";
import { Treasury } from "../contracts/Treasury.sol";

contract TreasuryHarness is Treasury {
    function exposeTryReleaseCollateral(uint256 assetId, address partner) external returns (uint256) {
        return _tryReleaseCollateral(assetId, partner, true);
    }

    function exposeFundBuffers(address partner, uint256 assetId, uint256 baseAmount) external {
        _fundBuffersFor(partner, assetId, baseAmount);
    }

    function setCollateralInfo(
        uint256 assetId,
        uint256 baseCollateral,
        uint256 initialBaseCollateral,
        uint256 earningsBuffer,
        uint256 protocolBuffer,
        uint256 totalCollateral,
        bool isLocked,
        uint256 lockedAt,
        uint256 lastEventTimestamp
    ) external {
        CollateralLib.CollateralInfo storage info = assetCollateral[assetId];
        info.baseCollateral = baseCollateral;
        info.initialBaseCollateral = initialBaseCollateral;
        info.earningsBuffer = earningsBuffer;
        info.protocolBuffer = protocolBuffer;
        info.totalCollateral = totalCollateral;
        info.isLocked = isLocked;
        info.lockedAt = lockedAt;
        info.lastEventTimestamp = lastEventTimestamp;
    }

    function setEarningsInfo(
        uint256 assetId,
        bool isInitialized,
        uint256 currentPeriod,
        uint256 lastProcessedPeriod,
        uint256 lastEventTimestamp
    ) external {
        EarningsLib.EarningsInfo storage info = assetEarnings[assetId];
        info.isInitialized = isInitialized;
        info.currentPeriod = currentPeriod;
        info.lastProcessedPeriod = lastProcessedPeriod;
        info.lastEventTimestamp = lastEventTimestamp;
    }

    function setEarningsPeriod(uint256 assetId, uint256 period, uint256 totalEarnings) external {
        assetEarnings[assetId].periods[period].totalEarnings = totalEarnings;
    }

    function setSettledSnapshot(uint256 assetId, address holder, uint256 amount, bool hasClaimed) external {
        EarningsLib.EarningsInfo storage info = assetEarnings[assetId];
        info.settledEarningsSnapshot[holder] = amount;
        info.hasClaimedSettledEarnings[holder] = hasClaimed;
    }

    function exposeClearCollateral(uint256 assetId) external returns (uint256) {
        return _clearCollateral(assetId);
    }

    function exposeApplyMissedEarningsShortfall(uint256 assetId) external {
        _applyMissedEarningsShortfall(assetId);
    }

    function setTotalCollateralDeposited(uint256 amount) external {
        totalCollateralDeposited = amount;
    }
}

contract TreasuryIntegrationTest is BaseTest, ERC1155Holder {
    function setUp() public {
        // Integration tests need funded accounts and authorized partners as a baseline
        _ensureState(SetupState.InitialAccountsSetup);
    }

    // Collateral Locking Tests

    function testFundBuffersFor() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 yieldBP = roboshareTokens.getTargetYieldBP(scenario.revenueTokenId);
        uint256 requiredCollateral = treasury.getTotalBufferRequirement(ASSET_VALUE, yieldBP);
        uint256 baseAmount = ASSET_VALUE;

        vm.prank(partner1);
        usdc.approve(address(treasury), requiredCollateral);

        BalanceSnapshot memory beforeSnapshot = _takeBalanceSnapshot(scenario.revenueTokenId);

        vm.expectEmit(true, true, false, true);
        emit ITreasury.CollateralLocked(scenario.assetId, partner1, requiredCollateral);

        vm.prank(address(marketplace));
        treasury.fundBuffersFor(partner1, scenario.assetId, baseAmount);

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

        _assertCollateralState(scenario.assetId, 0, requiredCollateral, true);
        assertEq(treasury.totalCollateralDeposited(), requiredCollateral);
    }

    function testFundBuffersForInitializedBranch() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 yieldBP = roboshareTokens.getTargetYieldBP(scenario.revenueTokenId);
        uint256 requiredCollateral = treasury.getTotalBufferRequirement(ASSET_VALUE, yieldBP);

        vm.prank(partner1);
        usdc.approve(address(treasury), requiredCollateral * 2);

        vm.prank(address(marketplace));
        treasury.fundBuffersFor(partner1, scenario.assetId, ASSET_VALUE);

        vm.prank(address(marketplace));
        treasury.fundBuffersFor(partner1, scenario.assetId, ASSET_VALUE);

        CollateralLib.CollateralInfo memory info = treasury.getAssetCollateralInfo(scenario.assetId);
        assertTrue(info.isLocked);
        assertGt(info.totalCollateral, 0);
    }

    function testFundBuffersForInitializesCollateral() public {
        _ensureState(SetupState.RevenueTokensMinted);

        TreasuryHarness harness = _deployTreasuryHarness();
        vm.prank(partner1);
        usdc.approve(address(harness), type(uint256).max);

        harness.exposeFundBuffers(partner1, scenario.assetId, ASSET_VALUE);

        CollateralLib.CollateralInfo memory info = harness.getAssetCollateralInfo(scenario.assetId);
        assertTrue(info.isLocked);
        assertGt(info.totalCollateral, 0);
    }

    function testFundBuffersForLockedAtZeroBranch() public {
        _ensureState(SetupState.RevenueTokensMinted);

        TreasuryHarness harness = _deployTreasuryHarness();
        harness.setCollateralInfo(scenario.assetId, 0, 0, 1, 1, 2, true, 0, block.timestamp);

        vm.prank(partner1);
        usdc.approve(address(harness), type(uint256).max);

        harness.exposeFundBuffers(partner1, scenario.assetId, ASSET_VALUE);

        CollateralLib.CollateralInfo memory info = harness.getAssetCollateralInfo(scenario.assetId);
        assertGt(info.lockedAt, 0);
    }

    function testFundBuffersForZeroBaseAmount() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.prank(partner1);
        usdc.approve(address(treasury), type(uint256).max);

        vm.prank(address(marketplace));
        vm.expectRevert(CollateralLib.InvalidCollateralAmount.selector);
        treasury.fundBuffersFor(partner1, scenario.assetId, 0);
    }

    function testFundBuffersForAssetNotFound() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 yieldBP = roboshareTokens.getTargetYieldBP(scenario.revenueTokenId);
        uint256 requiredCollateral = treasury.getTotalBufferRequirement(ASSET_VALUE, yieldBP);
        vm.prank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        vm.prank(address(marketplace));
        vm.expectRevert(ITreasury.AssetNotFound.selector);
        treasury.fundBuffersFor(partner1, 999, ASSET_VALUE);
    }

    function testFundBuffersForAlreadyLocked() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        uint256 yieldBP = roboshareTokens.getTargetYieldBP(scenario.revenueTokenId);
        IMarketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        uint256 baseAmount = listing.soldAmount * listing.pricePerToken;
        uint256 requiredCollateral = treasury.getTotalBufferRequirement(baseAmount, yieldBP);
        uint256 initialTotal = treasury.totalCollateralDeposited();

        vm.prank(partner1);
        usdc.approve(address(treasury), requiredCollateral);

        vm.prank(address(marketplace));
        treasury.fundBuffersFor(partner1, scenario.assetId, baseAmount);

        uint256 requiredCollateralSecond = treasury.getTotalBufferRequirement(ASSET_VALUE, yieldBP);
        vm.prank(partner1);
        usdc.approve(address(treasury), requiredCollateralSecond);

        vm.prank(address(marketplace));
        treasury.fundBuffersFor(partner1, scenario.assetId, ASSET_VALUE);

        assertTrue(treasury.getAssetCollateralInfo(scenario.assetId).isLocked);
        assertEq(treasury.totalCollateralDeposited(), initialTotal + requiredCollateral + requiredCollateralSecond);
    }

    function testFundBuffersForNoApproval() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.prank(partner1);
        usdc.approve(address(treasury), 0);
        vm.prank(address(marketplace));
        vm.expectRevert();
        treasury.fundBuffersFor(partner1, scenario.assetId, ASSET_VALUE);
    }

    function testFundBuffersForInsufficientApproval() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 yieldBP = roboshareTokens.getTargetYieldBP(scenario.revenueTokenId);
        uint256 requiredCollateral = treasury.getTotalBufferRequirement(ASSET_VALUE, yieldBP);
        vm.prank(partner1);
        usdc.approve(address(treasury), requiredCollateral - 1);
        vm.prank(address(marketplace));
        vm.expectRevert();
        treasury.fundBuffersFor(partner1, scenario.assetId, ASSET_VALUE);
    }

    function testCreditBaseEscrow() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 amount = ASSET_VALUE;

        vm.expectEmit(true, false, false, true, address(treasury));
        emit ITreasury.BaseEscrowCredited(scenario.assetId, amount);

        vm.prank(address(marketplace));
        treasury.creditBaseEscrow(scenario.assetId, amount);

        CollateralLib.CollateralInfo memory info = treasury.getAssetCollateralInfo(scenario.assetId);
        assertEq(info.baseCollateral, amount);
    }

    function testCreditBaseEscrowZeroAmount() public {
        _ensureState(SetupState.RevenueTokensMinted);

        CollateralLib.CollateralInfo memory beforeInfo = treasury.getAssetCollateralInfo(scenario.assetId);

        vm.prank(address(marketplace));
        treasury.creditBaseEscrow(scenario.assetId, 0);

        CollateralLib.CollateralInfo memory afterInfo = treasury.getAssetCollateralInfo(scenario.assetId);
        assertEq(afterInfo.baseCollateral, beforeInfo.baseCollateral);
        assertEq(afterInfo.totalCollateral, beforeInfo.totalCollateral);
        assertEq(afterInfo.lockedAt, beforeInfo.lockedAt);
    }

    // Collateral Releasing Tests

    function testReleaseCollateral() public {
        _ensureState(SetupState.BuffersLocked);

        // Burn tokens first (prerequisite for full release)
        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(scenario.assetId);
        uint256 supply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);

        // Grant burner role to this test contract to simulate burning
        vm.startPrank(admin);
        roboshareTokens.grantRole(roboshareTokens.BURNER_ROLE(), address(this));
        vm.stopPrank();

        // Burn all escrowed tokens from marketplace
        roboshareTokens.burn(address(marketplace), revenueTokenId, supply);

        // Partner calls releaseCollateral
        IMarketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        uint256 baseAmount = listing.soldAmount * listing.pricePerToken;
        uint256 yieldBP = roboshareTokens.getTargetYieldBP(scenario.revenueTokenId);
        uint256 expectedRelease = treasury.getTotalBufferRequirement(baseAmount, yieldBP);
        vm.prank(partner1);
        vm.expectEmit(true, true, false, true, address(treasury));
        emit ITreasury.CollateralReleased(scenario.assetId, partner1, expectedRelease);
        treasury.releaseCollateral(scenario.assetId);

        assertFalse(treasury.getAssetCollateralInfo(scenario.assetId).isLocked);
    }

    function testReleaseCollateralFor() public {
        _ensureState(SetupState.BuffersLocked);

        // Burn tokens first
        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(scenario.assetId);
        uint256 supply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);

        vm.startPrank(admin);
        roboshareTokens.grantRole(roboshareTokens.BURNER_ROLE(), address(this));
        vm.stopPrank();

        // Burn all escrowed tokens from marketplace
        roboshareTokens.burn(address(marketplace), revenueTokenId, supply);

        IMarketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        uint256 baseAmount = listing.soldAmount * listing.pricePerToken;
        uint256 yieldBP = roboshareTokens.getTargetYieldBP(scenario.revenueTokenId);
        uint256 expectedRelease = treasury.getTotalBufferRequirement(baseAmount, yieldBP);
        vm.prank(address(router));
        vm.expectEmit(true, true, false, true, address(treasury));
        emit ITreasury.CollateralReleased(scenario.assetId, partner1, expectedRelease);
        treasury.releaseCollateralFor(partner1, scenario.assetId);

        assertFalse(treasury.getAssetCollateralInfo(scenario.assetId).isLocked);
    }

    function testReleaseCollateralNotLocked() public {
        _ensureState(SetupState.AssetRegistered);
        vm.expectRevert(ITreasury.NoCollateralLocked.selector);
        vm.prank(partner1);
        treasury.releaseCollateral(scenario.assetId);
        vm.stopPrank();
    }

    function testReleasePartialCollateralNotLocked() public {
        _ensureState(SetupState.AssetRegistered);
        vm.expectRevert(ITreasury.NoCollateralLocked.selector);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
        vm.stopPrank();
    }

    function testReleasePartialCollateralNoEarningsPeriod() public {
        _ensureState(SetupState.BuffersLocked);

        vm.prank(partner1);
        vm.expectRevert(ITreasury.NoPriorEarningsDistribution.selector);
        treasury.releasePartialCollateral(scenario.assetId);
    }

    function testPreviewCollateralReleaseReturnsZeroWithoutEarnings() public {
        _ensureState(SetupState.BuffersLocked);

        uint256 preview = treasury.previewCollateralRelease(scenario.assetId, false);
        assertEq(preview, 0, "Preview should be zero without earnings");
    }

    function testPreviewCollateralReleaseMatchesReleasePartial() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        _setupEarningsDistributed(LARGE_EARNINGS_AMOUNT);

        vm.warp(block.timestamp + ProtocolLib.YEARLY_INTERVAL);

        uint256 preview = treasury.previewCollateralRelease(scenario.assetId, false);
        uint256 beforeRelease = treasury.getPendingWithdrawal(partner1);

        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);

        uint256 afterRelease = treasury.getPendingWithdrawal(partner1);
        assertEq(afterRelease - beforeRelease, preview, "Preview should match actual release");
        assertGt(preview, 0, "Preview should be greater than zero");
    }

    function testReleasePartialCollateralNoNewPeriods() public {
        _ensureState(SetupState.EarningsDistributed);

        vm.warp(block.timestamp + 1 days);

        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
    }

    function testReleaseCollateralNotAssetOwner() public {
        vm.expectRevert(ITreasury.NotAssetOwner.selector);
        vm.prank(partner1);
        treasury.releaseCollateral(999);
        vm.stopPrank();
    }

    // Withdrawal Tests

    function testProcessWithdrawal() public {
        _ensureState(SetupState.BuffersLocked);

        // Burn tokens first
        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(scenario.assetId);
        uint256 supply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);

        vm.startPrank(admin);
        roboshareTokens.grantRole(roboshareTokens.BURNER_ROLE(), address(this));
        vm.stopPrank();

        roboshareTokens.burn(address(marketplace), revenueTokenId, supply);

        vm.prank(address(router));
        treasury.releaseCollateralFor(partner1, scenario.assetId);

        uint256 initialBalance = usdc.balanceOf(partner1);
        uint256 pending = treasury.getPendingWithdrawal(partner1);

        vm.prank(partner1);
        vm.expectEmit(true, true, false, true, address(treasury));
        emit ITreasury.WithdrawalProcessed(partner1, pending);
        treasury.processWithdrawal();

        assertEq(usdc.balanceOf(partner1), initialBalance + pending);
        assertEq(treasury.getPendingWithdrawal(partner1), 0);
    }

    function testProcessWithdrawalNoPendingWithdrawals() public {
        vm.expectRevert(ITreasury.NoPendingWithdrawals.selector);
        vm.prank(partner1);
        treasury.processWithdrawal();
    }

    // Access Control

    function testReleaseCollateralUnauthorizedPartner() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        vm.expectRevert(PartnerManager.UnauthorizedPartner.selector);
        vm.prank(unauthorized);
        treasury.releaseCollateral(scenario.assetId);
    }

    // View Functions

    function testGetTreasuryStats() public {
        _ensureState(SetupState.AssetRegistered);
        (uint256 deposited0, uint256 balance0) = treasury.getTreasuryStats();
        assertEq(deposited0, 0);
        assertEq(balance0, 0);

        _ensureState(SetupState.RevenueTokensMinted);
        (uint256 deposited1, uint256 balance1) = treasury.getTreasuryStats();
        assertEq(deposited1, 0);
        assertEq(balance1, 0);
    }

    function testGetAssetCollateralInfoUninitialized() public view {
        CollateralLib.CollateralInfo memory info = treasury.getAssetCollateralInfo(scenario.assetId);
        assertEq(info.baseCollateral, 0);
        assertEq(info.totalCollateral, 0);
        assertEq(info.isLocked, false);
    }

    // Complex Scenarios

    function testMultipleAssetCollateralLocking() public {
        _ensureState(SetupState.RevenueTokensMinted); // First vehicle for partner1
        uint256 vehicleId1 = scenario.assetId;
        uint256 yieldBP1 = roboshareTokens.getTargetYieldBP(scenario.revenueTokenId);
        uint256 requiredCollateral1 = treasury.getTotalBufferRequirement(ASSET_VALUE, yieldBP1);
        vm.prank(partner1);
        usdc.approve(address(treasury), requiredCollateral1);
        vm.prank(address(marketplace));
        treasury.fundBuffersFor(partner1, vehicleId1, ASSET_VALUE);

        string memory vin = _generateVin(1);
        vm.prank(partner1);
        uint256 vehicleId2 = assetRegistry.registerAsset(
            abi.encode(
                vin, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            ),
            ASSET_VALUE
        );

        uint256 revenueTokenId2 = TokenLib.getTokenIdFromAssetId(vehicleId2);
        uint256 maturityDate = block.timestamp + 365 days;
        uint256 supply = ASSET_VALUE / REVENUE_TOKEN_PRICE;
        vm.startPrank(admin);
        roboshareTokens.setRevenueTokenInfo(revenueTokenId2, REVENUE_TOKEN_PRICE, supply, maturityDate, 10_000, 1_000);
        vm.stopPrank();
        _mintRevenueTokensToEscrow(revenueTokenId2, supply);

        uint256 yieldBP2 = roboshareTokens.getTargetYieldBP(revenueTokenId2);
        uint256 requiredCollateral2 = treasury.getTotalBufferRequirement(ASSET_VALUE, yieldBP2);
        vm.prank(partner1);
        usdc.approve(address(treasury), requiredCollateral2);
        vm.prank(address(marketplace));
        treasury.fundBuffersFor(partner1, vehicleId2, ASSET_VALUE);

        assertEq(treasury.totalCollateralDeposited(), requiredCollateral1 + requiredCollateral2);
        _assertCollateralState(vehicleId1, 0, requiredCollateral1, true);
        _assertCollateralState(vehicleId2, 0, requiredCollateral2, true);
    }

    function testCompleteCollateralLifecycle() public {
        _ensureState(SetupState.BuffersLocked);

        // 1. Lock Collateral (already done in setup)
        assertTrue(treasury.getAssetCollateralInfo(scenario.assetId).isLocked);

        // 2. Burn tokens
        uint256 revenueTokenId = TokenLib.getTokenIdFromAssetId(scenario.assetId);
        uint256 supply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);

        vm.startPrank(admin);
        roboshareTokens.grantRole(roboshareTokens.BURNER_ROLE(), address(this));
        vm.stopPrank();

        roboshareTokens.burn(address(marketplace), revenueTokenId, supply);

        // 3. Unlock Collateral
        vm.prank(address(router));
        treasury.releaseCollateralFor(partner1, scenario.assetId);

        assertFalse(treasury.getAssetCollateralInfo(scenario.assetId).isLocked);

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
        uint256 earningsAmount = EARNINGS_AMOUNT;

        // Calculate investor portion based on token ownership
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        uint256 investorTokens = roboshareTokens.getSoldSupply(scenario.revenueTokenId);
        uint256 revenueShareBP = roboshareTokens.getRevenueShareBP(scenario.revenueTokenId);
        uint256 cap = (earningsAmount * revenueShareBP) / ProtocolLib.BP_PRECISION;
        uint256 soldShare = (earningsAmount * investorTokens) / totalSupply;
        uint256 investorAmount = soldShare < cap ? soldShare : cap;

        uint256 protocolFee = ProtocolLib.calculateProtocolFee(investorAmount);
        uint256 netEarnings = investorAmount - protocolFee;

        uint256 treasuryBalanceBefore = usdc.balanceOf(address(treasury));

        vm.startPrank(partner1);
        usdc.approve(address(treasury), investorAmount);
        vm.expectEmit(true, true, false, true);
        emit ITreasury.EarningsDistributed(scenario.assetId, partner1, earningsAmount, netEarnings, 1);
        treasury.distributeEarnings(scenario.assetId, earningsAmount, false);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(treasury)), treasuryBalanceBefore + investorAmount, "Treasury balance mismatch");
    }

    function testDistributeEarningsExcludesPartnerHoldings() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        uint256 earningsAmount = EARNINGS_AMOUNT;

        uint256 revenueTokenId = scenario.revenueTokenId;
        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, revenueTokenId);
        uint256 transferAmount = buyerBalance / 2;

        vm.prank(buyer);
        roboshareTokens.safeTransferFrom(buyer, partner1, revenueTokenId, transferAmount, "");

        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);
        uint256 soldSupply = roboshareTokens.getSoldSupply(revenueTokenId);
        uint256 investorSupply = soldSupply - transferAmount;
        uint256 revenueShareBP = roboshareTokens.getRevenueShareBP(revenueTokenId);
        uint256 cap = (earningsAmount * revenueShareBP) / ProtocolLib.BP_PRECISION;
        uint256 soldShare = (earningsAmount * investorSupply) / totalSupply;
        uint256 investorAmount = soldShare < cap ? soldShare : cap;

        uint256 treasuryBalanceBefore = usdc.balanceOf(address(treasury));

        vm.startPrank(partner1);
        usdc.approve(address(treasury), investorAmount);
        treasury.distributeEarnings(scenario.assetId, earningsAmount, false);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(treasury)), treasuryBalanceBefore + investorAmount, "Treasury balance mismatch");

        vm.prank(partner1);
        vm.expectRevert(ITreasury.NoEarningsToClaim.selector);
        treasury.claimEarnings(scenario.assetId);
    }

    function testDistributeEarningsNoInvestors() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), EARNINGS_AMOUNT);
        vm.expectRevert(ITreasury.NoInvestors.selector);
        treasury.distributeEarnings(scenario.assetId, EARNINGS_AMOUNT, false);
        vm.stopPrank();
    }

    function testDistributeEarningsUnauthorizedPartner() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        vm.expectRevert(PartnerManager.UnauthorizedPartner.selector);
        vm.prank(unauthorized);
        treasury.distributeEarnings(scenario.assetId, EARNINGS_AMOUNT, false);
    }

    function testDistributeEarningsInvalidAmount() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // Case 1: Zero amount
        vm.expectRevert(ITreasury.InvalidEarningsAmount.selector);
        vm.prank(partner1);
        treasury.distributeEarnings(scenario.assetId, 0, false);
    }

    function testDistributeEarningsAssetNotFound() public {
        vm.expectRevert(ITreasury.NotAssetOwner.selector);
        vm.prank(partner1);
        treasury.distributeEarnings(999, EARNINGS_AMOUNT, false);
    }

    function testDistributeEarningsPendingAsset() public {
        _ensureState(SetupState.AssetRegistered);

        // Asset is in Pending status until revenue tokens are minted and collateral locked
        vm.startPrank(partner1);
        usdc.approve(address(treasury), EARNINGS_AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(ITreasury.AssetNotActive.selector, scenario.assetId, AssetLib.AssetStatus.Pending)
        );
        treasury.distributeEarnings(scenario.assetId, EARNINGS_AMOUNT, false);
        vm.stopPrank();
    }

    function testDistributeEarningsNoInvestorsSoldSupplyZero() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), EARNINGS_AMOUNT);
        vm.expectRevert(ITreasury.NoInvestors.selector);
        treasury.distributeEarnings(scenario.assetId, EARNINGS_AMOUNT, false);
        vm.stopPrank();
    }

    function testDistributeEarningsNoInvestorsPartnerOwnsSoldSupply() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        vm.prank(buyer);
        roboshareTokens.safeTransferFrom(buyer, partner1, scenario.revenueTokenId, PURCHASE_AMOUNT, "");

        vm.startPrank(partner1);
        usdc.approve(address(treasury), EARNINGS_AMOUNT);
        vm.expectRevert(ITreasury.NoInvestors.selector);
        treasury.distributeEarnings(scenario.assetId, EARNINGS_AMOUNT, false);
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
        usdc.approve(address(treasury), EARNINGS_AMOUNT);
        vm.expectRevert(
            abi.encodeWithSelector(ITreasury.AssetNotActive.selector, scenario.assetId, AssetLib.AssetStatus.Retired)
        );
        treasury.distributeEarnings(scenario.assetId, EARNINGS_AMOUNT, false);
        vm.stopPrank();
    }

    function testDistributeEarningsNotAssetOwner() public {
        _ensureState(SetupState.RevenueTokensClaimed); // Vehicle is owned by partner1

        // Attempt to distribute earnings as partner2, who is authorized but not the owner.
        vm.startPrank(partner2);
        usdc.approve(address(treasury), 1e9);
        vm.expectRevert(ITreasury.NotAssetOwner.selector);
        treasury.distributeEarnings(scenario.assetId, EARNINGS_AMOUNT, false);
        vm.stopPrank();
    }

    function testFundBuffersForUnauthorizedPartner() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.prank(address(marketplace));
        vm.expectRevert(PartnerManager.UnauthorizedPartner.selector);
        // address unauthorized is NOT a partner
        treasury.fundBuffersFor(unauthorized, scenario.assetId, ASSET_VALUE);
    }

    function testClaimEarningsAssetNotFound() public {
        _ensureState(SetupState.EarningsDistributed);
        uint256 nonExistentAssetId = 999;

        vm.prank(buyer);
        vm.expectRevert(ITreasury.AssetNotFound.selector);
        treasury.claimEarnings(nonExistentAssetId);
    }

    function testPreviewClaimEarningsAssetNotFound() public {
        _ensureState(SetupState.EarningsDistributed);
        uint256 nonExistentAssetId = 999;

        vm.expectRevert(ITreasury.AssetNotFound.selector);
        treasury.previewClaimEarnings(nonExistentAssetId, buyer);
    }

    function testPreviewSettlementClaimAssetNotFound() public {
        _ensureState(SetupState.EarningsDistributed);
        uint256 nonExistentAssetId = 999;

        vm.expectRevert(ITreasury.AssetNotFound.selector);
        treasury.previewSettlementClaim(nonExistentAssetId, buyer);
    }

    function testPreviewSettlementClaimNotSettledReturnsZero() public {
        _ensureState(SetupState.EarningsDistributed);
        assertEq(treasury.previewSettlementClaim(scenario.assetId, buyer), 0, "Not settled should preview zero");
    }

    function testPreviewSettlementClaimSettledMatchesClaim() public {
        _ensureState(SetupState.EarningsDistributed);

        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        uint256 previewAmount = treasury.previewSettlementClaim(scenario.assetId, buyer);
        assertGt(previewAmount, 0, "Settled preview should be positive");

        vm.prank(buyer);
        (uint256 settlementClaimed,) = assetRegistry.claimSettlement(scenario.assetId, false);

        assertEq(settlementClaimed, previewAmount, "Preview should match settlement claimed");
        assertEq(treasury.previewSettlementClaim(scenario.assetId, buyer), 0, "Preview should be zero after claim");
    }

    function testPreviewClaimEarningsActiveMatchesClaim() public {
        _ensureState(SetupState.EarningsDistributed);

        uint256 previewAmount = treasury.previewClaimEarnings(scenario.assetId, buyer);
        assertGt(previewAmount, 0, "Preview should show claimable earnings");

        uint256 pendingBefore = treasury.getPendingWithdrawal(buyer);
        vm.prank(buyer);
        treasury.claimEarnings(scenario.assetId);
        uint256 pendingAfter = treasury.getPendingWithdrawal(buyer);

        assertEq(pendingAfter - pendingBefore, previewAmount, "Preview should match claimed amount");
        assertEq(treasury.previewClaimEarnings(scenario.assetId, buyer), 0, "Preview should be zero after claim");
    }

    function testPreviewClaimEarningsNoTokenBalanceReturnsZero() public {
        _ensureState(SetupState.EarningsDistributed);
        assertEq(treasury.previewClaimEarnings(scenario.assetId, unauthorized), 0, "No balance should preview zero");
    }

    function testPreviewClaimEarningsNoEarningsInitialized() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        assertEq(treasury.previewClaimEarnings(scenario.assetId, buyer), 0, "No earnings should preview zero");
    }

    function testPreviewClaimEarningsAssetOwner() public {
        _ensureState(SetupState.EarningsDistributed);
        assertEq(treasury.previewClaimEarnings(scenario.assetId, partner1), 0, "Asset owner should preview zero");
    }

    function testPreviewClaimEarningsSettledSnapshotLifecycle() public {
        _ensureState(SetupState.EarningsDistributed);

        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        vm.prank(buyer);
        assetRegistry.claimSettlement(scenario.assetId, false);

        uint256 previewAmount = treasury.previewClaimEarnings(scenario.assetId, buyer);
        assertGt(previewAmount, 0, "Settled preview should come from snapshot");

        uint256 pendingBefore = treasury.getPendingWithdrawal(buyer);
        vm.prank(buyer);
        treasury.claimEarnings(scenario.assetId);
        uint256 pendingAfter = treasury.getPendingWithdrawal(buyer);

        assertEq(pendingAfter - pendingBefore, previewAmount, "Settled preview should match claimed amount");
        assertEq(
            treasury.previewClaimEarnings(scenario.assetId, buyer), 0, "Settled preview should be zero after claim"
        );
    }

    function testClaimEarnings() public {
        _ensureState(SetupState.EarningsDistributed);
        uint256 earningsAmount = EARNINGS_AMOUNT;

        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        uint256 investorTokens = roboshareTokens.getSoldSupply(scenario.revenueTokenId);
        uint256 revenueShareBP = roboshareTokens.getRevenueShareBP(scenario.revenueTokenId);
        uint256 cap = (earningsAmount * revenueShareBP) / ProtocolLib.BP_PRECISION;
        uint256 soldShare = (earningsAmount * investorTokens) / totalSupply;
        uint256 investorAmount = soldShare < cap ? soldShare : cap;
        uint256 netEarnings = investorAmount - ProtocolLib.calculateProtocolFee(investorAmount);

        uint256 buyerShare = (netEarnings * buyerBalance) / investorTokens;

        uint256 pendingBefore = treasury.getPendingWithdrawal(buyer);

        vm.startPrank(buyer);
        vm.expectEmit(true, true, false, true);
        emit ITreasury.EarningsClaimed(scenario.assetId, buyer, buyerShare);
        treasury.claimEarnings(scenario.assetId);
        vm.stopPrank();

        assertEq(treasury.getPendingWithdrawal(buyer), pendingBefore + buyerShare, "Pending withdrawal mismatch");
    }

    function testClaimEarningsMultiplePeriods() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        uint256 earnings1 = EARNINGS_AMOUNT;
        uint256 earnings2 = 500 * 1e6;
        _setupEarningsDistributed(earnings1);
        _setupEarningsDistributed(earnings2);

        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        uint256 investorTokens = roboshareTokens.getSoldSupply(scenario.revenueTokenId);
        uint256 revenueShareBP = roboshareTokens.getRevenueShareBP(scenario.revenueTokenId);
        uint256 cap1 = (earnings1 * revenueShareBP) / ProtocolLib.BP_PRECISION;
        uint256 soldShare1 = (earnings1 * investorTokens) / totalSupply;
        uint256 investorAmount1 = soldShare1 < cap1 ? soldShare1 : cap1;
        uint256 cap2 = (earnings2 * revenueShareBP) / ProtocolLib.BP_PRECISION;
        uint256 soldShare2 = (earnings2 * investorTokens) / totalSupply;
        uint256 investorAmount2 = soldShare2 < cap2 ? soldShare2 : cap2;
        uint256 totalNet = (investorAmount1 - ProtocolLib.calculateProtocolFee(investorAmount1))
            + (investorAmount2 - ProtocolLib.calculateProtocolFee(investorAmount2));

        uint256 buyerShare = (totalNet * buyerBalance) / investorTokens;

        uint256 initialPending = treasury.getPendingWithdrawal(buyer);
        vm.prank(buyer);
        treasury.claimEarnings(scenario.assetId);
        vm.stopPrank();
        assertEq(treasury.getPendingWithdrawal(buyer), initialPending + buyerShare, "Incorrect total claim");
    }

    function testClaimEarningsSettledAssetUsesSnapshot() public {
        _ensureState(SetupState.EarningsDistributed);

        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        vm.prank(buyer);
        assetRegistry.claimSettlement(scenario.assetId, false);

        uint256 beforePending = treasury.getPendingWithdrawal(buyer);
        vm.prank(buyer);
        treasury.claimEarnings(scenario.assetId);
        uint256 afterPending = treasury.getPendingWithdrawal(buyer);

        assertGt(afterPending, beforePending);
    }

    function testClaimEarningsNoBalance() public {
        _ensureState(SetupState.EarningsDistributed);

        vm.expectRevert(ITreasury.InsufficientTokenBalance.selector);
        vm.prank(unauthorized);
        treasury.claimEarnings(scenario.assetId);
    }

    function testClaimEarningsAlreadyClaimed() public {
        _ensureState(SetupState.EarningsDistributed);

        vm.startPrank(buyer);
        treasury.claimEarnings(scenario.assetId);
        vm.expectRevert(ITreasury.NoEarningsToClaim.selector);
        treasury.claimEarnings(scenario.assetId);
        vm.stopPrank();
    }

    function testReleasePartialCollateral() public {
        _ensureState(SetupState.EarningsDistributed);
        vm.warp(block.timestamp + 30 days);

        uint256 pendingBefore = treasury.getPendingWithdrawal(partner1);

        vm.startPrank(partner1);
        vm.expectEmit(true, true, false, false, address(treasury));
        emit ITreasury.CollateralReleased(scenario.assetId, partner1, 0); // Amount check via assert below
        treasury.releasePartialCollateral(scenario.assetId);
        vm.stopPrank();

        assertGt(treasury.getPendingWithdrawal(partner1), pendingBefore, "Collateral should be released");
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
        _ensureState(SetupState.EarningsDistributed);

        uint256 buyerInitialBalance = usdc.balanceOf(buyer);

        // earningsAmount is already distributed via _ensureState(SetupState.EarningsDistributed)
        uint256 earningsAmount = EARNINGS_AMOUNT;

        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        uint256 investorTokens = roboshareTokens.getSoldSupply(scenario.revenueTokenId);
        uint256 revenueShareBP = roboshareTokens.getRevenueShareBP(scenario.revenueTokenId);
        uint256 cap = (earningsAmount * revenueShareBP) / ProtocolLib.BP_PRECISION;
        uint256 soldShare = (earningsAmount * investorTokens) / totalSupply;
        uint256 investorAmount = soldShare < cap ? soldShare : cap;
        uint256 netEarnings = investorAmount - ProtocolLib.calculateProtocolFee(investorAmount);

        uint256 buyerShare = (netEarnings * buyerBalance) / investorTokens;

        vm.startPrank(buyer);
        vm.expectEmit(true, true, false, true, address(treasury));
        emit ITreasury.EarningsClaimed(scenario.assetId, buyer, buyerShare);
        treasury.claimEarnings(scenario.assetId);

        vm.expectEmit(true, false, false, true, address(treasury));
        emit ITreasury.WithdrawalProcessed(buyer, buyerShare);
        treasury.processWithdrawal();
        vm.stopPrank();

        assertEq(usdc.balanceOf(buyer), buyerInitialBalance + buyerShare);
    }

    function testFundBuffersForUnauthorizedCaller() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                treasury.AUTHORIZED_CONTRACT_ROLE()
            )
        );
        vm.prank(unauthorized);
        treasury.fundBuffersFor(partner1, scenario.assetId, ASSET_VALUE);
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

    function testFundBuffersForNotAssetOwner() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.prank(address(marketplace));
        vm.expectRevert(ITreasury.NotAssetOwner.selector);
        treasury.fundBuffersFor(partner2, scenario.assetId, ASSET_VALUE);
    }

    function testTreasuryFeeRecipientWithdrawal() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // Capture initial fee balance BEFORE distributing (includes fees from purchase)
        uint256 initialFeeBalance = treasury.getPendingWithdrawal(config.treasuryFeeRecipient);

        _ensureState(SetupState.EarningsDistributed);
        uint256 totalAmount = EARNINGS_AMOUNT;

        // Calculate investor portion (10% with 100/1000 tokens)
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        uint256 investorTokens = roboshareTokens.getSoldSupply(scenario.revenueTokenId);
        uint256 revenueShareBP = roboshareTokens.getRevenueShareBP(scenario.revenueTokenId);
        uint256 cap = (totalAmount * revenueShareBP) / ProtocolLib.BP_PRECISION;
        uint256 soldShare = (totalAmount * investorTokens) / totalSupply;
        uint256 investorAmount = soldShare < cap ? soldShare : cap;

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
        CollateralLib.CollateralInfo memory info = treasury.getAssetCollateralInfo(scenario.assetId);
        assertTrue(info.isLocked);
        vm.warp(info.lockedAt + dt);

        // Compute target net = base * BENCHMARK_YIELD_BP * dt / (BP_PRECISION * YEARLY_INTERVAL)
        uint256 baseCollateral = info.baseCollateral;
        uint256 targetNet = (baseCollateral * ProtocolLib.BENCHMARK_YIELD_BP * dt)
            / (ProtocolLib.BP_PRECISION * ProtocolLib.YEARLY_INTERVAL);

        // Compute gross so that net ~= targetNet (ceil to be safe): gross = ceil(targetNet * BP_PRECISION / (BP_PRECISION - PROTOCOL_FEE_BP))
        uint256 netMultiplier = ProtocolLib.BP_PRECISION - ProtocolLib.PROTOCOL_FEE_BP;
        uint256 gross = (targetNet * ProtocolLib.BP_PRECISION + (netMultiplier - 1)) / netMultiplier;

        _setupEarningsDistributed(gross);

        uint256 pendingBefore = treasury.getPendingWithdrawal(partner1);

        // Release; with near-perfect match no shortfall/excess branches should trigger
        vm.prank(partner1);
        vm.expectEmit(true, true, false, false, address(treasury));
        emit ITreasury.CollateralReleased(scenario.assetId, partner1, 0);
        treasury.releasePartialCollateral(scenario.assetId);

        uint256 pendingAfter = treasury.getPendingWithdrawal(partner1);
        assertGt(pendingAfter, pendingBefore, "Collateral should be released");
    }

    function testLinearReleaseOneYear() public {
        _ensureState(SetupState.EarningsDistributed);

        // Read initial lockedAt and base
        CollateralLib.CollateralInfo memory infoBefore = treasury.getAssetCollateralInfo(scenario.assetId);
        assertTrue(infoBefore.isLocked);

        // Warp one year from lock and release
        vm.warp(infoBefore.lockedAt + 365 days);

        // Distribute earnings to meet benchmark and keep buffer healthy
        _setupEarningsDistributed(LARGE_EARNINGS_AMOUNT);

        uint256 pendingBefore = treasury.getPendingWithdrawal(partner1);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);

        CollateralLib.CollateralInfo memory infoAfter = treasury.getAssetCollateralInfo(scenario.assetId);

        // Expected linear release = 12% of initial base
        uint256 expectedRelease = (infoBefore.baseCollateral * 1200) / 10000;
        assertEq(
            infoAfter.baseCollateral,
            infoBefore.baseCollateral - expectedRelease,
            "Linear one-year base release mismatch"
        );

        // Pending increased by net release (after protocol fee); total decreased equally (buffers unchanged)
        uint256 pendingAfter = treasury.getPendingWithdrawal(partner1);
        uint256 expectedFee = ProtocolLib.calculateProtocolFee(expectedRelease);
        uint256 expectedNet = expectedRelease - expectedFee;
        assertEq(pendingAfter - pendingBefore, expectedNet, "Pending increase mismatch");
    }

    function testLinearReleaseCumulativeEighteenMonths() public {
        _ensureState(SetupState.EarningsDistributed);

        // Read initial lockedAt and base
        CollateralLib.CollateralInfo memory infoInitial = treasury.getAssetCollateralInfo(scenario.assetId);
        assertTrue(infoInitial.isLocked);

        // First release: 12 months (12% expected)
        vm.warp(infoInitial.lockedAt + 365 days);

        // Distribute earnings to meet benchmark
        _setupEarningsDistributed(LARGE_EARNINGS_AMOUNT);

        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);

        // Second release: another 6 months (18 months total, 18% cumulative expected)
        vm.warp(infoInitial.lockedAt + 365 days + 182 days);

        // Distribute earnings again to meet benchmark
        _setupEarningsDistributed(LARGE_EARNINGS_AMOUNT);

        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);

        CollateralLib.CollateralInfo memory infoFinal = treasury.getAssetCollateralInfo(scenario.assetId);

        // Expected cumulative linear release based on total elapsed days (365 + 182)
        uint256 dt = 365 days + 182 days;
        uint256 expectedCumulative = (infoInitial.baseCollateral * ProtocolLib.DEPRECIATION_RATE_BP * dt)
            / (ProtocolLib.BP_PRECISION * ProtocolLib.YEARLY_INTERVAL);
        assertEq(
            infoFinal.baseCollateral,
            infoInitial.baseCollateral - expectedCumulative,
            "Linear 18-month cumulative base release mismatch"
        );
    }

    // Releasing without new earnings periods should revert (performance gate)
    function testReleasePartialCollateralNoNewEarningsPeriods() public {
        _ensureState(SetupState.EarningsDistributed);

        // Warp relative to the original lock timestamp before first release
        CollateralLib.CollateralInfo memory info = treasury.getAssetCollateralInfo(scenario.assetId);
        vm.warp(info.lockedAt + ProtocolLib.MIN_EVENT_INTERVAL + 1);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId); // updates lastEventTimestamp

        // Capture the timestamp used by the prior release and warp from it
        uint256 tsAfterFirstRelease = block.timestamp;
        vm.warp(tsAfterFirstRelease + ProtocolLib.MIN_EVENT_INTERVAL + 1);
        vm.expectRevert(ITreasury.NoNewEarningsPeriods.selector);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
    }

    // Shortfall then replenishment flow emitting events
    function testReleasePartialCollateralShortfallThenReplenishment() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        CollateralLib.CollateralInfo memory info = treasury.getAssetCollateralInfo(scenario.assetId);
        assertTrue(info.isLocked);

        // 1. Warp 3 years BEFORE distributing to ensure a massive shortfall
        // Benchmark for 3 years (30% of investor value = 3k) exceeds initial buffer (~2.5k)
        vm.warp(info.lockedAt + (3 * 365 days));

        // 2. Distribute minimal earnings (near-zero performance)
        _setupEarningsDistributed(SMALL_EARNINGS_AMOUNT);

        // 3. Process the pending Period 1 shortfall
        // This will drain the buffer.
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);

        // Verify buffer is drained
        CollateralLib.CollateralInfo memory infoAfterShortfall = treasury.getAssetCollateralInfo(scenario.assetId);
        assertEq(infoAfterShortfall.earningsBuffer, 0, "Buffer should be drained to zero");
        assertGt(infoAfterShortfall.reservedForLiquidation, 0, "Should have funds reserved for liquidation");

        // 4. Release; should still succeed but release nothing
        uint256 pendingBefore = treasury.getPendingWithdrawal(partner1);
        vm.warp(block.timestamp + 30 days);
        _setupEarningsDistributed(SMALL_EARNINGS_AMOUNT); // Record Period 2 shortfall
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
        uint256 pendingAfter = treasury.getPendingWithdrawal(partner1);
        assertEq(pendingAfter, pendingBefore, "No collateral should be released during shortfall");

        // 5. Now add excess earnings and process to replenish buffers
        _setupEarningsDistributed(LARGE_EARNINGS_AMOUNT);

        // 6. Advance time more and release again (replenishment should have occurred)
        vm.warp(block.timestamp + 120 days);
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
        assertGt(treasury.getPendingWithdrawal(partner1), pendingAfter, "Collateral should release after replenishment");
    }

    function testDistributeEarningsMinimumProtocolFee() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // With new logic, we need to distribute enough so investor portion >= MIN_PROTOCOL_FEE
        // Investor owns PURCHASE_AMOUNT (100) out of total supply = 10%
        // So we need to distribute 10x MIN_PROTOCOL_FEE to get investor portion = MIN_PROTOCOL_FEE
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        uint256 totalAmount = (ProtocolLib.MIN_PROTOCOL_FEE * totalSupply) / buyerBalance;

        uint256 initialFeeBalance = treasury.getPendingWithdrawal(config.treasuryFeeRecipient);

        _setupEarningsDistributed(totalAmount);

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
        treasury.distributeEarnings(scenario.assetId, insufficientEarningsAmount, false);
        vm.stopPrank();
    }

    function testReleasePartialCollateralDepleted() public {
        _ensureState(SetupState.EarningsDistributed);

        CollateralLib.CollateralInfo memory info = treasury.getAssetCollateralInfo(scenario.assetId);
        assertTrue(info.isLocked);
        uint256 earningsBuffer = info.earningsBuffer;
        uint256 protocolBuffer = info.protocolBuffer;
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        uint256 investorTokens = roboshareTokens.getSoldSupply(scenario.revenueTokenId);

        // Repeatedly release collateral over 10 years until it's fully depleted (12% per year, ~8.33 years to deplete)
        uint256 timeToWarp = info.lockedAt;
        for (uint256 i = 0; i < 9; i++) {
            timeToWarp += 365 days;
            vm.warp(timeToWarp);

            // Ensure investor portion meets benchmark to keep buffers full.
            uint256 benchmark = EarningsLib.calculateEarnings(
                info.initialBaseCollateral, 365 days, roboshareTokens.getTargetYieldBP(scenario.revenueTokenId)
            );
            uint256 topUp = (benchmark * totalSupply) / investorTokens;
            vm.startPrank(partner1);
            usdc.approve(address(treasury), topUp);
            treasury.distributeEarnings(scenario.assetId, topUp, false);
            vm.stopPrank();

            vm.prank(partner1);
            treasury.releasePartialCollateral(scenario.assetId);
        }

        // Verify base collateral is depleted, but buffers remain
        CollateralLib.CollateralInfo memory infoAfter = treasury.getAssetCollateralInfo(scenario.assetId);
        assertEq(infoAfter.baseCollateral, 0, "Base collateral should be zero after 9 years");
        uint256 benchmarkAnnual = EarningsLib.calculateEarnings(
            info.initialBaseCollateral, 365 days, roboshareTokens.getTargetYieldBP(scenario.revenueTokenId)
        );
        uint256 protocolFeePerPeriod = ProtocolLib.calculateProtocolFee(benchmarkAnnual);
        uint256 maxRemaining = earningsBuffer + protocolBuffer - (protocolFeePerPeriod * 8);
        uint256 minRemaining = earningsBuffer + protocolBuffer - (protocolFeePerPeriod * 9);
        assertGe(infoAfter.totalCollateral, minRemaining, "Total collateral should be above minimum buffer expectation");
        assertLe(infoAfter.totalCollateral, maxRemaining, "Total collateral should be below maximum buffer expectation");

        // Attempt one final release in the 10th year
        // distribute enough to satisfy safety gate
        uint256 finalInvestorAmount = (1000 * 1e6 * totalSupply) / investorTokens;
        vm.startPrank(partner1);
        usdc.approve(address(treasury), finalInvestorAmount);
        treasury.distributeEarnings(scenario.assetId, finalInvestorAmount, false);
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days);

        // Should succeed with 0 release
        vm.prank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
    }

    // Settlement Tests

    function testInitiateSettlementTopUp() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 topUpAmount = TOP_UP_AMOUNT;

        _setupBaseEscrowCredited(ASSET_VALUE);

        // Partner approves top-up
        vm.prank(partner1);
        usdc.approve(address(treasury), topUpAmount);

        // Check initial state
        CollateralLib.CollateralInfo memory info = treasury.getAssetCollateralInfo(scenario.assetId);
        assertEq(info.baseCollateral, ASSET_VALUE);

        vm.prank(address(router));
        (uint256 settlementAmount, uint256 settlementPerToken) =
            treasury.initiateSettlement(partner1, scenario.assetId, topUpAmount);

        // Verify Settlement Amount logic
        // Should be InvestorClaimable + TopUp
        // InvestorClaimable = Base + Reserved (protocol buffer excluded)
        assertGt(settlementAmount, topUpAmount);
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        assertEq(settlementPerToken, settlementAmount / totalSupply);
    }

    function testExecuteLiquidation() public {
        _ensureState(SetupState.RevenueTokensMinted);

        _setupBaseEscrowCredited(ASSET_VALUE);

        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(scenario.revenueTokenId);
        vm.warp(maturityDate + 1);

        vm.prank(address(router));
        (uint256 liquidationAmount, uint256 settlementPerToken) = treasury.executeLiquidation(scenario.assetId);

        CollateralLib.CollateralInfo memory infoAfter = treasury.getAssetCollateralInfo(scenario.assetId);
        assertFalse(infoAfter.isLocked);
        assertEq(infoAfter.baseCollateral, 0);

        assertGt(liquidationAmount, 0);
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        assertEq(settlementPerToken, liquidationAmount / totalSupply);
    }

    function testPreviewLiquidationEligibilityNotEligible() public {
        _ensureState(SetupState.RevenueTokensMinted);
        _setupBaseEscrowCredited(ASSET_VALUE);

        (bool eligible, uint8 reason) = treasury.previewLiquidationEligibility(scenario.assetId);
        assertFalse(eligible);
        assertEq(reason, 3); // NotEligible

        vm.prank(address(router));
        vm.expectRevert(
            abi.encodeWithSelector(IAssetRegistry.AssetNotEligibleForLiquidation.selector, scenario.assetId)
        );
        treasury.executeLiquidation(scenario.assetId);
    }

    function testPreviewLiquidationEligibilityByMaturity() public {
        _ensureState(SetupState.RevenueTokensMinted);
        _setupBaseEscrowCredited(ASSET_VALUE);

        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(scenario.revenueTokenId);
        vm.warp(maturityDate + 1);

        (bool eligible, uint8 reason) = treasury.previewLiquidationEligibility(scenario.assetId);
        assertTrue(eligible);
        assertEq(reason, 0); // EligibleByMaturity
    }

    function testPreviewLiquidationEligibilityNoPriorEarningsInitialized() public {
        _ensureState(SetupState.RevenueTokensMinted);
        _setupBaseEscrowCredited(ASSET_VALUE);

        (,,,, uint256 lastEventTimestamp,,,,) = treasury.assetEarnings(scenario.assetId);
        assertEq(lastEventTimestamp, 0, "No earnings should be initialized for this branch");

        (bool eligible, uint8 reason) = treasury.previewLiquidationEligibility(scenario.assetId);
        assertFalse(eligible);
        assertEq(reason, 3); // NotEligible
    }

    function testPreviewLiquidationEligibilityZeroElapsed() public {
        _ensureState(SetupState.EarningsDistributed);

        (,,,, uint256 lastEventTimestamp,,,,) = treasury.assetEarnings(scenario.assetId);
        assertEq(lastEventTimestamp, block.timestamp, "Preview should run in same timestamp for zero-elapsed branch");

        (bool eligible, uint8 reason) = treasury.previewLiquidationEligibility(scenario.assetId);
        assertFalse(eligible);
        assertEq(reason, 3); // NotEligible
    }

    function testExecuteLiquidationAppliesMissedEarningsShortfall() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        (,,,, uint256 lastEventTimestamp,,,,) = treasury.assetEarnings(scenario.assetId);
        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(scenario.revenueTokenId);
        CollateralLib.CollateralInfo memory infoBefore = treasury.getAssetCollateralInfo(scenario.assetId);
        uint256 targetYieldBP = roboshareTokens.getTargetYieldBP(scenario.revenueTokenId);
        uint256 elapsedToDeplete = (infoBefore.earningsBuffer * ProtocolLib.YEARLY_INTERVAL * ProtocolLib.BP_PRECISION)
            / (infoBefore.initialBaseCollateral * targetYieldBP);
        uint256 warpTo = lastEventTimestamp + elapsedToDeplete + 1;
        require(warpTo < maturityDate, "Test assumes delinquency before maturity");
        vm.warp(warpTo);

        uint256 shortfallAmount =
            EarningsLib.calculateEarnings(infoBefore.initialBaseCollateral, elapsedToDeplete + 1, targetYieldBP);

        vm.expectEmit(true, true, false, true, address(treasury));
        emit ITreasury.ShortfallReserved(scenario.assetId, shortfallAmount);

        (bool eligible, uint8 reason) = treasury.previewLiquidationEligibility(scenario.assetId);
        assertTrue(eligible);
        assertEq(reason, 1); // EligibleByInsolvency

        vm.prank(address(router));
        treasury.executeLiquidation(scenario.assetId);
    }

    function testSettlementProtocolBufferSeparation() public {
        _ensureState(SetupState.RevenueTokensMinted);

        _setupBaseEscrowCredited(ASSET_VALUE);

        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(scenario.revenueTokenId);
        vm.warp(maturityDate + 1);

        // Get initial state
        CollateralLib.CollateralInfo memory infoBefore = treasury.getAssetCollateralInfo(scenario.assetId);
        uint256 protocolBuffer = infoBefore.protocolBuffer;
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
        _ensureState(SetupState.RevenueTokensClaimed);

        // Simulate asset being liquidated via VehicleRegistry to ensure status is updated
        // We need to warp to maturity for liquidation to be valid.
        uint256 revenueTokenId = scenario.assetId + 1;
        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(revenueTokenId);
        vm.warp(maturityDate + 1);

        vm.prank(unauthorized); // Anyone can call liquidateAsset
        assetRegistry.liquidateAsset(scenario.assetId);

        uint256 initialBalance = usdc.balanceOf(buyer);
        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, revenueTokenId);
        assertFalse(treasury.getAssetCollateralInfo(scenario.assetId).isLocked); // settlement clears this.

        (, uint256 settlementPerToken,) = treasury.assetSettlements(scenario.assetId);

        vm.startPrank(buyer);
        (uint256 claimed,) = assetRegistry.claimSettlement(scenario.assetId, false);
        // Settlement now uses pendingWithdrawals pattern - need to withdraw
        treasury.processWithdrawal();
        vm.stopPrank();

        assertEq(claimed, buyerBalance * settlementPerToken, "Claimed amount mismatch");
        assertEq(usdc.balanceOf(buyer), initialBalance + claimed, "Buyer USDC balance mismatch");
    }

    function testSettlementAfterMaturityReturnsBufferToPartner() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Warp past maturity
        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(scenario.revenueTokenId);
        vm.warp(maturityDate + 1);

        // Settle asset
        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        // Check results
        CollateralLib.CollateralInfo memory info = treasury.getAssetCollateralInfo(scenario.assetId);
        uint256 earningsBuffer = info.earningsBuffer;
        uint256 protocolBuffer = info.protocolBuffer;

        // Expected behavior: earningsBuffer AND protocolBuffer should be in partner's pending withdrawals
        uint256 pending = treasury.getPendingWithdrawal(partner1);
        assertEq(pending, earningsBuffer + protocolBuffer, "Partner should receive earnings AND protocol buffer");

        // Treasury fee recipient should NOT receive protocol buffer
        uint256 feeRecipientPending = treasury.getPendingWithdrawal(config.treasuryFeeRecipient);
        assertEq(feeRecipientPending, 0, "Fee recipient should not receive protocol buffer on maturity settlement");
    }

    // ============ Coverage Tests for Uncovered Branches ============

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

        (bool eligible, uint8 reason) = treasury.previewLiquidationEligibility(scenario.assetId);
        assertFalse(eligible);
        assertEq(reason, 2); // AlreadySettled

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

        vm.prank(address(router));
        uint256 claimed = treasury.processSettlementClaim(buyer, scenario.assetId, 0);
        assertEq(claimed, 0);
    }

    function testProcessSettlementClaimNotSettled() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        vm.startPrank(address(router));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAssetRegistry.AssetNotSettled.selector, scenario.assetId, router.getAssetStatus(scenario.assetId)
            )
        );
        treasury.processSettlementClaim(buyer, scenario.assetId, 1);
        vm.stopPrank();
    }

    // ============================================
    // Earnings Snapshot Tests
    // ============================================

    /// @dev Test claimSettlement with autoClaimEarnings=true claims both settlement and earnings
    function testClaimSettlementAutoClaimEarnings() public {
        _ensureState(SetupState.EarningsDistributed);

        // Buyer purchases tokens - now buyer holds 100 tokens, partner1 holds 900
        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        assertEq(buyerBalance, 100);

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

    function testClaimEarningsSettledUsesSnapshot() public {
        _ensureState(SetupState.EarningsDistributed);

        vm.prank(address(router));
        treasury.snapshotAndClaimEarnings(scenario.assetId, buyer, false);

        vm.prank(address(treasury));
        router.setAssetStatus(scenario.assetId, AssetLib.AssetStatus.Retired);

        uint256 pendingBefore = treasury.getPendingWithdrawal(buyer);
        vm.prank(buyer);
        treasury.claimEarnings(scenario.assetId);
        uint256 pendingAfter = treasury.getPendingWithdrawal(buyer);
        assertGt(pendingAfter, pendingBefore);
    }

    /// @dev Test claimSettlement with autoClaimEarnings=false then claim earnings separately
    function testClaimSettlementThenClaimEarningsFromSnapshot() public {
        _ensureState(SetupState.EarningsDistributed);

        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        assertEq(buyerBalance, 100);

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
        _ensureState(SetupState.EarningsDistributed);

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

    function testClaimEarningsSettledAsset() public {
        _ensureState(SetupState.EarningsDistributed);

        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        vm.prank(buyer);
        assetRegistry.claimSettlement(scenario.assetId, false);

        uint256 pendingBefore = treasury.getPendingWithdrawal(buyer);

        vm.prank(buyer);
        treasury.claimEarnings(scenario.assetId);

        uint256 pendingAfter = treasury.getPendingWithdrawal(buyer);
        assertGt(pendingAfter, pendingBefore, "Should claim earnings for settled asset");
    }

    function testClaimEarningsSettledAssetViaSnapshot() public {
        _ensureState(SetupState.EarningsDistributed);

        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        vm.prank(buyer);
        assetRegistry.claimSettlement(scenario.assetId, false);

        uint256 pendingBefore = treasury.getPendingWithdrawal(buyer);

        vm.prank(buyer);
        treasury.claimEarnings(scenario.assetId);

        uint256 pendingAfter = treasury.getPendingWithdrawal(buyer);
        assertGt(pendingAfter, pendingBefore, "Should claim settled earnings via snapshot");
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
        _setupEarningsDistributed(earningsAmount);

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
        _ensureState(SetupState.EarningsDistributed);

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
        _ensureState(SetupState.EarningsDistributed);

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
        _ensureState(SetupState.EarningsDistributed);

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
            _setupEarningsDistributed(earningsAmount);

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
        uint256 earningsAmount = LARGE_EARNINGS_AMOUNT;
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount * 3);

        // First distribution - no release (first period)
        uint256 released1 = treasury.distributeEarnings(scenario.assetId, earningsAmount, true);
        assertEq(released1, 0, "No release on first period");

        // Advance past minimum interval (15 days)
        vm.warp(block.timestamp + 16 days);

        // Second distribution with auto-release - should release collateral
        uint256 pendingBefore = treasury.getPendingWithdrawal(partner1);

        vm.expectEmit(true, true, false, false, address(treasury));
        emit ITreasury.CollateralReleased(scenario.assetId, partner1, 0); // Amount check via assert below

        uint256 released2 = treasury.distributeEarnings(scenario.assetId, earningsAmount, true);
        assertGt(released2, 0, "Should release collateral on second distribution");

        uint256 pendingAfter = treasury.getPendingWithdrawal(partner1);
        assertEq(pendingAfter - pendingBefore, released2, "Pending should include released collateral");

        vm.stopPrank();
    }

    /// @dev Test that consecutive distributions with auto-release work (no interval check)
    function testDistributeEarningsAutoReleaseConsecutive() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        uint256 earningsAmount = LARGE_EARNINGS_AMOUNT;
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount * 2);

        // First distribution - creates period 1, but no prior period to process yet
        uint256 released1 = treasury.distributeEarnings(scenario.assetId, earningsAmount, true);
        assertEq(released1, 0, "First distribution has no prior periods to process");

        // Warp time forward - release amount is based on linear depreciation over time
        vm.warp(block.timestamp + 7 days);

        // Second distribution - now has period 1 to process AND time has passed for depreciation
        uint256 released2 = treasury.distributeEarnings(scenario.assetId, earningsAmount, true);
        assertGt(released2, 0, "Second distribution should release collateral");

        vm.stopPrank();
    }

    /// @dev Test distributeEarnings with tryAutoRelease=false does not release collateral
    function testDistributeEarningsAutoReleaseDisabled() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        uint256 earningsAmount = LARGE_EARNINGS_AMOUNT;
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount * 2);

        // First distribution
        treasury.distributeEarnings(scenario.assetId, earningsAmount, false);

        // Advance past minimum interval
        vm.warp(block.timestamp + 16 days);

        // Second distribution with auto-release DISABLED
        uint256 released = treasury.distributeEarnings(
            scenario.assetId,
            earningsAmount,
            false // disabled
        );

        assertEq(released, 0, "Should not release when tryAutoRelease=false");

        // Partner can still manually release
        treasury.releasePartialCollateral(scenario.assetId);

        vm.stopPrank();
    }

    function testDistributeEarningsAutoReleaseNotLocked() public {
        _ensureState(SetupState.RevenueTokensMinted);

        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        uint256 soldAmount = totalSupply / 2;
        vm.prank(address(marketplace));
        router.recordSoldSupply(scenario.revenueTokenId, soldAmount);

        uint256 investorAmount = (EARNINGS_AMOUNT * soldAmount) / totalSupply;
        vm.startPrank(partner1);
        usdc.approve(address(treasury), investorAmount);
        uint256 released = treasury.distributeEarnings(scenario.assetId, EARNINGS_AMOUNT, true);
        vm.stopPrank();

        assertEq(released, 0);
    }

    function testAutoReleaseProtocolFeeClamped() public {
        _ensureState(SetupState.RevenueTokensMinted);

        uint256 baseAmount = 1 * 10 ** 6;
        vm.prank(partner1);
        usdc.approve(address(treasury), type(uint256).max);
        vm.prank(address(marketplace));
        treasury.fundBuffersFor(partner1, scenario.assetId, baseAmount);

        vm.prank(address(marketplace));
        treasury.creditBaseEscrow(scenario.assetId, baseAmount);

        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        uint256 soldAmount = totalSupply / 2;
        vm.prank(address(marketplace));
        router.recordSoldSupply(scenario.revenueTokenId, soldAmount);

        vm.warp(block.timestamp + 7 days);

        uint256 investorAmount = (EARNINGS_AMOUNT * soldAmount) / totalSupply;
        uint256 feePendingBefore = treasury.getPendingWithdrawal(config.treasuryFeeRecipient);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), investorAmount);
        uint256 released = treasury.distributeEarnings(scenario.assetId, EARNINGS_AMOUNT, true);
        vm.stopPrank();

        assertEq(released, 0);

        uint256 feePendingAfter = treasury.getPendingWithdrawal(config.treasuryFeeRecipient);
        uint256 protocolFeeFromEarnings = ProtocolLib.calculateProtocolFee(investorAmount);
        uint256 releaseFeeDelta = feePendingAfter - feePendingBefore - protocolFeeFromEarnings;

        assertGt(releaseFeeDelta, 0);
        assertLt(releaseFeeDelta, ProtocolLib.MIN_PROTOCOL_FEE);
    }

    /// @dev Test manual releasePartialCollateral still works independently
    function testManualReleaseAfterDistributeAutoReleaseDisabled() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        uint256 earningsAmount = LARGE_EARNINGS_AMOUNT;
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);

        // Distribute without auto-release
        treasury.distributeEarnings(scenario.assetId, earningsAmount, false);

        // Advance past minimum interval
        vm.warp(block.timestamp + 16 days);

        // Manual release should work
        uint256 pendingBefore = treasury.getPendingWithdrawal(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
        uint256 pendingAfter = treasury.getPendingWithdrawal(partner1);

        assertGt(pendingAfter, pendingBefore, "Manual release should work");

        vm.stopPrank();
    }

    function testPreviewCollateralReleaseAssumeNewPeriodNoEarnings() public {
        _ensureState(SetupState.ListingEnded);

        vm.warp(block.timestamp + 1 days);
        uint256 preview = treasury.previewCollateralRelease(scenario.assetId, true);
        assertGt(preview, 0);
    }

    function testPreviewCollateralReleaseAssumeNewPeriodNoNewPeriods() public {
        _ensureState(SetupState.EarningsDistributed);

        uint256 extraRevenue = 10_000_000_000; // large revenue to avoid shortfall
        vm.startPrank(partner1);
        usdc.approve(address(treasury), type(uint256).max);
        treasury.distributeEarnings(scenario.assetId, extraRevenue, false);
        vm.stopPrank();

        uint256 firstWarp = block.timestamp + 30 days;
        vm.warp(firstWarp);
        vm.startPrank(partner1);
        treasury.releasePartialCollateral(scenario.assetId);
        vm.stopPrank();

        vm.warp(firstWarp + 30 days);
        uint256 preview = treasury.previewCollateralRelease(scenario.assetId, true);
        assertGt(preview, 0);
    }

    function testPreviewCollateralReleaseAssumeNewPeriodFeeClamp() public {
        _ensureState(SetupState.ListingEnded);

        CollateralLib.CollateralInfo memory info = treasury.getAssetCollateralInfo(scenario.assetId);
        vm.warp(info.lockedAt + 1);

        uint256 preview = treasury.previewCollateralRelease(scenario.assetId, true);
        assertEq(preview, 0);
    }

    function testPreviewCollateralReleaseNoReleaseDue() public {
        _ensureState(SetupState.EarningsDistributed);

        CollateralLib.CollateralInfo memory info = treasury.getAssetCollateralInfo(scenario.assetId);
        vm.warp(info.lockedAt == 0 ? block.timestamp : info.lockedAt);

        uint256 preview = treasury.previewCollateralRelease(scenario.assetId, false);
        assertEq(preview, 0);
    }

    function testClearCollateralClampsTotalDeposited() public {
        _ensureState(SetupState.RevenueTokensMinted);

        TreasuryHarness harness = _deployTreasuryHarness();
        harness.setCollateralInfo(scenario.assetId, 0, 0, 0, 0, 100e6, true, block.timestamp, block.timestamp);
        harness.setTotalCollateralDeposited(10e6);

        uint256 released = harness.exposeClearCollateral(scenario.assetId);
        assertEq(released, 10e6);
        assertEq(harness.totalCollateralDeposited(), 0);
    }

    function testFuzzDistributeEarnings(uint256 totalEarnings) public {
        totalEarnings = bound(totalEarnings, (10 * 1e6) + 1, 1e12 - 1); // >10 USDC

        _ensureState(SetupState.RevenueTokensClaimed);

        // Ensure partner has funds
        _fundAddressWithUsdc(partner1, totalEarnings * 2);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), totalEarnings);

        // Capture state before
        uint256 treasuryBalanceBefore = usdc.balanceOf(address(treasury));

        treasury.distributeEarnings(scenario.assetId, totalEarnings, false);

        // Verify balances
        uint256 treasuryBalanceAfter = usdc.balanceOf(address(treasury));
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        uint256 investorTokens = roboshareTokens.getSoldSupply(scenario.revenueTokenId);
        uint256 revenueShareBP = roboshareTokens.getRevenueShareBP(scenario.revenueTokenId);
        uint256 cap = (totalEarnings * revenueShareBP) / ProtocolLib.BP_PRECISION;
        uint256 soldShare = (totalEarnings * investorTokens) / totalSupply;
        uint256 investorAmount = soldShare < cap ? soldShare : cap;

        assertEq(
            treasuryBalanceAfter,
            treasuryBalanceBefore + investorAmount,
            "Only investor portion should remain in Treasury"
        );

        // Verify partner got remainder back immediately
        // Note: distributeEarnings transfers 'amount' FROM partner, then sends (amount - investorAmount) back to partner?
        // Let's check contract logic.
        // Actually distributeEarnings takes 'amount' from sender.
        // If investorAmount < amount, the difference is kept by partner?
        // No, `distributeEarnings` usually assumes the `amount` is total revenue, and `investorAmount` is what is sent to the contract.
        // Wait, looking at Treasury.sol:
        // function distributeEarnings(..., uint256 amount, ...)
        //   IERC20(usdc).safeTransferFrom(msg.sender, address(this), investorAmount);
        // It only transfers `investorAmount`!
        // The `amount` param is just for record keeping (total revenue).

        // So my assertion `treasuryBalanceAfter == treasuryBalanceBefore + investorPortion` is correct.

        vm.stopPrank();
    }

    // ============================================
    // Convenience Withdrawal Function Tests
    // ============================================

    /// @dev Test releaseAndWithdrawCollateral releases and withdraws in one call
    function testReleaseAndWithdrawCollateral() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        uint256 earningsAmount = LARGE_EARNINGS_AMOUNT;
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount * 2);

        // First distribution to establish earnings
        treasury.distributeEarnings(scenario.assetId, earningsAmount, false);

        // Advance time for depreciation
        vm.warp(block.timestamp + 30 days);

        // Second distribution
        treasury.distributeEarnings(scenario.assetId, earningsAmount, false);

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
        _ensureState(SetupState.EarningsDistributed);

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
        _ensureState(SetupState.EarningsDistributed);

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
    function testReleaseAndWithdrawCollateralNoNewEarningsPeriods() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        uint256 earningsAmount = EARNINGS_AMOUNT;
        vm.startPrank(partner1);
        usdc.approve(address(treasury), earningsAmount);

        // Distribute and release immediately
        treasury.distributeEarnings(scenario.assetId, earningsAmount, true);

        // Try to release again without new distribution
        vm.expectRevert(ITreasury.NoNewEarningsPeriods.selector);
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

    function _deployTreasuryHarness() internal returns (TreasuryHarness harness) {
        harness = new TreasuryHarness();
        harness.initialize(
            admin, address(roboshareTokens), address(partnerManager), address(router), address(usdc), admin
        );
    }
}
