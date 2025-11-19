// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";

contract MarketplaceIntegrationTest is BaseTest {
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
        emit Marketplace.ListingCreated(
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

        vm.expectRevert(Marketplace__InvalidTokenType.selector);
        vm.prank(partner1);
        marketplace.createListing(scenario.assetId, 1, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
    }

    function testCreateListingInvalidAmount() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.startPrank(partner1);
        vm.expectRevert(Marketplace__InvalidAmount.selector);
        marketplace.createListing(scenario.revenueTokenId, 0, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);

        vm.expectRevert(Marketplace__InvalidAmount.selector);
        marketplace.createListing(
            scenario.revenueTokenId, REVENUE_TOKEN_SUPPLY + 1, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
        );
        vm.stopPrank();
    }

    function testCreateListingInvalidPrice() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.prank(partner1);
        vm.expectRevert(Marketplace__InvalidPrice.selector);
        marketplace.createListing(scenario.revenueTokenId, LISTING_AMOUNT, 0, LISTING_DURATION, true);
    }

    function testCreateListingInsufficientTokenBalance() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.startPrank(partner1);
        roboshareTokens.safeTransferFrom(partner1, partner2, scenario.revenueTokenId, 600, "");

        vm.expectRevert(Marketplace__InsufficientTokenBalance.selector);
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

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);

        BalanceSnapshot memory beforeBalance = takeBalanceSnapshot(scenario.revenueTokenId);

        vm.expectEmit(true, true, true, true, address(marketplace));
        emit Marketplace.RevenueTokensTraded(
            scenario.revenueTokenId, partner1, buyer, PURCHASE_AMOUNT, scenario.listingId, totalPrice
        );

        marketplace.purchaseTokens(scenario.listingId, PURCHASE_AMOUNT);
        vm.stopPrank();

        BalanceSnapshot memory afterBalance = takeBalanceSnapshot(scenario.revenueTokenId);

        assertBalanceChanges(
            beforeBalance,
            afterBalance,
            int256(totalPrice) - int256(salesPenalty), // Partner USDC change
            -int256(expectedPayment), // Buyer USDC change
            0, // Treasury Fee Recipient USDC does not change directly
            int256(protocolFee) + int256(salesPenalty), // Treasury Contract USDC change
            0, // Partner token change (already escrowed)
            int256(PURCHASE_AMOUNT) // Buyer token change
        );

        Marketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        assertEq(listing.amount, LISTING_AMOUNT - PURCHASE_AMOUNT);
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

        // 5. Assert correct distribution of funds, including the penalty
        assertBalanceChanges(
            beforeBalance,
            afterBalance,
            int256(sellerReceives), // Partner USDC change
            -int256(expectedPayment), // Buyer USDC change
            0, // Treasury Fee Recipient USDC does not change directly
            int256(protocolFee) + int256(salesPenalty), // Treasury Contract USDC change (receives fee + penalty)
            0, // Partner token change (already escrowed)
            int256(PURCHASE_AMOUNT) // Buyer token change
        );
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

        assertBalanceChanges(
            beforeBalance,
            afterBalance,
            int256(sellerReceives), // Partner USDC change
            -int256(expectedPayment), // Buyer USDC change
            0, // Treasury Fee Recipient USDC does not change directly
            int256(protocolFee) + int256(salesPenalty), // Treasury Contract USDC change
            0, // Partner token change (already escrowed)
            int256(PURCHASE_AMOUNT) // Buyer token change
        );
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

        vm.expectRevert(Marketplace__ListingExpired.selector);
        vm.prank(buyer);
        marketplace.purchaseTokens(scenario.listingId, 100);
    }

    function testPurchaseListingInvalidAmount() public {
        _ensureState(SetupState.AssetWithListing);

        vm.expectRevert(Marketplace__InvalidAmount.selector);
        vm.prank(buyer);
        marketplace.purchaseTokens(scenario.listingId, LISTING_AMOUNT + 1);
    }

    // Cancel Listing Tests

    function testCancelListingSuccess() public {
        _ensureState(SetupState.AssetWithListing);

        uint256 partnerBalanceBefore = roboshareTokens.balanceOf(partner1, scenario.revenueTokenId);

        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        Marketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        assertFalse(listing.isActive);

        assertTokenBalance(
            partner1,
            scenario.revenueTokenId,
            partnerBalanceBefore + LISTING_AMOUNT,
            "Partner token balance mismatch after cancellation"
        );
        assertTokenBalance(
            address(marketplace), scenario.revenueTokenId, 0, "Marketplace token balance mismatch after cancellation"
        );
    }

    function testCancelListingUnauthorized() public {
        _ensureState(SetupState.AssetWithListing);

        vm.expectRevert(Marketplace__NotTokenOwner.selector);
        vm.prank(unauthorized);
        marketplace.cancelListing(scenario.listingId);
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

        assertEq(roboshareTokens.balanceOf(buyer, scenario.revenueTokenId), purchaseAmount);
    }

    function testPurchaseTokensNonExistentListing() public {
        _ensureState(SetupState.AssetWithListing);
        uint256 nonExistentListingId = 999;

        vm.prank(buyer);
        vm.expectRevert(Marketplace__ListingNotFound.selector);
        marketplace.purchaseTokens(nonExistentListingId, 1);
    }

    function testPurchaseTokensInactiveListing() public {
        _ensureState(SetupState.AssetWithListing);

        // Deactivate listing by cancelling it
        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        // Attempt to purchase from the now-inactive listing
        vm.prank(buyer);
        vm.expectRevert(Marketplace__ListingNotActive.selector);
        marketplace.purchaseTokens(scenario.listingId, 1);
    }

    function testCancelListingNonExistentListing() public {
        _ensureState(SetupState.AssetWithListing);
        uint256 nonExistentListingId = 999;

        vm.prank(partner1);
        vm.expectRevert(Marketplace__ListingNotFound.selector);
        marketplace.cancelListing(nonExistentListingId);
    }

    function testCancelListing_RevertsForInactiveListing() public {
        _ensureState(SetupState.AssetWithListing);

        // Deactivate listing by cancelling it
        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        // Attempt to cancel the now-inactive listing again
        vm.prank(partner1);
        vm.expectRevert(Marketplace__ListingNotActive.selector);
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

        // 4. Assert balances
        // Seller receives full amount, treasury contract receives the minimum fee.
        assertBalanceChanges(
            beforePurchase,
            afterPurchase,
            int256(totalPrice), // Partner USDC change
            -int256(expectedPayment), // Buyer USDC change
            0, // Treasury Fee Recipient USDC change
            int256(ProtocolLib.MIN_PROTOCOL_FEE), // Treasury Contract USDC change (receives minimum fee)
            0, // Partner token change
            int256(purchaseAmount) // Buyer token change
        );
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
        vm.expectRevert(Marketplace__FeesExceedPrice.selector);
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
        vm.expectRevert(Marketplace__FeesExceedPrice.selector);
        marketplace.purchaseTokens(listingId, 1);
        vm.stopPrank();
    }
}
