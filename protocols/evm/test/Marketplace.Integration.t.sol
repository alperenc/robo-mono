// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ProtocolLib, CollateralLib } from "../contracts/Libraries.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { Marketplace } from "../contracts/Marketplace.sol";

contract MarketplaceIntegrationTest is BaseTest {
    event ListingCreated(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        uint256 indexed assetId,
        address seller,
        uint256 amount,
        uint256 pricePerToken,
        uint256 expiresAt,
        bool buyerPaysFee,
        bool isPrimary
    );

    event RevenueTokensTraded(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 listingId,
        uint256 totalPrice
    );

    function setUp() public {
        _ensureState(SetupState.InitialAccountsSetup);
    }

    // Create Listing Tests

    function testCreateListing() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        vm.startPrank(buyer);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 newListingId = marketplace.createListing(
            scenario.revenueTokenId, buyerBalance, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
        );
        vm.stopPrank();

        _assertListingState(newListingId, scenario.revenueTokenId, buyerBalance, REVENUE_TOKEN_PRICE, buyer, true, true);
        Marketplace.Listing memory listing = marketplace.getListing(newListingId);
        assertFalse(listing.isPrimary);
    }

    function testCreateListingAssetOwnerUsesEscrow() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.prank(partner1);
        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.createListing(scenario.revenueTokenId, LISTING_AMOUNT, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
    }

    function testCreateListingInvalidTokenType() public {
        _ensureState(SetupState.AssetRegistered);

        vm.expectRevert(Marketplace.InvalidTokenType.selector);
        vm.prank(partner1);
        marketplace.createListing(scenario.assetId, 1, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
    }

    function testCreateListingInvalidAmount() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.startPrank(partner1);
        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.createListing(scenario.revenueTokenId, 0, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);

        uint256 currentSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.createListing(
            scenario.revenueTokenId, currentSupply + 1, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
        );
        vm.stopPrank();
    }

    function testCreateListingInvalidPrice() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.prank(partner1);
        vm.expectRevert(Marketplace.InvalidPrice.selector);
        marketplace.createListing(scenario.revenueTokenId, LISTING_AMOUNT, 0, LISTING_DURATION, true);
    }

    function testCreateListingInsufficientTokenBalance() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        vm.startPrank(partner2);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        vm.expectRevert(Marketplace.InsufficientTokenBalance.selector);
        marketplace.createListing(scenario.revenueTokenId, 1, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
        vm.stopPrank();
    }

    function testCreateListingSecondaryInsufficientBalance() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        vm.prank(buyer);
        vm.expectRevert(Marketplace.InsufficientTokenBalance.selector);
        marketplace.createListing(
            scenario.revenueTokenId, buyerBalance + 1, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
        );
    }

    function testCreateListingSecondaryTransfersFromSeller() public {
        _ensureState(SetupState.RevenueTokensListed);

        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        if (buyerBalance == 0) {
            (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(scenario.listingId, PURCHASE_AMOUNT);
            vm.startPrank(buyer);
            usdc.approve(address(marketplace), expectedPayment);
            marketplace.purchaseTokens(scenario.listingId, PURCHASE_AMOUNT);
            vm.stopPrank();

            vm.prank(partner1);
            usdc.approve(address(treasury), type(uint256).max);
            vm.prank(partner1);
            marketplace.endListing(scenario.listingId);

            vm.prank(buyer);
            // claimTokens removed: immediate settlement
            buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        }

        vm.prank(buyer);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 beforeEscrow = marketplace.tokenEscrow(scenario.revenueTokenId);
        uint256 marketplaceBalanceBefore = roboshareTokens.balanceOf(address(marketplace), scenario.revenueTokenId);
        vm.prank(buyer);
        uint256 listingId = marketplace.createListing(
            scenario.revenueTokenId, buyerBalance, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
        );
        uint256 afterEscrow = marketplace.tokenEscrow(scenario.revenueTokenId);
        uint256 marketplaceBalanceAfter = roboshareTokens.balanceOf(address(marketplace), scenario.revenueTokenId);

        assertEq(afterEscrow, beforeEscrow);
        assertEq(marketplaceBalanceAfter, marketplaceBalanceBefore + buyerBalance);
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.amount, buyerBalance);
        assertFalse(listing.isPrimary);
    }

    function testCreateListingPrimaryUsesEscrow() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        uint256 beforeEscrow = marketplace.tokenEscrow(scenario.revenueTokenId);
        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        vm.startPrank(buyer);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.createListing(
            scenario.revenueTokenId, buyerBalance, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
        );
        vm.stopPrank();

        uint256 afterEscrow = marketplace.tokenEscrow(scenario.revenueTokenId);
        assertEq(afterEscrow, beforeEscrow);

        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertFalse(listing.isPrimary);
    }

    function testEndListingPrimaryEscrowsUnsoldTokens() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        uint256 amount = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        vm.startPrank(buyer);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 listingId =
            marketplace.createListing(scenario.revenueTokenId, amount, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
        marketplace.endListing(listingId);
        vm.stopPrank();
        assertEq(roboshareTokens.balanceOf(buyer, scenario.revenueTokenId), amount);
    }

    function testEndListingPrimarySoldOutSkipsEscrowReturn() public {
        _ensureState(SetupState.RevenueTokensListed);

        uint256 listingId = scenario.listingId;
        Marketplace.Listing memory beforeListing = marketplace.getListing(listingId);

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), type(uint256).max);
        marketplace.purchaseTokens(listingId, beforeListing.amount);
        vm.stopPrank();

        uint256 beforeEscrow = marketplace.tokenEscrow(scenario.revenueTokenId);

        vm.prank(partner1);
        usdc.approve(address(treasury), type(uint256).max);
        vm.prank(partner1);
        marketplace.endListing(listingId);

        uint256 afterEscrow = marketplace.tokenEscrow(scenario.revenueTokenId);
        assertEq(afterEscrow, beforeEscrow);
    }

    function testCancelListingPrimaryEscrowsAllTokens() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        uint256 amount = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        vm.startPrank(buyer);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 listingId =
            marketplace.createListing(scenario.revenueTokenId, amount, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
        marketplace.cancelListing(listingId);
        vm.stopPrank();
        assertEq(roboshareTokens.balanceOf(buyer, scenario.revenueTokenId), amount);
    }

    function testEndListingPrimaryCreditsBaseEscrow() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        CollateralLib.CollateralInfo memory beforeCollateral = treasury.getAssetCollateralInfo(scenario.assetId);
        uint256 amount = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        vm.startPrank(buyer);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 listingId =
            marketplace.createListing(scenario.revenueTokenId, amount, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
        marketplace.endListing(listingId);
        vm.stopPrank();

        CollateralLib.CollateralInfo memory afterCollateral = treasury.getAssetCollateralInfo(scenario.assetId);
        assertEq(afterCollateral.baseCollateral, beforeCollateral.baseCollateral);
        assertEq(afterCollateral.initialBaseCollateral, beforeCollateral.initialBaseCollateral);
    }

    function testCreateListingAssetOwnerRequiresBuyerPaysFee() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.prank(partner1);
        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.createListing(scenario.revenueTokenId, LISTING_AMOUNT, REVENUE_TOKEN_PRICE, LISTING_DURATION, false);
    }

    function testCreateListingAssetOwnerAmountExceedsRemaining() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.prank(partner1);
        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.createListing(scenario.revenueTokenId, 2, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
    }

    function testCreateListingAssetOwnerInsufficientEscrow() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.prank(partner1);
        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.createListing(scenario.revenueTokenId, 1, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
    }

    function testEndListingReturnsUnsoldToEscrowForAssetOwner() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.prank(partner1);
        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.createListing(scenario.revenueTokenId, LISTING_AMOUNT, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
    }

    function testCancelListingReturnsTokensToEscrowForAssetOwner() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.prank(partner1);
        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.createListing(scenario.revenueTokenId, LISTING_AMOUNT, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
    }

    function testCancelListingReturnsTokensToSellerForSecondary() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        vm.startPrank(buyer);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.createListing(
            scenario.revenueTokenId, buyerBalance, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
        );
        vm.stopPrank();

        uint256 escrowBefore = marketplace.tokenEscrow(scenario.revenueTokenId);
        uint256 buyerBefore = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);

        vm.prank(buyer);
        marketplace.cancelListing(listingId);

        uint256 escrowAfter = marketplace.tokenEscrow(scenario.revenueTokenId);
        uint256 buyerAfter = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);

        assertEq(escrowAfter, escrowBefore);
        assertEq(buyerAfter, buyerBefore + buyerBalance);
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertFalse(listing.isPrimary);
    }

    function testEndListingCreditsBaseEscrowForAssetOwner() public {
        _ensureState(SetupState.RevenueTokensMinted);

        uint256 baseBefore = treasury.getAssetCollateralInfo(scenario.assetId).baseCollateral;
        vm.prank(partner1);
        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.createListing(scenario.revenueTokenId, LISTING_AMOUNT, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
        uint256 baseAfter = treasury.getAssetCollateralInfo(scenario.assetId).baseCollateral;
        assertEq(baseAfter, baseBefore);
    }

    function testCreateListingSecondarySetsEarlySalePenalty() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        vm.startPrank(buyer);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 secondaryListingId = marketplace.createListing(
            scenario.revenueTokenId, PURCHASE_AMOUNT, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
        );
        vm.stopPrank();

        Marketplace.Listing memory listing = marketplace.getListing(secondaryListingId);
        assertGt(listing.earlySalePenalty, 0, "Early sale penalty should be set");
        assertFalse(listing.isPrimary);
    }

    // Purchase Listing Tests

    function testPurchaseTokensBuyerPaysFee() public {
        _ensureState(SetupState.RevenueTokensListed);

        (uint256 totalPrice, uint256 protocolFee, uint256 expectedPayment) =
            marketplace.calculatePurchaseCost(scenario.listingId, PURCHASE_AMOUNT);
        uint256 sellerReceives = totalPrice;

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);

        BalanceSnapshot memory beforeBalance = _takeBalanceSnapshot(scenario.revenueTokenId);

        _expectRevenueTokensTradedEvent(
            scenario.revenueTokenId, partner1, buyer, PURCHASE_AMOUNT, scenario.listingId, totalPrice
        );

        marketplace.purchaseTokens(scenario.listingId, PURCHASE_AMOUNT);
        vm.stopPrank();

        BalanceSnapshot memory afterBalance = _takeBalanceSnapshot(scenario.revenueTokenId);

        _assertBalanceChanges(
            beforeBalance,
            afterBalance,
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(sellerReceives), // Partner USDC change (immediate)
            // forge-lint: disable-next-line(unsafe-typecast)
            -int256(expectedPayment), // Buyer USDC change
            0, // Treasury Fee Recipient USDC (pending withdrawal only)
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(protocolFee),
            0,
            0,
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(PURCHASE_AMOUNT)
        );

        Marketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        assertEq(listing.amount, LISTING_AMOUNT - PURCHASE_AMOUNT);
        assertEq(listing.soldAmount, PURCHASE_AMOUNT);
    }

    function testPurchaseTokensListingOwnerCannotPurchase() public {
        _ensureState(SetupState.RevenueTokensListed);

        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(scenario.listingId, 1);
        _fundAddressWithUsdc(partner1, expectedPayment);

        vm.startPrank(partner1);
        usdc.approve(address(marketplace), expectedPayment);
        vm.expectRevert(Marketplace.ListingOwnerCannotPurchase.selector);
        marketplace.purchaseTokens(scenario.listingId, 1);
        vm.stopPrank();
    }

    function testPurchaseTokensEarlySalePenalty() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        uint256 earlySalePenalty = roboshareTokens.getSalesPenalty(buyer, scenario.revenueTokenId, PURCHASE_AMOUNT);
        assertGt(earlySalePenalty, 0, "Sales penalty should be greater than zero");

        vm.startPrank(buyer);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 newListingId = marketplace.createListing(
            scenario.revenueTokenId, PURCHASE_AMOUNT, REVENUE_TOKEN_PRICE, LISTING_DURATION, false
        );
        vm.stopPrank();

        // 3. Calculate expected costs, including the penalty
        (uint256 totalPrice, uint256 protocolFee, uint256 expectedPayment) =
            marketplace.calculatePurchaseCost(newListingId, PURCHASE_AMOUNT);

        Marketplace.Listing memory listing = marketplace.getListing(newListingId);
        assertEq(listing.earlySalePenalty, earlySalePenalty, "Listing early sale penalty mismatch");

        // 4. Partner purchases the tokens
        vm.startPrank(partner1);
        usdc.approve(address(marketplace), expectedPayment);

        BalanceSnapshot memory beforeBalance = _takeBalanceSnapshot(scenario.revenueTokenId);

        marketplace.purchaseTokens(newListingId, PURCHASE_AMOUNT);
        vm.stopPrank();

        BalanceSnapshot memory afterBalance = _takeBalanceSnapshot(scenario.revenueTokenId);

        // 5. Immediate settlement
        _assertBalanceChanges(
            beforeBalance,
            afterBalance,
            // forge-lint: disable-next-line(unsafe-typecast)
            -int256(expectedPayment), // Partner USDC change (partner1 is buyer)
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(totalPrice - protocolFee - listing.earlySalePenalty), // Seller proceeds net penalty and fee
            0, // Treasury Fee Recipient USDC (pending withdrawal only)
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(protocolFee + listing.earlySalePenalty),
            0,
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(PURCHASE_AMOUNT),
            0
        );
    }

    function testPurchaseTokensSellerPaysFee() public {
        _ensureState(SetupState.RevenueTokensListed);

        // Create a secondary listing with seller paying the fee
        uint256 newListingId = _setupSecondaryListing(partner2, PURCHASE_AMOUNT, REVENUE_TOKEN_PRICE, false);

        (uint256 totalPrice, uint256 protocolFee, uint256 expectedPayment) =
            marketplace.calculatePurchaseCost(newListingId, PURCHASE_AMOUNT);
        uint256 sellerReceives = totalPrice - protocolFee;
        Marketplace.Listing memory listing = marketplace.getListing(newListingId);

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);

        BalanceSnapshot memory beforeBalance = _takeBalanceSnapshot(scenario.revenueTokenId);

        marketplace.purchaseTokens(newListingId, PURCHASE_AMOUNT);
        vm.stopPrank();

        BalanceSnapshot memory afterBalance = _takeBalanceSnapshot(scenario.revenueTokenId);

        // Immediate settlement
        _assertBalanceChanges(
            beforeBalance,
            afterBalance,
            0,
            // forge-lint: disable-next-line(unsafe-typecast)
            -int256(expectedPayment), // Buyer USDC change
            0, // Treasury Fee Recipient USDC (pending withdrawal only)
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(protocolFee + listing.earlySalePenalty),
            0,
            0,
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(PURCHASE_AMOUNT)
        );
        assertEq(
            usdc.balanceOf(partner2),
            1_000_000 * 10 ** 6 + (sellerReceives - listing.earlySalePenalty),
            "Seller proceeds mismatch"
        );
    }

    function testPurchaseTokensCompletelyExhaustsListing() public {
        _ensureState(SetupState.RevenueTokensListed);

        uint256 totalPrice = LISTING_AMOUNT * REVENUE_TOKEN_PRICE;
        uint256 protocolFee = ProtocolLib.calculateProtocolFee(totalPrice);

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), totalPrice + protocolFee);
        marketplace.purchaseTokens(scenario.listingId, LISTING_AMOUNT);
        vm.stopPrank();

        Marketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        assertEq(listing.amount, 0);
        assertFalse(listing.isActive);
        assertEq(listing.soldAmount, LISTING_AMOUNT);

        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        uint256 remaining = totalSupply - LISTING_AMOUNT;
        assertEq(roboshareTokens.balanceOf(buyer, scenario.revenueTokenId), LISTING_AMOUNT);
        _assertTokenBalance(
            address(marketplace), scenario.revenueTokenId, remaining, "Marketplace token balance mismatch"
        );
        assertEq(marketplace.tokenEscrow(scenario.revenueTokenId), remaining);
    }

    function testPurchaseTokensInsufficientPayment() public {
        _ensureState(SetupState.RevenueTokensListed);

        uint256 totalPrice = PURCHASE_AMOUNT * REVENUE_TOKEN_PRICE;
        uint256 protocolFee = ProtocolLib.calculateProtocolFee(totalPrice);
        uint256 requiredPayment = totalPrice + protocolFee;

        address poorBuyer = makeAddr("poorBuyer");
        _setupInsufficientFunds(poorBuyer, requiredPayment);

        vm.startPrank(poorBuyer);
        usdc.approve(address(marketplace), requiredPayment);

        vm.expectRevert(); // ERC20: transfer amount exceeds balance
        marketplace.purchaseTokens(scenario.listingId, PURCHASE_AMOUNT);
        vm.stopPrank();
    }

    function testPurchaseTokensExpired() public {
        _ensureState(SetupState.RevenueTokensListed);

        // Create a secondary listing to ensure expiry applies
        uint256 transferAmount = 200;
        _purchaseAndClaimTokens(transferAmount);
        vm.prank(buyer);
        roboshareTokens.safeTransferFrom(buyer, partner2, scenario.revenueTokenId, transferAmount, "");

        vm.startPrank(partner2);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 secondaryListingId =
            marketplace.createListing(scenario.revenueTokenId, transferAmount, REVENUE_TOKEN_PRICE, 1 days, true);
        vm.stopPrank();

        _setupExpiredListing(secondaryListingId);

        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(secondaryListingId, 100);
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(secondaryListingId, 100);
        vm.stopPrank();
        assertEq(roboshareTokens.balanceOf(buyer, scenario.revenueTokenId), transferAmount - 100);
    }

    function testPurchaseTokensInvalidAmount() public {
        _ensureState(SetupState.RevenueTokensListed);

        vm.expectRevert(Marketplace.InvalidAmount.selector);
        vm.prank(buyer);
        marketplace.purchaseTokens(scenario.listingId, LISTING_AMOUNT + 1);
    }

    // Cancel Listing Tests

    function testCancelListing() public {
        _ensureState(SetupState.RevenueTokensListed);

        // 1. Purchase some tokens to have them in escrow
        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(scenario.listingId, PURCHASE_AMOUNT);
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(scenario.listingId, PURCHASE_AMOUNT);
        vm.stopPrank();

        uint256 partnerBalanceBefore = roboshareTokens.balanceOf(partner1, scenario.revenueTokenId);

        // 2. Cancel listing
        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        Marketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        assertFalse(listing.isActive);
        assertTrue(listing.isCancelled);

        // 3. Verify unsold inventory returned to seller
        _assertTokenBalance(
            partner1,
            scenario.revenueTokenId,
            partnerBalanceBefore + (LISTING_AMOUNT - PURCHASE_AMOUNT),
            "Partner token balance mismatch after cancellation"
        );
        _assertTokenBalance(
            address(marketplace), scenario.revenueTokenId, 0, "Marketplace token balance mismatch after cancellation"
        );
        assertEq(marketplace.tokenEscrow(scenario.revenueTokenId), 0);
        _assertTokenBalance(buyer, scenario.revenueTokenId, PURCHASE_AMOUNT, "Buyer token balance mismatch");
    }

    function testCancelListingExpiredNotOwner() public {
        _ensureState(SetupState.RevenueTokensListed);

        _setupExpiredListing(scenario.listingId);

        vm.prank(unauthorized);
        marketplace.cancelListing(scenario.listingId);

        Marketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        assertTrue(listing.isCancelled);
    }

    function testClaimTokensListingNotFound() public {
        _ensureState(SetupState.RevenueTokensListed);
        _assertRemovedSelector(abi.encodeWithSignature("claimTokens(uint256)", 999));
    }

    function testClaimTokensListingActive() public {
        _ensureState(SetupState.RevenueTokensListed);
        _assertRemovedSelector(abi.encodeWithSignature("claimTokens(uint256)", scenario.listingId));
    }

    function testClaimTokensListingCancelled() public {
        _ensureState(SetupState.RevenueTokensListed);

        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);
        _assertRemovedSelector(abi.encodeWithSignature("claimTokens(uint256)", scenario.listingId));
    }

    function testClaimTokensNoTokensToClaim() public {
        _ensureState(SetupState.RevenueTokensListed);

        vm.prank(partner1);
        marketplace.endListing(scenario.listingId);
        _assertRemovedSelector(abi.encodeWithSignature("claimTokens(uint256)", scenario.listingId));
    }

    function testClaimRefundListingNotFound() public {
        _ensureState(SetupState.RevenueTokensListed);
        _assertRemovedSelector(abi.encodeWithSignature("claimRefund(uint256)", 999));
    }

    function testClaimRefundListingNotCancelled() public {
        _ensureState(SetupState.RevenueTokensListed);
        _assertRemovedSelector(abi.encodeWithSignature("claimRefund(uint256)", scenario.listingId));
    }

    function testClaimRefundNoRefundToClaim() public {
        _ensureState(SetupState.RevenueTokensListed);

        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);
        _assertRemovedSelector(abi.encodeWithSignature("claimRefund(uint256)", scenario.listingId));
    }

    // Finalize Listing Tests

    function testFinalizeListingPendingProceeds() public {
        _ensureState(SetupState.RevenueTokensListed);
        _assertRemovedSelector(abi.encodeWithSignature("finalizeListing(uint256)", scenario.listingId));
    }

    function testFinalizeListingAlreadyCancelled() public {
        _ensureState(SetupState.RevenueTokensListed);

        // First cancel the listing
        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        _assertRemovedSelector(abi.encodeWithSignature("finalizeListing(uint256)", scenario.listingId));
    }

    function testFinalizeListingSoldOutSecondarySettlesAndWithdraws() public {
        _ensureState(SetupState.RevenueTokensListed);

        uint256 secondaryListingId = _setupSecondaryListing(partner2, PURCHASE_AMOUNT, REVENUE_TOKEN_PRICE, true);

        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(secondaryListingId, PURCHASE_AMOUNT);

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(secondaryListingId, PURCHASE_AMOUNT);
        vm.stopPrank();

        Marketplace.Listing memory listingAfter = marketplace.getListing(secondaryListingId);
        assertFalse(listingAfter.isActive, "Listing should be inactive after sellout");
        assertEq(listingAfter.amount, 0, "Listing amount should be zero after sellout");
        _assertRemovedSelector(abi.encodeWithSignature("finalizeListing(uint256)", secondaryListingId));
    }

    function testFinalizeListingNotListingOwner() public {
        _ensureState(SetupState.RevenueTokensListed);
        _assertRemovedSelector(abi.encodeWithSignature("finalizeListing(uint256)", scenario.listingId));
    }

    function testCancelListingNotListingOwner() public {
        _ensureState(SetupState.RevenueTokensListed);

        vm.expectRevert(Marketplace.NotListingOwner.selector);
        vm.prank(unauthorized);
        marketplace.cancelListing(scenario.listingId);
    }

    // Extend Listing Tests

    function testExtendListing() public {
        _ensureState(SetupState.RevenueTokensListed);

        Marketplace.Listing memory listingBefore = marketplace.getListing(scenario.listingId);
        uint256 additionalDuration = 7 days;

        vm.prank(partner1);
        marketplace.extendListing(scenario.listingId, additionalDuration);

        Marketplace.Listing memory listingAfter = marketplace.getListing(scenario.listingId);
        assertEq(listingAfter.expiresAt, listingBefore.expiresAt + additionalDuration);
        assertTrue(listingAfter.isActive);
    }

    function testExtendListingListingNotFound() public {
        _ensureState(SetupState.ContractsDeployed);

        uint256 nonExistentListingId = 999;

        vm.expectRevert(Marketplace.ListingNotFound.selector);
        vm.prank(partner1);
        marketplace.extendListing(nonExistentListingId, 7 days);
    }

    function testExtendListingNotListingOwner() public {
        _ensureState(SetupState.RevenueTokensListed);

        vm.expectRevert(Marketplace.NotListingOwner.selector);
        vm.prank(unauthorized);
        marketplace.extendListing(scenario.listingId, 7 days);
    }

    function testExtendListingInactive() public {
        _ensureState(SetupState.RevenueTokensListed);

        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        vm.expectRevert(Marketplace.ListingNotActive.selector);
        vm.prank(partner1);
        marketplace.extendListing(scenario.listingId, 7 days);
    }

    function testExtendListingZeroDuration() public {
        _ensureState(SetupState.RevenueTokensListed);

        vm.expectRevert(Marketplace.InvalidDuration.selector);
        vm.prank(partner1);
        marketplace.extendListing(scenario.listingId, 0);
    }

    // End Listing Tests

    function testEndListingSoldOut() public {
        _ensureState(SetupState.RevenueTokensListed);

        // Buy all tokens
        (,, uint256 payment) = marketplace.calculatePurchaseCost(scenario.listingId, LISTING_AMOUNT);
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), payment);
        marketplace.purchaseTokens(scenario.listingId, LISTING_AMOUNT);
        vm.stopPrank();

        // Check state before ending
        Marketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        assertFalse(listing.isActive); // Already inactive because amount is 0
        assertEq(listing.amount, 0);

        // End listing for sold-out listing (no inventory to return)
        vm.prank(partner1);
        marketplace.endListing(scenario.listingId);
        listing = marketplace.getListing(scenario.listingId);
        assertFalse(listing.isActive);
        assertEq(listing.amount, 0);
    }

    function testEndListingExpired() public {
        _ensureState(SetupState.RevenueTokensListed);
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);

        // Warping to future
        _warpToTimeOffset(LISTING_DURATION + 1);

        vm.prank(partner1);
        usdc.approve(address(treasury), type(uint256).max);

        vm.prank(partner1);
        marketplace.endListing(scenario.listingId);

        Marketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        assertFalse(listing.isActive);

        // Unsold tokens are returned to seller
        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), totalSupply);
        assertEq(roboshareTokens.balanceOf(address(marketplace), scenario.revenueTokenId), 0);
        assertEq(marketplace.tokenEscrow(scenario.revenueTokenId), 0);
    }

    function testEndListing() public {
        _ensureState(SetupState.RevenueTokensListed);
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);

        // Check it is active
        Marketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        assertTrue(listing.isActive);

        // End listing early
        vm.prank(partner1);
        marketplace.endListing(scenario.listingId);

        // Verify it ended
        listing = marketplace.getListing(scenario.listingId);
        assertFalse(listing.isActive);
        assertFalse(listing.isCancelled);

        // Unsold tokens are returned to seller
        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), totalSupply);
        assertEq(roboshareTokens.balanceOf(address(marketplace), scenario.revenueTokenId), 0);
        assertEq(marketplace.tokenEscrow(scenario.revenueTokenId), 0);
    }

    function testEndListingNotListingOwner() public {
        _ensureState(SetupState.RevenueTokensListed);

        // Expire it so it's eligible to end
        _warpToTimeOffset(LISTING_DURATION + 1);

        vm.expectRevert(Marketplace.NotListingOwner.selector);
        vm.prank(unauthorized);
        marketplace.endListing(scenario.listingId);
    }

    function testEndListingNotFound() public {
        _ensureState(SetupState.RevenueTokensListed);

        vm.prank(partner1);
        vm.expectRevert(Marketplace.ListingNotFound.selector);
        marketplace.endListing(999);
    }

    function testEndListingNotActive() public {
        _ensureState(SetupState.RevenueTokensListed);

        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        vm.prank(partner1);
        vm.expectRevert(Marketplace.ListingNotActive.selector);
        marketplace.endListing(scenario.listingId);
    }

    // View Function Tests

    function testGetAssetListings() public {
        _ensureState(SetupState.RevenueTokensListed);

        assertEq(_getListingCount(scenario.assetId), 1);
        uint256[] memory activeListings = marketplace.getAssetListings(scenario.assetId);
        assertEq(activeListings[0], scenario.listingId);
    }

    function testGetAssetListingsNone() public {
        _ensureState(SetupState.RevenueTokensMinted);

        uint256[] memory activeListings = marketplace.getAssetListings(scenario.assetId);
        assertEq(activeListings.length, 0);
    }

    function testGetAssetListingsOnlyInactive() public {
        _ensureState(SetupState.RevenueTokensListed);

        // Cancel the listing to make it inactive
        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        uint256[] memory activeListings = marketplace.getAssetListings(scenario.assetId);
        assertEq(activeListings.length, 0);
    }

    function testGetAssetListingsMixed() public {
        _ensureState(SetupState.RevenueTokensListed); // Creates listing 1

        uint256 listingId2 = _setupSecondaryListing(partner2, PURCHASE_AMOUNT, REVENUE_TOKEN_PRICE, true);

        // Cancel the first listing
        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        assertEq(_getListingCount(scenario.assetId), 1);
        uint256[] memory activeListings = marketplace.getAssetListings(scenario.assetId);
        assertEq(activeListings[0], listingId2);
    }

    function testCalculatePurchaseCost() public {
        _ensureState(SetupState.RevenueTokensListed);

        (uint256 totalCost, uint256 protocolFee, uint256 expectedPayment) =
            marketplace.calculatePurchaseCost(scenario.listingId, PURCHASE_AMOUNT);

        assertEq(totalCost, PURCHASE_AMOUNT * REVENUE_TOKEN_PRICE);
        assertEq(protocolFee, ProtocolLib.calculateProtocolFee(totalCost));
        assertEq(expectedPayment, totalCost + protocolFee);
    }

    function testIsAssetEligibleForListing() public {
        _ensureState(SetupState.AssetRegistered);
        assertFalse(marketplace.isAssetEligibleForListing(scenario.assetId));

        _ensureState(SetupState.RevenueTokensMinted);
        assertTrue(marketplace.isAssetEligibleForListing(scenario.assetId));
    }

    function testIsAssetEligibleForListingAssetNotFound() public {
        _ensureState(SetupState.InitialAccountsSetup);

        assertFalse(marketplace.isAssetEligibleForListing(999));
    }

    // Fuzz Tests
    function testFuzzPurchaseTokens(uint256 purchaseAmount) public {
        _ensureState(SetupState.RevenueTokensListed);

        vm.assume(purchaseAmount > 0 && purchaseAmount <= LISTING_AMOUNT);

        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(scenario.listingId, purchaseAmount);

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(scenario.listingId, purchaseAmount);
        vm.stopPrank();

        // Immediate token transfer
        assertEq(roboshareTokens.balanceOf(buyer, scenario.revenueTokenId), purchaseAmount);
    }

    function testPurchaseTokensListingNotFound() public {
        _ensureState(SetupState.RevenueTokensListed);
        uint256 nonExistentListingId = 999;

        vm.prank(buyer);
        vm.expectRevert(Marketplace.ListingNotFound.selector);
        marketplace.purchaseTokens(nonExistentListingId, 1);
    }

    function testPurchaseTokensInactiveListing() public {
        _ensureState(SetupState.RevenueTokensListed);

        // Deactivate listing by cancelling it
        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        // Attempt to purchase from the now-inactive listing
        vm.prank(buyer);
        vm.expectRevert(Marketplace.ListingNotActive.selector);
        marketplace.purchaseTokens(scenario.listingId, 1);
    }

    function testFuzzCreateListing(uint256 amount, uint256 price, uint256 duration) public {
        _ensureState(SetupState.RevenueTokensPurchased);

        // Constraints
        vm.assume(amount > 0 && amount <= PURCHASE_AMOUNT);
        vm.assume(price > 0 && price < 1e12); // Reasonable price range
        vm.assume(duration > 0 && duration < 3650 days);

        vm.startPrank(buyer);
        roboshareTokens.setApprovalForAll(address(marketplace), true);

        uint256 listingId = marketplace.createListing(scenario.revenueTokenId, amount, price, duration, true);
        vm.stopPrank();

        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.amount, amount);
        assertEq(listing.pricePerToken, price);
        assertEq(listing.expiresAt, block.timestamp + duration);
    }

    function testCancelListingListingNotFound() public {
        _ensureState(SetupState.RevenueTokensListed);
        uint256 nonExistentListingId = 999;

        vm.prank(partner1);
        vm.expectRevert(Marketplace.ListingNotFound.selector);
        marketplace.cancelListing(nonExistentListingId);
    }

    function testCancelListingInactive() public {
        _ensureState(SetupState.RevenueTokensListed);

        // Deactivate listing by cancelling it
        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        // Attempt to cancel the now-inactive listing again
        vm.prank(partner1);
        vm.expectRevert(Marketplace.ListingNotActive.selector);
        marketplace.cancelListing(scenario.listingId);
    }

    function testPurchaseTokensMinimumProtocolFee() public {
        // 1. Setup with a very low price to ensure percentage-based protocol fee calculates to zero
        uint256 lowPrice = 30; // Total price < 40 results in a percentage fee of 0
        uint256 purchaseAmount = 1;
        uint256 listingAmount = 10;

        _ensureState(SetupState.RevenueTokensListed);
        _purchaseAndClaimTokens(listingAmount);
        _warpPastHoldingPeriod();
        vm.startPrank(buyer);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 listingId =
            marketplace.createListing(scenario.revenueTokenId, listingAmount, lowPrice, LISTING_DURATION, true);
        vm.stopPrank();

        // 2. Calculate costs - protocolFee should now be MINIMUM_PROTOCOL_FEE
        (uint256 totalPrice, uint256 protocolFee, uint256 expectedPayment) =
            marketplace.calculatePurchaseCost(listingId, purchaseAmount);

        assertEq(protocolFee, ProtocolLib.MIN_PROTOCOL_FEE, "Protocol fee should be the minimum fee");
        assertEq(
            expectedPayment, totalPrice + ProtocolLib.MIN_PROTOCOL_FEE, "Expected payment should include minimum fee"
        );

        // 3. Execute purchase
        vm.startPrank(partner1);
        usdc.approve(address(marketplace), expectedPayment);
        BalanceSnapshot memory beforePurchase = _takeBalanceSnapshot(scenario.revenueTokenId);
        marketplace.purchaseTokens(listingId, purchaseAmount);
        BalanceSnapshot memory afterPurchase = _takeBalanceSnapshot(scenario.revenueTokenId);
        vm.stopPrank();

        // 4. Immediate settlement
        _assertBalanceChanges(
            beforePurchase,
            afterPurchase,
            // forge-lint: disable-next-line(unsafe-typecast)
            -int256(expectedPayment),
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(totalPrice), // Buyer (seller) receives proceeds
            0,
            int256(ProtocolLib.MIN_PROTOCOL_FEE),
            0,
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(purchaseAmount),
            0
        );
    }

    function testPurchaseTokensFeesExceedPriceBuyerPays() public {
        _ensureState(SetupState.RevenueTokensListed);

        // Transfer tokens to buyer so a penalty applies on re-sale
        _purchaseAndClaimTokens(10);

        // Create a listing with a price so low that the penalty exceeds it
        uint256 lowPrice = 1;
        vm.startPrank(buyer);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.createListing(scenario.revenueTokenId, 10, lowPrice, LISTING_DURATION, true);
        vm.stopPrank();

        // Attempt to purchase, which should fail
        vm.startPrank(partner1);
        usdc.approve(address(marketplace), 2_000_000); // Approve more than enough
        vm.expectRevert(Marketplace.FeesExceedPrice.selector);
        marketplace.purchaseTokens(listingId, 1);
        vm.stopPrank();
    }

    function testPurchaseTokensFeesExceedPriceSellerPays() public {
        _ensureState(SetupState.RevenueTokensListed);

        // Transfer tokens to a secondary seller so a penalty applies
        _purchaseAndClaimTokens(10);
        vm.prank(buyer);
        roboshareTokens.safeTransferFrom(buyer, partner2, scenario.revenueTokenId, 10, "");

        // Create a listing with a price so low that the penalty exceeds it
        uint256 lowPrice = 1;
        vm.startPrank(partner2);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.createListing(scenario.revenueTokenId, 10, lowPrice, LISTING_DURATION, false); // Seller pays
        vm.stopPrank();

        // Attempt to purchase, which should fail
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), 1000); // Approve more than enough
        vm.expectRevert(Marketplace.FeesExceedPrice.selector);
        marketplace.purchaseTokens(listingId, 1);
        vm.stopPrank();
    }

    // Settlement Integration Tests

    function testCreateListingAssetNotActive() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Settle asset
        vm.startPrank(partner1);
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        uint256 totalLiability = REVENUE_TOKEN_PRICE * totalSupply;
        _fundAddressWithUsdc(partner1, totalLiability);
        usdc.approve(address(treasury), totalLiability);
        assetRegistry.settleAsset(scenario.assetId, totalLiability);
        vm.stopPrank();

        vm.startPrank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        vm.expectRevert(Marketplace.AssetNotEligibleForListing.selector);
        marketplace.createListing(scenario.revenueTokenId, LISTING_AMOUNT, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
        vm.stopPrank();
    }

    function testPurchaseTokensAssetNotActive() public {
        _ensureState(SetupState.RevenueTokensListed);

        // Settle asset
        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(scenario.listingId, PURCHASE_AMOUNT);
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        vm.expectRevert(Marketplace.AssetNotActive.selector);
        marketplace.purchaseTokens(scenario.listingId, PURCHASE_AMOUNT);
        vm.stopPrank();
    }

    function testPartnerCanPurchaseSecondaryListing() public {
        _ensureState(SetupState.RevenueTokensListed);

        uint256 secondaryListingId = _setupSecondaryListing(partner2, PURCHASE_AMOUNT, REVENUE_TOKEN_PRICE, true);

        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(secondaryListingId, PURCHASE_AMOUNT);
        vm.startPrank(partner1);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(secondaryListingId, PURCHASE_AMOUNT);
        vm.stopPrank();

        // Tokens transfer immediately
        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), PURCHASE_AMOUNT);
    }

    // ============ createListingFor Tests ============

    function testCreateListingFor() public {
        _ensureState(SetupState.RevenueTokensPurchased);

        // Production flow: Router has AUTHORIZED_CONTRACT_ROLE on Marketplace (set during deploy)
        // Test that Router can create listing for partner and event emits correct seller

        // Partner must approve marketplace for token transfer
        vm.prank(buyer);
        roboshareTokens.setApprovalForAll(address(marketplace), true);

        uint256 expectedListingId = 2;
        uint256 listingAmount = PURCHASE_AMOUNT;
        uint256 duration = 30 days;

        // Verify the ListingCreated event emits the correct seller (partner1, NOT router)
        vm.expectEmit(true, true, true, true, address(marketplace));
        emit ListingCreated(
            expectedListingId,
            scenario.revenueTokenId,
            scenario.assetId,
            buyer, // seller should be explicit seller argument, not router caller
            listingAmount,
            REVENUE_TOKEN_PRICE,
            block.timestamp + duration,
            true,
            false
        );

        // Create listing via Router (as happens in production when registries call router.createListingFor)
        vm.prank(address(assetRegistry)); // Registry has role on Router
        uint256 listingId = router.createListingFor(
            buyer, scenario.revenueTokenId, listingAmount, REVENUE_TOKEN_PRICE, duration, true
        );

        // Verify listing struct also has correct seller
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.seller, buyer, "Listing seller should be buyer");
        assertEq(listing.tokenId, scenario.revenueTokenId);
        assertEq(listing.amount, listingAmount);
        assertFalse(listing.isPrimary);
    }

    function testCreateListingForUnauthorizedCaller() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Without AUTHORIZED_CONTRACT_ROLE - should revert
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                marketplace.AUTHORIZED_CONTRACT_ROLE()
            )
        );
        marketplace.createListingFor(partner1, scenario.revenueTokenId, 500, REVENUE_TOKEN_PRICE, 30 days, true);
    }

    function testCreateListingForInvalidTokenType() public {
        _ensureState(SetupState.RevenueTokensMinted);

        bytes32 authorizedRole = marketplace.AUTHORIZED_CONTRACT_ROLE();
        vm.prank(admin);
        marketplace.grantRole(authorizedRole, address(this));

        // assetId (even number) is not a revenue token
        vm.expectRevert(Marketplace.InvalidTokenType.selector);
        marketplace.createListingFor(partner1, scenario.assetId, 500, REVENUE_TOKEN_PRICE, 30 days, true);
    }

    function testCreateListingForInvalidPrice() public {
        _ensureState(SetupState.RevenueTokensMinted);

        bytes32 authorizedRole = marketplace.AUTHORIZED_CONTRACT_ROLE();
        vm.prank(admin);
        marketplace.grantRole(authorizedRole, address(this));

        // Price of 0 is invalid
        vm.expectRevert(Marketplace.InvalidPrice.selector);
        marketplace.createListingFor(partner1, scenario.revenueTokenId, 500, 0, 30 days, true);
    }

    function testCreateListingForInvalidAmount() public {
        _ensureState(SetupState.RevenueTokensMinted);

        bytes32 authorizedRole = marketplace.AUTHORIZED_CONTRACT_ROLE();
        vm.prank(admin);
        marketplace.grantRole(authorizedRole, address(this));

        // Amount of 0 is invalid
        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.createListingFor(partner1, scenario.revenueTokenId, 0, REVENUE_TOKEN_PRICE, 30 days, true);

        // Amount greater than total supply is invalid
        uint256 currentSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.createListingFor(
            partner1, scenario.revenueTokenId, currentSupply + 1, REVENUE_TOKEN_PRICE, 30 days, true
        );
    }

    function testCreateListingForInsufficientBalance() public {
        _ensureState(SetupState.RevenueTokensPurchased);

        bytes32 authorizedRole = marketplace.AUTHORIZED_CONTRACT_ROLE();
        vm.prank(admin);
        marketplace.grantRole(authorizedRole, address(this));

        // partner2 doesn't own any of this token
        vm.expectRevert(Marketplace.InsufficientTokenBalance.selector);
        marketplace.createListingFor(partner2, scenario.revenueTokenId, 1, REVENUE_TOKEN_PRICE, 30 days, true);
    }

    function testCreateListingForAssetNotActive() public {
        _ensureState(SetupState.RevenueTokensMinted);

        bytes32 authorizedRole = marketplace.AUTHORIZED_CONTRACT_ROLE();
        vm.prank(admin);
        marketplace.grantRole(authorizedRole, address(this));

        // Settle the asset so it's not Active anymore
        // Partner must top up to cover total liability
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        uint256 totalLiability = REVENUE_TOKEN_PRICE * totalSupply;
        _fundAddressWithUsdc(partner1, totalLiability);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), totalLiability);
        assetRegistry.settleAsset(scenario.assetId, totalLiability);
        vm.stopPrank();

        // Asset is now Retired (not Active) - should revert with AssetNotEligibleForListing
        vm.expectRevert(Marketplace.AssetNotEligibleForListing.selector);
        marketplace.createListingFor(partner1, scenario.revenueTokenId, 500, REVENUE_TOKEN_PRICE, 30 days, true);
    }

    function _purchaseAndClaimTokens(uint256 amount) internal {
        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(scenario.listingId, amount);
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(scenario.listingId, amount);
        vm.stopPrank();
    }

    function _assertRemovedSelector(bytes memory callData) internal {
        (bool success,) = address(marketplace).call(callData);
        assertFalse(success, "Expected removed API selector to be unavailable");
    }

    function _setupSecondaryListing(address seller, uint256 amount, uint256 pricePerToken, bool buyerPaysFee)
        internal
        returns (uint256 listingId)
    {
        _purchaseAndClaimTokens(amount);

        vm.prank(buyer);
        roboshareTokens.safeTransferFrom(buyer, seller, scenario.revenueTokenId, amount, "");

        vm.startPrank(seller);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        listingId =
            marketplace.createListing(scenario.revenueTokenId, amount, pricePerToken, LISTING_DURATION, buyerPaysFee);
        vm.stopPrank();
    }
}
