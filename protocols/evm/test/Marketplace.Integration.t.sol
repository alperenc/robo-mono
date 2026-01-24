// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseTest } from "./BaseTest.t.sol";
import { ProtocolLib, AssetLib } from "../contracts/Libraries.sol";
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
        bool buyerPaysFee
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
        _ensureState(SetupState.AccountsFunded);
    }

    // Create Listing Tests

    function testCreateListingSuccess() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.startPrank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);

        uint256 expectedListingId = 1;

        vm.expectEmit(true, true, true, true, address(marketplace));
        emit ListingCreated(
            expectedListingId,
            scenario.revenueTokenId,
            scenario.assetId,
            partner1,
            LISTING_AMOUNT,
            REVENUE_TOKEN_PRICE,
            block.timestamp + LISTING_DURATION,
            true
        );

        uint256 newListingId = marketplace.createListing(
            scenario.revenueTokenId, LISTING_AMOUNT, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
        );
        vm.stopPrank();

        assertEq(newListingId, expectedListingId);
        assertListingState(
            newListingId, scenario.revenueTokenId, LISTING_AMOUNT, REVENUE_TOKEN_PRICE, partner1, true, true
        );

        assertTokenBalance(
            address(marketplace), scenario.revenueTokenId, LISTING_AMOUNT, "Marketplace token balance mismatch"
        );
        assertTokenBalance(
            partner1, scenario.revenueTokenId, REVENUE_TOKEN_SUPPLY - LISTING_AMOUNT, "Partner token balance mismatch"
        );
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

        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.createListing(
            scenario.revenueTokenId, REVENUE_TOKEN_SUPPLY + 1, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
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
        _ensureState(SetupState.RevenueTokensMinted);

        vm.startPrank(partner1);
        roboshareTokens.safeTransferFrom(partner1, partner2, scenario.revenueTokenId, 600, "");

        vm.expectRevert(Marketplace.InsufficientTokenBalance.selector);
        marketplace.createListing(
            scenario.revenueTokenId, REVENUE_TOKEN_SUPPLY, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
        );
        vm.stopPrank();
    }

    // Purchase Listing Tests

    function testPurchaseListingBuyerPaysFee() public {
        _ensureState(SetupState.AssetWithListing);

        (uint256 totalPrice, uint256 protocolFee, uint256 expectedPayment) =
            marketplace.calculatePurchaseCost(scenario.listingId, PURCHASE_AMOUNT);
        uint256 salesPenalty = roboshareTokens.getSalesPenalty(partner1, scenario.revenueTokenId, PURCHASE_AMOUNT);
        uint256 sellerReceives = totalPrice - salesPenalty;

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);

        BalanceSnapshot memory beforeBalance = takeBalanceSnapshot(scenario.revenueTokenId);

        vm.expectEmit(true, true, true, true, address(marketplace));
        emit RevenueTokensTraded(
            scenario.revenueTokenId, partner1, buyer, PURCHASE_AMOUNT, scenario.listingId, totalPrice
        );

        marketplace.purchaseTokens(scenario.listingId, PURCHASE_AMOUNT);
        vm.stopPrank();

        BalanceSnapshot memory afterBalance = takeBalanceSnapshot(scenario.revenueTokenId);

        // Deferred proceeds: USDC held in Marketplace until listing ends
        assertBalanceChanges(
            beforeBalance,
            afterBalance,
            0, // Partner USDC change (deferred - no transfer yet)
            // forge-lint: disable-next-line(unsafe-typecast)
            -int256(expectedPayment), // Buyer USDC change
            0, // Treasury Fee Recipient USDC (deferred)
            0, // Treasury Contract USDC (deferred until listing ends)
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(sellerReceives) + int256(protocolFee) + int256(salesPenalty), // Marketplace holds USDC
            0, // Partner token change (already escrowed)
            0 // Buyer token change (HELD IN ESCROW)
        );

        // Verify listing proceeds accumulated in Marketplace (not Treasury pendingWithdrawals)
        assertEq(marketplace.listingProceeds(scenario.listingId), sellerReceives, "Listing proceeds mismatch");
        assertEq(
            marketplace.listingProtocolFees(scenario.listingId),
            protocolFee + salesPenalty,
            "Listing protocol fees mismatch"
        );

        Marketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        assertEq(listing.amount, LISTING_AMOUNT - PURCHASE_AMOUNT);
        assertEq(listing.soldAmount, PURCHASE_AMOUNT);
        assertEq(marketplace.buyerTokens(scenario.listingId, buyer), PURCHASE_AMOUNT);
    }

    function testPurchaseListingEarlySalePenalty() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // 1. Transfer Asset NFT from partner1 to partner2, so partner1 is no longer the owner.
        vm.prank(partner1);
        roboshareTokens.safeTransferFrom(partner1, partner2, scenario.assetId, 1, "");

        // 2. Create a new listing with seller paying the fee
        vm.startPrank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 newListingId = marketplace.createListing(
            scenario.revenueTokenId, PURCHASE_AMOUNT, REVENUE_TOKEN_PRICE, LISTING_DURATION, false
        );
        vm.stopPrank();

        // 3. Calculate expected costs, including the penalty
        (uint256 totalPrice, uint256 protocolFee, uint256 expectedPayment) =
            marketplace.calculatePurchaseCost(newListingId, PURCHASE_AMOUNT);

        uint256 salesPenalty = roboshareTokens.getSalesPenalty(partner1, scenario.revenueTokenId, PURCHASE_AMOUNT);
        assertGt(salesPenalty, 0, "Sales penalty should be greater than zero");

        uint256 sellerReceives = totalPrice - protocolFee - salesPenalty;

        // 4. Buyer purchases the tokens
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);

        BalanceSnapshot memory beforeBalance = takeBalanceSnapshot(scenario.revenueTokenId);

        marketplace.purchaseTokens(newListingId, PURCHASE_AMOUNT);
        vm.stopPrank();

        BalanceSnapshot memory afterBalance = takeBalanceSnapshot(scenario.revenueTokenId);

        // 5. Deferred proceeds: USDC held in Marketplace until listing ends
        assertBalanceChanges(
            beforeBalance,
            afterBalance,
            0, // Partner USDC change (deferred)
            // forge-lint: disable-next-line(unsafe-typecast)
            -int256(expectedPayment), // Buyer USDC change
            0, // Treasury Fee Recipient USDC (deferred)
            0, // Treasury Contract USDC (deferred until listing ends)
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(totalPrice), // Marketplace holds USDC
            0, // Partner token change (already escrowed)
            0 // Buyer token change (HELD IN ESCROW)
        );

        // Verify listing proceeds accumulated in Marketplace
        assertEq(marketplace.listingProceeds(newListingId), sellerReceives, "Listing proceeds mismatch");
        assertEq(marketplace.buyerTokens(newListingId, buyer), PURCHASE_AMOUNT);
    }

    function testPurchaseListingSellerPaysFee() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Create a new listing with seller paying the fee
        vm.startPrank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 newListingId = marketplace.createListing(
            scenario.revenueTokenId, PURCHASE_AMOUNT, REVENUE_TOKEN_PRICE, LISTING_DURATION, false
        );
        vm.stopPrank();

        (uint256 totalPrice, uint256 protocolFee, uint256 expectedPayment) =
            marketplace.calculatePurchaseCost(newListingId, PURCHASE_AMOUNT);
        uint256 salesPenalty = roboshareTokens.getSalesPenalty(partner1, scenario.revenueTokenId, PURCHASE_AMOUNT);
        uint256 sellerReceives = totalPrice - protocolFee - salesPenalty;

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);

        BalanceSnapshot memory beforeBalance = takeBalanceSnapshot(scenario.revenueTokenId);

        marketplace.purchaseTokens(newListingId, PURCHASE_AMOUNT);
        vm.stopPrank();

        BalanceSnapshot memory afterBalance = takeBalanceSnapshot(scenario.revenueTokenId);

        // Deferred proceeds: USDC held in Marketplace until listing ends
        assertBalanceChanges(
            beforeBalance,
            afterBalance,
            0, // Partner USDC change (deferred)
            // forge-lint: disable-next-line(unsafe-typecast)
            -int256(expectedPayment), // Buyer USDC change
            0, // Treasury Fee Recipient USDC (deferred)
            0, // Treasury Contract USDC (deferred until listing ends)
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(totalPrice), // Marketplace holds USDC
            0, // Partner token change (already escrowed)
            0 // Buyer token change (HELD IN ESCROW)
        );

        // Verify listing proceeds accumulated in Marketplace
        assertEq(marketplace.listingProceeds(newListingId), sellerReceives, "Listing proceeds mismatch");
        assertEq(marketplace.buyerTokens(newListingId, buyer), PURCHASE_AMOUNT);
    }

    function testPurchaseListingCompletelyExhaustsListing() public {
        _ensureState(SetupState.AssetWithListing);

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

        // Tokens held in escrow, not transferred yet
        assertEq(roboshareTokens.balanceOf(buyer, scenario.revenueTokenId), 0);
        assertEq(marketplace.buyerTokens(scenario.listingId, buyer), LISTING_AMOUNT);

        // To claim tokens, we must end the listing (which is already inactive due to 0 amount, but needs settlement)
        vm.prank(partner1);
        marketplace.endListing(scenario.listingId);

        // Now buyer can claim
        vm.prank(buyer);
        marketplace.claimTokens(scenario.listingId);

        assertEq(roboshareTokens.balanceOf(buyer, scenario.revenueTokenId), LISTING_AMOUNT);
        assertTokenBalance(address(marketplace), scenario.revenueTokenId, 0, "Marketplace token balance mismatch");
    }

    function testPurchaseListingInsufficientPayment() public {
        _ensureState(SetupState.AssetWithListing);

        uint256 totalPrice = PURCHASE_AMOUNT * REVENUE_TOKEN_PRICE;
        uint256 protocolFee = ProtocolLib.calculateProtocolFee(totalPrice);
        uint256 requiredPayment = totalPrice + protocolFee;

        address poorBuyer = makeAddr("poorBuyer");
        setupInsufficientFunds(poorBuyer, requiredPayment);

        vm.startPrank(poorBuyer);
        usdc.approve(address(marketplace), requiredPayment);

        vm.expectRevert(); // ERC20: transfer amount exceeds balance
        marketplace.purchaseTokens(scenario.listingId, PURCHASE_AMOUNT);
        vm.stopPrank();
    }

    function testPurchaseListingExpired() public {
        _ensureState(SetupState.AssetWithListing);

        setupExpiredListing(scenario.listingId);

        vm.expectRevert(Marketplace.ListingExpired.selector);
        vm.prank(buyer);
        marketplace.purchaseTokens(scenario.listingId, 100);
    }

    function testPurchaseListingInvalidAmount() public {
        _ensureState(SetupState.AssetWithListing);

        vm.expectRevert(Marketplace.InvalidAmount.selector);
        vm.prank(buyer);
        marketplace.purchaseTokens(scenario.listingId, LISTING_AMOUNT + 1);
    }

    // Cancel Listing Tests

    function testCancelListingSuccess() public {
        _ensureState(SetupState.AssetWithListing);

        // 1. Purchase some tokens to have them in escrow
        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(scenario.listingId, PURCHASE_AMOUNT);
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(scenario.listingId, PURCHASE_AMOUNT);
        vm.stopPrank();

        uint256 partnerBalanceBefore = roboshareTokens.balanceOf(partner1, scenario.revenueTokenId);
        uint256 buyerUsdcBefore = usdc.balanceOf(buyer);

        // 2. Cancel listing
        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        Marketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        assertFalse(listing.isActive);
        assertTrue(listing.isCancelled);

        // 3. Verify seller received ALL tokens (unsold + sold)
        // Seller had (Total - ListingAmount) + (ListingAmount - PurchaseAmount) returned + PurchaseAmount (escrowed) returned
        // So Seller should have original Total - ListingAmount + ListingAmount = Original Total
        // Wait, logic:
        // Before cancel: Seller has Total - ListingAmount.
        // Listing has ListingAmount - PurchaseAmount (unsold) + PurchaseAmount (sold).
        // Return = ListingAmount.
        // Result: Seller has Total.
        assertTokenBalance(
            partner1,
            scenario.revenueTokenId,
            partnerBalanceBefore + LISTING_AMOUNT, // Returns everything
            "Partner token balance mismatch after cancellation"
        );
        assertTokenBalance(
            address(marketplace), scenario.revenueTokenId, 0, "Marketplace token balance mismatch after cancellation"
        );

        // 4. Verify buyer cannot claim tokens
        vm.prank(buyer);
        vm.expectRevert(Marketplace.ListingNotEnded.selector);
        marketplace.claimTokens(scenario.listingId);

        // 5. Verify buyer can claim refund
        vm.prank(buyer);
        marketplace.claimRefund(scenario.listingId);

        assertEq(usdc.balanceOf(buyer), buyerUsdcBefore + expectedPayment, "Buyer refund mismatch");
        assertEq(marketplace.buyerPayments(scenario.listingId, buyer), 0, "Buyer payment state mismatch");
    }

    // Finalize Listing Tests

    function testFinalizeListingWithPendingProceeds() public {
        _ensureState(SetupState.AssetWithListing);

        // First, make a partial purchase to generate proceeds held in Marketplace
        (uint256 totalPrice,, uint256 expectedPayment) =
            marketplace.calculatePurchaseCost(scenario.listingId, PURCHASE_AMOUNT);
        uint256 salesPenalty = roboshareTokens.getSalesPenalty(partner1, scenario.revenueTokenId, PURCHASE_AMOUNT);
        uint256 sellerReceives = totalPrice - salesPenalty; // buyerPaysFee = true

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(scenario.listingId, PURCHASE_AMOUNT);
        vm.stopPrank();

        // Verify proceeds are held in Marketplace (not Treasury pendingWithdrawals)
        assertEq(marketplace.listingProceeds(scenario.listingId), sellerReceives, "Listing proceeds before finalize");
        assertEq(treasury.getPendingWithdrawal(partner1), 0, "Pending withdrawal should be zero before finalize");

        uint256 partnerUsdcBefore = usdc.balanceOf(partner1);
        uint256 partnerTokensBefore = roboshareTokens.balanceOf(partner1, scenario.revenueTokenId);

        // Finalize listing - should cancel remaining listing, transfer to Treasury, AND withdraw proceeds
        vm.prank(partner1);
        uint256 withdrawn = marketplace.finalizeListing(scenario.listingId);

        // Verify withdrawal happened
        assertEq(withdrawn, sellerReceives, "Withdrawn amount mismatch");
        assertEq(usdc.balanceOf(partner1), partnerUsdcBefore + sellerReceives, "Partner USDC after finalize");

        // Verify listing was ended (not cancelled in the refund sense)
        Marketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        assertFalse(listing.isActive, "Listing should be inactive");
        assertFalse(listing.isCancelled, "Listing should NOT be cancelled");

        // Verify unsold tokens returned to seller
        uint256 unsoldTokens = LISTING_AMOUNT - PURCHASE_AMOUNT;
        assertEq(
            roboshareTokens.balanceOf(partner1, scenario.revenueTokenId),
            partnerTokensBefore + unsoldTokens,
            "Partner tokens after finalize"
        );

        // Verify listing proceeds cleared
        assertEq(marketplace.listingProceeds(scenario.listingId), 0, "Listing proceeds should be zero after finalize");
        assertEq(treasury.getPendingWithdrawal(partner1), 0, "Pending withdrawal should be zero after finalize");

        // Verify Buyer can claim tokens
        vm.prank(buyer);
        marketplace.claimTokens(scenario.listingId);
        assertEq(roboshareTokens.balanceOf(buyer, scenario.revenueTokenId), PURCHASE_AMOUNT);

        // Verify Buyer cannot claim refund
        vm.prank(buyer);
        vm.expectRevert(Marketplace.ListingNotCancelled.selector);
        marketplace.claimRefund(scenario.listingId);
    }

    function testFinalizeListingAlreadyCancelled() public {
        _ensureState(SetupState.AssetWithListing);

        // First cancel the listing
        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        // Finalize should still work (just no tokens to return)
        vm.prank(partner1);
        uint256 withdrawn = marketplace.finalizeListing(scenario.listingId);

        // No proceeds to withdraw
        assertEq(withdrawn, 0, "No withdrawal expected");
    }

    function testFinalizeListingUnauthorized() public {
        _ensureState(SetupState.AssetWithListing);

        vm.expectRevert(Marketplace.NotTokenOwner.selector);
        vm.prank(unauthorized);
        marketplace.finalizeListing(scenario.listingId);
    }

    function testCancelListingUnauthorized() public {
        _ensureState(SetupState.AssetWithListing);

        vm.expectRevert(Marketplace.NotTokenOwner.selector);
        vm.prank(unauthorized);
        marketplace.cancelListing(scenario.listingId);
    }

    // Extend Listing Tests

    function testExtendListingSuccess() public {
        _ensureState(SetupState.AssetWithListing);

        Marketplace.Listing memory listingBefore = marketplace.getListing(scenario.listingId);
        uint256 additionalDuration = 7 days;

        vm.prank(partner1);
        marketplace.extendListing(scenario.listingId, additionalDuration);

        Marketplace.Listing memory listingAfter = marketplace.getListing(scenario.listingId);
        assertEq(listingAfter.expiresAt, listingBefore.expiresAt + additionalDuration);
        assertTrue(listingAfter.isActive);
    }

    function testExtendListingNonExistent() public {
        _ensureState(SetupState.ContractsDeployed);

        uint256 nonExistentListingId = 999;

        vm.expectRevert(Marketplace.ListingNotFound.selector);
        vm.prank(partner1);
        marketplace.extendListing(nonExistentListingId, 7 days);
    }

    function testExtendListingUnauthorized() public {
        _ensureState(SetupState.AssetWithListing);

        vm.expectRevert(Marketplace.NotTokenOwner.selector);
        vm.prank(unauthorized);
        marketplace.extendListing(scenario.listingId, 7 days);
    }

    function testExtendListingInactive() public {
        _ensureState(SetupState.AssetWithListing);

        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        vm.expectRevert(Marketplace.ListingNotActive.selector);
        vm.prank(partner1);
        marketplace.extendListing(scenario.listingId, 7 days);
    }

    function testExtendListingZeroDuration() public {
        _ensureState(SetupState.AssetWithListing);

        vm.expectRevert(Marketplace.InvalidDuration.selector);
        vm.prank(partner1);
        marketplace.extendListing(scenario.listingId, 0);
    }

    // End Listing Tests

    function testEndListingSoldOut() public {
        _ensureState(SetupState.AssetWithListing);

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

        // End listing to settle proceeds
        vm.prank(partner1);
        marketplace.endListing(scenario.listingId);

        // Verify proceeds settled
        assertEq(marketplace.listingProceeds(scenario.listingId), 0);
        assertGt(treasury.getPendingWithdrawal(partner1), 0);
    }

    function testEndListingExpired() public {
        _ensureState(SetupState.AssetWithListing);

        // Warping to future
        vm.warp(block.timestamp + LISTING_DURATION + 1);

        vm.prank(partner1);
        marketplace.endListing(scenario.listingId);

        Marketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        assertFalse(listing.isActive);

        // Unsold tokens should be returned
        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), REVENUE_TOKEN_SUPPLY);
    }

    function testEndListingActiveSuccess() public {
        _ensureState(SetupState.AssetWithListing);

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

        // Unsold tokens returned
        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), REVENUE_TOKEN_SUPPLY);
    }

    function testEndListingUnauthorized() public {
        _ensureState(SetupState.AssetWithListing);

        // Expire it so it's eligible to end
        vm.warp(block.timestamp + LISTING_DURATION + 1);

        vm.expectRevert(Marketplace.NotTokenOwner.selector);
        vm.prank(unauthorized);
        marketplace.endListing(scenario.listingId);
    }

    // View Function Tests

    function testGetAssetListings() public {
        _ensureState(SetupState.AssetWithListing);

        uint256[] memory activeListings = marketplace.getAssetListings(scenario.assetId);
        assertEq(activeListings.length, 1);
        assertEq(activeListings[0], scenario.listingId);
    }

    function testGetAssetListingsNoListings() public {
        _ensureState(SetupState.RevenueTokensMinted);

        uint256[] memory activeListings = marketplace.getAssetListings(scenario.assetId);
        assertEq(activeListings.length, 0);
    }

    function testGetAssetListingsOnlyInactive() public {
        _ensureState(SetupState.AssetWithListing);

        // Cancel the listing to make it inactive
        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        uint256[] memory activeListings = marketplace.getAssetListings(scenario.assetId);
        assertEq(activeListings.length, 0);
    }

    function testGetAssetListingsMixed() public {
        _ensureState(SetupState.AssetWithListing); // Creates listing 1

        // Create a second listing
        vm.prank(partner1);
        uint256 listingId2 =
            marketplace.createListing(scenario.revenueTokenId, 50, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);

        // Cancel the first listing
        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        uint256[] memory activeListings = marketplace.getAssetListings(scenario.assetId);
        assertEq(activeListings.length, 1);
        assertEq(activeListings[0], listingId2);
    }

    function testCalculatePurchaseCost() public {
        _ensureState(SetupState.AssetWithListing);

        (uint256 totalCost, uint256 protocolFee, uint256 expectedPayment) =
            marketplace.calculatePurchaseCost(scenario.listingId, PURCHASE_AMOUNT);

        assertEq(totalCost, PURCHASE_AMOUNT * REVENUE_TOKEN_PRICE);
        assertEq(protocolFee, ProtocolLib.calculateProtocolFee(totalCost));
        assertEq(expectedPayment, totalCost + protocolFee);
    }

    function testIsAssetEligibleForListing() public {
        _ensureState(SetupState.AssetRegistered);
        assertFalse(marketplace.isAssetEligibleForListing(scenario.assetId));

        vm.startPrank(partner1);
        usdc.approve(
            address(treasury), treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY)
        );
        treasury.lockCollateral(scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();

        assertTrue(marketplace.isAssetEligibleForListing(scenario.assetId));
    }

    // Fuzz Tests
    function testFuzzPurchaseListing(uint256 purchaseAmount) public {
        _ensureState(SetupState.AssetWithListing);

        vm.assume(purchaseAmount > 0 && purchaseAmount <= LISTING_AMOUNT);

        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(scenario.listingId, purchaseAmount);

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(scenario.listingId, purchaseAmount);
        vm.stopPrank();

        // Tokens are escrowed
        assertEq(roboshareTokens.balanceOf(buyer, scenario.revenueTokenId), 0);
        assertEq(marketplace.buyerTokens(scenario.listingId, buyer), purchaseAmount);

        // Claim tokens
        vm.prank(partner1);
        marketplace.endListing(scenario.listingId);

        vm.prank(buyer);
        marketplace.claimTokens(scenario.listingId);

        assertEq(roboshareTokens.balanceOf(buyer, scenario.revenueTokenId), purchaseAmount);
    }

    function testPurchaseTokensNonExistentListing() public {
        _ensureState(SetupState.AssetWithListing);
        uint256 nonExistentListingId = 999;

        vm.prank(buyer);
        vm.expectRevert(Marketplace.ListingNotFound.selector);
        marketplace.purchaseTokens(nonExistentListingId, 1);
    }

    function testPurchaseTokensInactiveListing() public {
        _ensureState(SetupState.AssetWithListing);

        // Deactivate listing by cancelling it
        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        // Attempt to purchase from the now-inactive listing
        vm.prank(buyer);
        vm.expectRevert(Marketplace.ListingNotActive.selector);
        marketplace.purchaseTokens(scenario.listingId, 1);
    }

    function testCancelListingNonExistentListing() public {
        _ensureState(SetupState.AssetWithListing);
        uint256 nonExistentListingId = 999;

        vm.prank(partner1);
        vm.expectRevert(Marketplace.ListingNotFound.selector);
        marketplace.cancelListing(nonExistentListingId);
    }

    function testCancelListing_RevertsForInactiveListing() public {
        _ensureState(SetupState.AssetWithListing);

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

        // Manual setup since we're using custom price
        _ensureState(SetupState.RevenueTokensMinted);
        vm.startPrank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.createListing(
            scenario.revenueTokenId,
            listingAmount,
            lowPrice,
            LISTING_DURATION,
            true // buyerPaysFee = true
        );
        vm.stopPrank();

        // 2. Calculate costs - protocolFee should now be MINIMUM_PROTOCOL_FEE
        (uint256 totalPrice, uint256 protocolFee, uint256 expectedPayment) =
            marketplace.calculatePurchaseCost(listingId, purchaseAmount);

        assertEq(protocolFee, ProtocolLib.MIN_PROTOCOL_FEE, "Protocol fee should be the minimum fee");
        assertEq(
            expectedPayment, totalPrice + ProtocolLib.MIN_PROTOCOL_FEE, "Expected payment should include minimum fee"
        );

        // 3. Execute purchase
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        BalanceSnapshot memory beforePurchase = takeBalanceSnapshot(scenario.revenueTokenId);
        marketplace.purchaseTokens(listingId, purchaseAmount);
        BalanceSnapshot memory afterPurchase = takeBalanceSnapshot(scenario.revenueTokenId);
        vm.stopPrank();

        // 4. Deferred proceeds: USDC held in Marketplace until listing ends
        assertBalanceChanges(
            beforePurchase,
            afterPurchase,
            0, // Partner USDC change (deferred)
            // forge-lint: disable-next-line(unsafe-typecast)
            -int256(expectedPayment), // Buyer USDC change
            0, // Treasury Fee Recipient USDC change
            0, // Treasury Contract USDC change (deferred until listing ends)
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(expectedPayment), // Marketplace holds USDC
            0, // Partner token change
            0 // Buyer token change (HELD IN ESCROW)
        );

        // Verify listing proceeds accumulated in Marketplace
        assertEq(marketplace.listingProceeds(listingId), totalPrice, "Listing proceeds mismatch");
        assertEq(marketplace.buyerTokens(listingId, buyer), purchaseAmount);
    }

    function testPurchaseListingFeesExceedPriceBuyerPays() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Transfer asset so seller is not the owner and incurs a penalty
        vm.prank(partner1);
        roboshareTokens.safeTransferFrom(partner1, partner2, scenario.assetId, 1, "");

        // Create a listing with a price so low that the penalty exceeds it
        uint256 lowPrice = 1;
        vm.startPrank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.createListing(scenario.revenueTokenId, 10, lowPrice, LISTING_DURATION, true);
        vm.stopPrank();

        // Attempt to purchase, which should fail
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), 1000); // Approve more than enough
        vm.expectRevert(Marketplace.FeesExceedPrice.selector);
        marketplace.purchaseTokens(listingId, 1);
        vm.stopPrank();
    }

    function testPurchaseListingFeesExceedPriceSellerPays() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Transfer asset so seller is not the owner and incurs a penalty
        vm.prank(partner1);
        roboshareTokens.safeTransferFrom(partner1, partner2, scenario.assetId, 1, "");

        // Create a listing with a price so low that the penalty exceeds it
        uint256 lowPrice = 1;
        vm.startPrank(partner1);
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

    function testCreateListingRevertsWhenSettled() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Settle asset
        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        vm.startPrank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        vm.expectRevert(Marketplace.ListingNotActive.selector);
        marketplace.createListing(scenario.revenueTokenId, LISTING_AMOUNT, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
        vm.stopPrank();
    }

    function testPurchaseRevertsWhenSettled() public {
        _ensureState(SetupState.AssetWithListing);

        // Settle asset
        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), 1e9);
        vm.expectRevert(Marketplace.ListingNotActive.selector);
        marketplace.purchaseTokens(scenario.listingId, PURCHASE_AMOUNT);
        vm.stopPrank();
    }

    // ============ createListingFor Tests ============

    function testCreateListingForSuccess() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Production flow: Router has AUTHORIZED_CONTRACT_ROLE on Marketplace (set during deploy)
        // Test that Router can create listing for partner and event emits correct seller

        // Partner must approve marketplace for token transfer
        vm.prank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);

        uint256 expectedListingId = 1;
        uint256 listingAmount = 500;
        uint256 duration = 30 days;

        // Verify the ListingCreated event emits the correct seller (partner1, NOT router)
        vm.expectEmit(true, true, true, true, address(marketplace));
        emit ListingCreated(
            expectedListingId,
            scenario.revenueTokenId,
            scenario.assetId,
            partner1, // Critical: This should be the actual seller, not msg.sender (router)
            listingAmount,
            REVENUE_TOKEN_PRICE,
            block.timestamp + duration,
            true
        );

        // Create listing via Router (as happens in production when registries call router.createListingFor)
        vm.prank(address(assetRegistry)); // Registry has role on Router
        uint256 listingId = router.createListingFor(
            partner1, scenario.revenueTokenId, listingAmount, REVENUE_TOKEN_PRICE, duration, true
        );

        // Verify listing struct also has correct seller
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.seller, partner1, "Listing seller should be partner1");
        assertEq(listing.tokenId, scenario.revenueTokenId);
        assertEq(listing.amount, listingAmount);
    }

    function testCreateListingForUnauthorized() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Without AUTHORIZED_CONTRACT_ROLE - should revert
        vm.expectRevert();
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
        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.createListingFor(
            partner1, scenario.revenueTokenId, REVENUE_TOKEN_SUPPLY + 1, REVENUE_TOKEN_PRICE, 30 days, true
        );
    }

    function testCreateListingForInsufficientBalance() public {
        _ensureState(SetupState.RevenueTokensMinted);

        bytes32 authorizedRole = marketplace.AUTHORIZED_CONTRACT_ROLE();
        vm.prank(admin);
        marketplace.grantRole(authorizedRole, address(this));

        // partner2 doesn't own any of this token
        vm.expectRevert(Marketplace.InsufficientTokenBalance.selector);
        marketplace.createListingFor(partner2, scenario.revenueTokenId, 500, REVENUE_TOKEN_PRICE, 30 days, true);
    }

    function testCreateListingForAssetNotActive() public {
        _ensureState(SetupState.RevenueTokensMinted);

        bytes32 authorizedRole = marketplace.AUTHORIZED_CONTRACT_ROLE();
        vm.prank(admin);
        marketplace.grantRole(authorizedRole, address(this));

        // Settle the asset so it's not Active anymore
        // Partner must top up to cover total liability
        uint256 totalLiability = REVENUE_TOKEN_PRICE * REVENUE_TOKEN_SUPPLY;
        deal(address(usdc), partner1, totalLiability);
        vm.startPrank(partner1);
        usdc.approve(address(treasury), totalLiability);
        assetRegistry.settleAsset(scenario.assetId, totalLiability);
        vm.stopPrank();

        // Asset is now Retired (not Active) - should revert with AssetNotActive
        vm.expectRevert(Marketplace.AssetNotActive.selector);
        marketplace.createListingFor(partner1, scenario.revenueTokenId, 500, REVENUE_TOKEN_PRICE, 30 days, true);
    }

    // ============ registerAssetMintAndList Integration Test ============

    function testRegisterAssetMintAndListFullFlow() public {
        _ensureState(SetupState.PartnersAuthorized);

        // Setup: Configure marketplace on Router and grant role to Router
        vm.startPrank(admin);
        router.setMarketplace(address(marketplace));
        marketplace.grantRole(marketplace.AUTHORIZED_CONTRACT_ROLE(), address(router));
        vm.stopPrank();

        // Partner must approve marketplace for token transfers
        vm.startPrank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);

        // Prepare collateral
        uint256 requiredCollateral = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        deal(address(usdc), partner1, requiredCollateral);
        usdc.approve(address(treasury), requiredCollateral);

        // Use a different VIN for this test
        bytes memory vehicleData = abi.encode(
            "UNIQUE123456789", // Different VIN
            TEST_MAKE,
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            TEST_METADATA_URI
        );

        // Execute: Register, mint, and list in one transaction!
        (uint256 assetId, uint256 revenueTokenId, uint256 listingId) = assetRegistry.registerAssetMintAndList(
            vehicleData, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY, block.timestamp + 365 days, 30 days, true
        );
        vm.stopPrank();

        // Verify: Asset was registered and activated
        assertTrue(assetRegistry.assetExists(assetId));
        assertEq(uint8(assetRegistry.getAssetStatus(assetId)), uint8(AssetLib.AssetStatus.Active));

        // Verify: Revenue tokens were minted (but transferred to marketplace for escrow)
        assertEq(roboshareTokens.balanceOf(address(marketplace), revenueTokenId), REVENUE_TOKEN_SUPPLY);

        // Verify: Listing was created with full supply at face value
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        assertEq(listing.seller, partner1);
        assertEq(listing.tokenId, revenueTokenId);
        assertEq(listing.amount, REVENUE_TOKEN_SUPPLY);
        assertEq(listing.pricePerToken, REVENUE_TOKEN_PRICE);
        assertTrue(listing.isActive);
    }
}
