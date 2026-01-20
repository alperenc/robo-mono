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

    // Local constants for test values
    uint256 constant TRANSFER_AMOUNT = 600;
    uint256 constant SMALL_LISTING_AMOUNT = 50;
    uint256 constant LOW_PRICE = 30;

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
        roboshareTokens.safeTransferFrom(partner1, partner2, scenario.revenueTokenId, TRANSFER_AMOUNT, "");

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

        assertBalanceChanges(
            beforeBalance,
            afterBalance,
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(totalPrice) - int256(salesPenalty), // Partner USDC change
            // forge-lint: disable-next-line(unsafe-typecast)
            -int256(expectedPayment), // Buyer USDC change
            0, // Treasury Fee Recipient USDC does not change directly
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(protocolFee) + int256(salesPenalty), // Treasury Contract USDC change
            0, // Partner token change (already escrowed)
            // forge-lint: disable-next-line(unsafe-typecast)
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
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(sellerReceives), // Partner USDC change
            // forge-lint: disable-next-line(unsafe-typecast)
            -int256(expectedPayment), // Buyer USDC change
            0, // Treasury Fee Recipient USDC does not change directly
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(protocolFee) + int256(salesPenalty), // Treasury Contract USDC change (receives fee + penalty)
            0, // Partner token change (already escrowed)
            // forge-lint: disable-next-line(unsafe-typecast)
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
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(sellerReceives), // Partner USDC change
            // forge-lint: disable-next-line(unsafe-typecast)
            -int256(expectedPayment), // Buyer USDC change
            0, // Treasury Fee Recipient USDC does not change directly
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(protocolFee) + int256(salesPenalty), // Treasury Contract USDC change
            0, // Partner token change (already escrowed)
            // forge-lint: disable-next-line(unsafe-typecast)
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

        vm.expectRevert(Marketplace.NotTokenOwner.selector);
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
            marketplace.createListing(scenario.revenueTokenId, SMALL_LISTING_AMOUNT, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);

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
        uint256 nonExistentListingId = INVALID_LISTING_ID;

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
        uint256 nonExistentListingId = INVALID_LISTING_ID;

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
        uint256 lowPrice = LOW_PRICE; // Total price < 40 results in a percentage fee of 0
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
            // forge-lint: disable-next-line(unsafe-typecast)
            int256(totalPrice), // Partner USDC change
            // forge-lint: disable-next-line(unsafe-typecast)
            -int256(expectedPayment), // Buyer USDC change
            0, // Treasury Fee Recipient USDC change
            int256(ProtocolLib.MIN_PROTOCOL_FEE), // Treasury Contract USDC change (receives minimum fee)
            0, // Partner token change
            // forge-lint: disable-next-line(unsafe-typecast)
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
        uint256 listingAmount = MEDIUM_TOKEN_AMOUNT;
        uint256 duration = ONE_MONTH_DAYS * 1 days;

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
        marketplace.createListingFor(partner1, scenario.revenueTokenId, MEDIUM_TOKEN_AMOUNT, REVENUE_TOKEN_PRICE, ONE_MONTH_DAYS * 1 days, true);
    }

    function testCreateListingForInvalidTokenType() public {
        _ensureState(SetupState.RevenueTokensMinted);

        bytes32 authorizedRole = marketplace.AUTHORIZED_CONTRACT_ROLE();
        vm.prank(admin);
        marketplace.grantRole(authorizedRole, address(this));

        // assetId (even number) is not a revenue token
        vm.expectRevert(Marketplace.InvalidTokenType.selector);
        marketplace.createListingFor(partner1, scenario.assetId, MEDIUM_TOKEN_AMOUNT, REVENUE_TOKEN_PRICE, ONE_MONTH_DAYS * 1 days, true);
    }

    function testCreateListingForInvalidPrice() public {
        _ensureState(SetupState.RevenueTokensMinted);

        bytes32 authorizedRole = marketplace.AUTHORIZED_CONTRACT_ROLE();
        vm.prank(admin);
        marketplace.grantRole(authorizedRole, address(this));

        // Price of 0 is invalid
        vm.expectRevert(Marketplace.InvalidPrice.selector);
        marketplace.createListingFor(partner1, scenario.revenueTokenId, MEDIUM_TOKEN_AMOUNT, 0, ONE_MONTH_DAYS * 1 days, true);
    }

    function testCreateListingForInvalidAmount() public {
        _ensureState(SetupState.RevenueTokensMinted);

        bytes32 authorizedRole = marketplace.AUTHORIZED_CONTRACT_ROLE();
        vm.prank(admin);
        marketplace.grantRole(authorizedRole, address(this));

        // Amount of 0 is invalid
        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.createListingFor(partner1, scenario.revenueTokenId, 0, REVENUE_TOKEN_PRICE, ONE_MONTH_DAYS * 1 days, true);

        // Amount greater than total supply is invalid
        vm.expectRevert(Marketplace.InvalidAmount.selector);
        marketplace.createListingFor(
            partner1, scenario.revenueTokenId, REVENUE_TOKEN_SUPPLY + 1, REVENUE_TOKEN_PRICE, ONE_MONTH_DAYS * 1 days, true
        );
    }

    function testCreateListingForInsufficientBalance() public {
        _ensureState(SetupState.RevenueTokensMinted);

        bytes32 authorizedRole = marketplace.AUTHORIZED_CONTRACT_ROLE();
        vm.prank(admin);
        marketplace.grantRole(authorizedRole, address(this));

        // partner2 doesn't own any of this token
        vm.expectRevert(Marketplace.InsufficientTokenBalance.selector);
        marketplace.createListingFor(partner2, scenario.revenueTokenId, MEDIUM_TOKEN_AMOUNT, REVENUE_TOKEN_PRICE, ONE_MONTH_DAYS * 1 days, true);
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
        marketplace.createListingFor(partner1, scenario.revenueTokenId, MEDIUM_TOKEN_AMOUNT, REVENUE_TOKEN_PRICE, ONE_MONTH_DAYS * 1 days, true);
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
            vehicleData, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY, block.timestamp + ONE_YEAR_DAYS * 1 days, ONE_MONTH_DAYS * 1 days, true
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
