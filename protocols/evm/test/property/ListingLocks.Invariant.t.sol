// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Marketplace } from "../../contracts/Marketplace.sol";
import { RoboshareTokens } from "../../contracts/RoboshareTokens.sol";
import { PropertyBase } from "./PropertyBase.t.sol";

contract ListingLocksHandler is Test {
    Marketplace internal marketplace;
    RoboshareTokens internal roboshareTokens;
    IERC20 internal usdc;
    uint256 internal revenueTokenId;
    address[] internal actors;
    uint256[] internal trackedListingIds;

    constructor(
        Marketplace _marketplace,
        RoboshareTokens _roboshareTokens,
        IERC20 _usdc,
        uint256 _revenueTokenId,
        address[] memory _actors
    ) {
        marketplace = _marketplace;
        roboshareTokens = _roboshareTokens;
        usdc = _usdc;
        revenueTokenId = _revenueTokenId;
        actors = _actors;
    }

    function buyFromPrimaryPool(uint256 actorSeed, uint256 amountSeed) external {
        uint256 currentSupply = roboshareTokens.getRevenueTokenSupply(revenueTokenId);
        uint256 maxSupply = roboshareTokens.getRevenueTokenMaxSupply(revenueTokenId);
        if (currentSupply >= maxSupply) return;

        address buyer = actors[actorSeed % actors.length];
        uint256 remaining = maxSupply - currentSupply;
        uint256 amount = bound(amountSeed, 1, remaining);
        (,, uint256 totalCost) = marketplace.previewPrimaryPurchase(revenueTokenId, amount);
        if (usdc.balanceOf(buyer) < totalCost) return;

        vm.prank(buyer);
        marketplace.buyFromPrimaryPool(revenueTokenId, amount);
    }

    function createListing(uint256 actorSeed, uint256 amountSeed, uint256 durationSeed, bool buyerPaysFee) external {
        address seller = actors[actorSeed % actors.length];
        uint256 balance = roboshareTokens.balanceOf(seller, revenueTokenId);
        uint256 locked = roboshareTokens.getLockedAmount(seller, revenueTokenId);
        if (balance <= locked) return;

        uint256 available = balance - locked;
        uint256 amount = bound(amountSeed, 1, available);
        uint256 duration = bound(durationSeed, 1 days, 90 days);

        vm.prank(seller);
        try marketplace.createListing(
            revenueTokenId, amount, roboshareTokens.getTokenPrice(revenueTokenId), duration, buyerPaysFee
        ) returns (
            uint256 listingId
        ) {
            trackedListingIds.push(listingId);
        } catch { }
    }

    function buyFromSecondaryListing(uint256 listingSeed, uint256 buyerSeed, uint256 amountSeed) external {
        if (trackedListingIds.length == 0) return;

        uint256 listingId = trackedListingIds[listingSeed % trackedListingIds.length];
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        if (!listing.isActive || listing.amount == 0) return;

        address buyer = actors[buyerSeed % actors.length];
        if (buyer == listing.seller) {
            buyer = actors[(buyerSeed + 1) % actors.length];
            if (buyer == listing.seller) return;
        }

        uint256 amount = bound(amountSeed, 1, listing.amount);
        (,, uint256 totalCost) = marketplace.previewSecondaryPurchase(listingId, amount);
        if (usdc.balanceOf(buyer) < totalCost) return;

        vm.prank(buyer);
        marketplace.buyFromSecondaryListing(listingId, amount);
    }

    function endListing(uint256 listingSeed) external {
        if (trackedListingIds.length == 0) return;

        uint256 listingId = trackedListingIds[listingSeed % trackedListingIds.length];
        Marketplace.Listing memory listing = marketplace.getListing(listingId);
        if (!listing.isActive || listing.amount == 0) return;

        vm.prank(listing.seller);
        marketplace.endListing(listingId);
    }

    function transferUnlockedTokens(uint256 fromSeed, uint256 toSeed, uint256 amountSeed) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        if (from == to) return;

        uint256 balance = roboshareTokens.balanceOf(from, revenueTokenId);
        uint256 locked = roboshareTokens.getLockedAmount(from, revenueTokenId);
        if (balance <= locked) return;

        uint256 unlocked = balance - locked;
        uint256 amount = bound(amountSeed, 1, unlocked);

        vm.prank(from);
        roboshareTokens.safeTransferFrom(from, to, revenueTokenId, amount, "");
    }

    function trackedListingCount() external view returns (uint256) {
        return trackedListingIds.length;
    }

    function trackedListingIdAt(uint256 index) external view returns (uint256) {
        return trackedListingIds[index];
    }
}

contract ListingLocksInvariantTest is PropertyBase {
    ListingLocksHandler internal handler;
    address[] internal handlerActors;

    function setUp() public {
        _setUpPropertyBase(SetupState.PrimaryPoolCreated);

        for (uint256 i = 0; i < _propertyActorCount(); i++) {
            address actor = _propertyActorAt(i);
            if (actor != admin) {
                handlerActors.push(actor);
            }
        }

        handler = new ListingLocksHandler(marketplace, roboshareTokens, usdc, scenario.revenueTokenId, handlerActors);
        targetContract(address(handler));
    }

    function invariantLockedAmountsNeverExceedBalances() public view {
        for (uint256 i = 0; i < handlerActors.length; i++) {
            uint256 balance = roboshareTokens.balanceOf(handlerActors[i], scenario.revenueTokenId);
            uint256 locked = roboshareTokens.getLockedAmount(handlerActors[i], scenario.revenueTokenId);
            assertLe(locked, balance, "locked amount exceeds balance");
        }
    }

    function invariantTrackedActorBalancesMatchSupply() public view {
        assertEq(
            _sumTrackedBalances(scenario.revenueTokenId),
            roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId),
            "tracked balances != token supply"
        );
    }

    function invariantSellerLocksMatchActiveListings() public view {
        for (uint256 i = 0; i < handlerActors.length; i++) {
            address seller = handlerActors[i];
            uint256 expectedLocked;

            uint256 listingCount = handler.trackedListingCount();
            for (uint256 j = 0; j < listingCount; j++) {
                Marketplace.Listing memory listing = marketplace.getListing(handler.trackedListingIdAt(j));
                if (listing.seller == seller && listing.tokenId == scenario.revenueTokenId && listing.isActive) {
                    expectedLocked += listing.amount;
                }
            }

            assertEq(
                roboshareTokens.getLockedAmount(seller, scenario.revenueTokenId),
                expectedLocked,
                "locked amount != active listing sum"
            );
        }
    }
}
