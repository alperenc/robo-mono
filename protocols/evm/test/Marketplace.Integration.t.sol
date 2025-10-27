// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";

contract MarketplaceIntegrationTest is BaseTest {
    function setUp() public {
        _ensureState(SetupState.VehicleWithTokens);
    }



    // Lock Collateral and List Tests

    function testLockCollateralAndListSuccess() public {
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        roboshareTokens.setApprovalForAll(address(marketplace), true);

        uint256 expectedListingId = 1;

        vm.expectEmit(true, true, true, true, address(marketplace));
        emit Marketplace.CollateralLockedAndListed(
            scenario.vehicleId,
            scenario.revenueTokenId,
            expectedListingId,
            partner1,
            requiredCollateral,
            PURCHASE_AMOUNT,
            REVENUE_TOKEN_PRICE,
            true
        );

        uint256 newListingId = marketplace.lockCollateralAndList(
            scenario.vehicleId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY, PURCHASE_AMOUNT, LISTING_DURATION, true
        );
        vm.stopPrank();

        assertEq(newListingId, 1);
        assertListingState(
            newListingId,
            scenario.revenueTokenId,
            PURCHASE_AMOUNT,
            REVENUE_TOKEN_PRICE,
            partner1,
            true,
            true
        );

        assertTokenBalance(address(marketplace), scenario.revenueTokenId, PURCHASE_AMOUNT, "Marketplace token balance mismatch");
        assertTokenBalance(partner1, scenario.revenueTokenId, REVENUE_TOKEN_SUPPLY - PURCHASE_AMOUNT, "Partner token balance mismatch");

        (,, bool isLocked,,) = treasury.getAssetCollateralInfo(scenario.vehicleId);
        assertTrue(isLocked);
    }

    function testLockCollateralAndListUnauthorizedPartner() public {
        vm.expectRevert(PartnerManager.PartnerManager__NotAuthorized.selector);
        vm.prank(unauthorized);
        marketplace.lockCollateralAndList(
            scenario.vehicleId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY, PURCHASE_AMOUNT, LISTING_DURATION, true
        );
    }

    function testLockCollateralAndListInvalidAmount() public {
        vm.expectRevert(Marketplace__InvalidAmount.selector);
        vm.prank(partner1);
        marketplace.lockCollateralAndList(
            scenario.vehicleId,
            REVENUE_TOKEN_PRICE,
            REVENUE_TOKEN_SUPPLY,
            REVENUE_TOKEN_SUPPLY + 1,
            LISTING_DURATION,
            true
        );
    }

    function testLockCollateralAndListInsufficientTokenBalance() public {
        vm.prank(partner1);
        roboshareTokens.safeTransferFrom(partner1, partner2, scenario.revenueTokenId, 600, "");

        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);

        vm.expectRevert(Marketplace__InsufficientTokenBalance.selector);
        marketplace.lockCollateralAndList(
            scenario.vehicleId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY, PURCHASE_AMOUNT, LISTING_DURATION, true
        );
        vm.stopPrank();
    }

    // Create Listing Tests

    function testCreateListingRequiresCollateral() public {
        vm.expectRevert(Marketplace__CollateralNotLocked.selector);
        vm.prank(partner1);
        marketplace.createListing(scenario.revenueTokenId, PURCHASE_AMOUNT, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
    }

    function testCreateListingInvalidTokenType() public {
        vm.expectRevert(Marketplace__InvalidTokenType.selector);
        vm.prank(partner1);
        marketplace.createListing(scenario.vehicleId, 1, REVENUE_TOKEN_PRICE, LISTING_DURATION, true);
    }

    // Purchase Listing Tests

    function testPurchaseListingBuyerPaysFee() public {
        _ensureState(SetupState.VehicleWithListing);

        uint256 purchaseAmount = 100;
        (uint256 totalPrice, uint256 protocolFee, uint256 expectedPayment) =
            marketplace.calculatePurchaseCost(scenario.listingId, purchaseAmount);

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);

        BalanceSnapshot memory beforeBalance = takeBalanceSnapshot(scenario.revenueTokenId);

        vm.expectEmit(true, true, true, true, address(marketplace));
        emit Marketplace.RevenueTokensTraded(
            scenario.revenueTokenId, partner1, buyer, purchaseAmount, scenario.listingId, totalPrice
        );

        marketplace.purchaseTokens(scenario.listingId, purchaseAmount);
        vm.stopPrank();

        BalanceSnapshot memory afterBalance = takeBalanceSnapshot(scenario.revenueTokenId);

        assertBalanceChanges(
            beforeBalance,
            afterBalance,
            int256(totalPrice), // Partner USDC change
            -int256(expectedPayment), // Buyer USDC change
            int256(protocolFee), // Treasury Fee Recipient USDC change
            0, // Treasury Contract USDC change
            0, // Partner token change (already escrowed)
            int256(purchaseAmount) // Buyer token change
        );

        Marketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        assertEq(listing.amount, PURCHASE_AMOUNT - purchaseAmount);
    }

    function testPurchaseListingSellerPaysFee() public {
        uint256 requiredCollateral = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        vm.startPrank(partner1);
        usdc.approve(address(treasury), requiredCollateral);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 newListingId = marketplace.lockCollateralAndList(
            scenario.vehicleId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY, PURCHASE_AMOUNT, LISTING_DURATION, false
        );
        vm.stopPrank();

        uint256 purchaseAmount = 100;
        (uint256 totalPrice, uint256 protocolFee, uint256 expectedPayment) =
            marketplace.calculatePurchaseCost(newListingId, purchaseAmount);
        uint256 sellerReceives = totalPrice - protocolFee;

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);

        BalanceSnapshot memory beforeBalance = takeBalanceSnapshot(scenario.revenueTokenId);

        marketplace.purchaseTokens(newListingId, purchaseAmount);
        vm.stopPrank();

        BalanceSnapshot memory afterBalance = takeBalanceSnapshot(scenario.revenueTokenId);

        assertBalanceChanges(
            beforeBalance,
            afterBalance,
            int256(sellerReceives), // Partner USDC change
            -int256(expectedPayment), // Buyer USDC change
            int256(protocolFee), // Treasury Fee Recipient USDC change
            0, // Treasury Contract USDC change
            0, // Partner token change (already escrowed)
            int256(purchaseAmount) // Buyer token change
        );
    }

    function testPurchaseListingCompletelyExhaustsListing() public {
        _ensureState(SetupState.VehicleWithListing);

        uint256 totalPrice = PURCHASE_AMOUNT * REVENUE_TOKEN_PRICE;
        uint256 protocolFee = ProtocolLib.calculateProtocolFee(totalPrice);

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), totalPrice + protocolFee);
        marketplace.purchaseTokens(scenario.listingId, PURCHASE_AMOUNT);
        vm.stopPrank();

        Marketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        assertEq(listing.amount, 0);
        assertFalse(listing.isActive);
        assertEq(roboshareTokens.balanceOf(buyer, scenario.revenueTokenId), PURCHASE_AMOUNT);
        assertTokenBalance(address(marketplace), scenario.revenueTokenId, 0, "Marketplace token balance mismatch");
    }

    function testPurchaseListingInsufficientPayment() public {
        _ensureState(SetupState.VehicleWithListing);

        uint256 purchaseAmount = 100;
        uint256 totalPrice = purchaseAmount * REVENUE_TOKEN_PRICE;
        uint256 protocolFee = ProtocolLib.calculateProtocolFee(totalPrice);
        uint256 requiredPayment = totalPrice + protocolFee;

        address poorBuyer = makeAddr("poorBuyer");
        setupInsufficientFunds(poorBuyer, requiredPayment);

        vm.startPrank(poorBuyer);
        usdc.approve(address(marketplace), requiredPayment);

        vm.expectRevert(); // ERC20: transfer amount exceeds balance
        marketplace.purchaseTokens(scenario.listingId, purchaseAmount);
        vm.stopPrank();
    }

    function testPurchaseListingExpired() public {
        _ensureState(SetupState.VehicleWithListing);

        vm.warp(block.timestamp + LISTING_DURATION + 1);

        vm.expectRevert(Marketplace__ListingExpired.selector);
        vm.prank(buyer);
        marketplace.purchaseTokens(scenario.listingId, 100);
    }

    function testPurchaseListingInvalidAmount() public {
        _ensureState(SetupState.VehicleWithListing);

        vm.expectRevert(Marketplace__InvalidAmount.selector);
        vm.prank(buyer);
        marketplace.purchaseTokens(scenario.listingId, PURCHASE_AMOUNT + 1);
    }

    // Cancel Listing Tests

    function testCancelListingSuccess() public {
        _ensureState(SetupState.VehicleWithListing);

        uint256 partnerBalanceBefore = roboshareTokens.balanceOf(partner1, scenario.revenueTokenId);

        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        Marketplace.Listing memory listing = marketplace.getListing(scenario.listingId);
        assertFalse(listing.isActive);

        assertTokenBalance(partner1, scenario.revenueTokenId, partnerBalanceBefore + PURCHASE_AMOUNT, "Partner token balance mismatch after cancellation");
        assertTokenBalance(address(marketplace), scenario.revenueTokenId, 0, "Marketplace token balance mismatch after cancellation");
    }

    function testCancelListingUnauthorized() public {
        _ensureState(SetupState.VehicleWithListing);

        vm.expectRevert(Marketplace__NotTokenOwner.selector);
        vm.prank(unauthorized);
        marketplace.cancelListing(scenario.listingId);
    }

    // View Function Tests

    function testGetVehicleListings() public {
        _ensureState(SetupState.VehicleWithListing);

        uint256[] memory activeListings = marketplace.getVehicleListings(scenario.vehicleId);
        assertEq(activeListings.length, 1);
        assertEq(activeListings[0], scenario.listingId);
    }

    function testCalculatePurchaseCost() public {
        _ensureState(SetupState.VehicleWithListing);

        uint256 purchaseAmount = 100;
        (uint256 totalCost, uint256 protocolFee, uint256 expectedPayment) =
            marketplace.calculatePurchaseCost(scenario.listingId, purchaseAmount);

        assertEq(totalCost, purchaseAmount * REVENUE_TOKEN_PRICE);
        assertEq(protocolFee, ProtocolLib.calculateProtocolFee(totalCost));
        assertEq(expectedPayment, totalCost + protocolFee);
    }

    function testIsVehicleEligibleForListing() public {
        assertFalse(marketplace.isVehicleEligibleForListing(scenario.vehicleId));

        vm.startPrank(partner1);
        usdc.approve(address(treasury), treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY));
        treasury.lockCollateral(scenario.vehicleId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        vm.stopPrank();

        assertTrue(marketplace.isVehicleEligibleForListing(scenario.vehicleId));
    }

    // Admin Function Tests

    function testSetTreasuryAddress() public {
        address newTreasury = makeAddr("newTreasury");

        vm.prank(admin);
        marketplace.setTreasuryAddress(newTreasury);

        assertEq(marketplace.treasuryAddress(), newTreasury);
    }

    // Fuzz Tests
    function testFuzzPurchaseListing(uint256 purchaseAmount) public {
        _ensureState(SetupState.VehicleWithListing);

        vm.assume(purchaseAmount > 0 && purchaseAmount <= PURCHASE_AMOUNT);

        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(scenario.listingId, purchaseAmount);

        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(scenario.listingId, purchaseAmount);
        vm.stopPrank();

        assertEq(roboshareTokens.balanceOf(buyer, scenario.revenueTokenId), purchaseAmount);
    }
}
