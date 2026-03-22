// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { AssetLib, CollateralLib } from "../../contracts/Libraries.sol";
import { EarningsManager } from "../../contracts/EarningsManager.sol";
import { Treasury } from "../../contracts/Treasury.sol";
import { Marketplace } from "../../contracts/Marketplace.sol";
import { RoboshareTokens } from "../../contracts/RoboshareTokens.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PropertyBase } from "./PropertyBase.t.sol";

contract TreasuryAccountingHandler is Test {
    Treasury internal treasury;
    EarningsManager internal earningsManager;
    Marketplace internal marketplace;
    RoboshareTokens internal roboshareTokens;
    IERC20 internal usdc;
    uint256 internal assetId;
    uint256 internal revenueTokenId;
    address internal partner;
    address[] internal actors;

    constructor(
        Treasury _treasury,
        EarningsManager _earningsManager,
        Marketplace _marketplace,
        RoboshareTokens _roboshareTokens,
        IERC20 _usdc,
        uint256 _assetId,
        uint256 _revenueTokenId,
        address _partner,
        address[] memory _actors
    ) {
        treasury = _treasury;
        earningsManager = _earningsManager;
        marketplace = _marketplace;
        roboshareTokens = _roboshareTokens;
        usdc = _usdc;
        assetId = _assetId;
        revenueTokenId = _revenueTokenId;
        partner = _partner;
        actors = _actors;
    }

    // Separate state transitions by at least one second so earnings periods and
    // token acquisitions do not collapse into the same timestamp in property runs.
    function _advanceStepTime() internal {
        vm.warp(block.timestamp + 1);
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

        _advanceStepTime();
        vm.prank(buyer);
        marketplace.buyFromPrimaryPool(revenueTokenId, amount);
    }

    function enableProceeds() external {
        (, uint256 baseCollateral,,,,,,,,,,,) = treasury.assetCollateral(assetId);
        if (baseCollateral == 0) return;

        _advanceStepTime();
        vm.prank(partner);
        try treasury.enableProceeds(assetId) { } catch { }
    }

    function distributeEarnings(uint256 totalRevenueSeed, bool tryAutoRelease) external {
        if (marketplace.router().getAssetStatus(assetId) != AssetLib.AssetStatus.Earning) return;
        if (roboshareTokens.balanceOf(partner, revenueTokenId) >= roboshareTokens.getRevenueTokenSupply(revenueTokenId))
        {
            return;
        }

        uint256 totalRevenue = bound(totalRevenueSeed, 1_000 * 1e6, 100_000 * 1e6);
        if (usdc.balanceOf(partner) < totalRevenue) return;

        _advanceStepTime();
        vm.prank(partner);
        usdc.approve(address(earningsManager), totalRevenue);
        vm.prank(partner);
        earningsManager.distributeEarnings(assetId, totalRevenue, tryAutoRelease);
    }

    function claimEarnings(uint256 actorSeed) external {
        address actor = actors[actorSeed % actors.length];
        if (earningsManager.previewClaimEarnings(assetId, actor) == 0) return;

        _advanceStepTime();
        vm.prank(actor);
        earningsManager.claimEarnings(assetId);
    }

    function processWithdrawal(uint256 actorSeed) external {
        address actor = actors[actorSeed % actors.length];
        if (treasury.pendingWithdrawals(actor) == 0) return;

        vm.prank(actor);
        treasury.processWithdrawal();
    }

    function warpForward(uint256 secondsSeed) external {
        uint256 delta = bound(secondsSeed, 1 days, 120 days);
        vm.warp(block.timestamp + delta);
    }

    function releasePartialCollateral() external {
        if (treasury.previewCollateralRelease(assetId, false) == 0) return;

        _advanceStepTime();
        vm.prank(partner);
        treasury.releasePartialCollateral(assetId);
    }
}

contract TreasuryAccountingInvariantTest is PropertyBase {
    TreasuryAccountingHandler internal handler;
    address[] internal handlerActors;

    function setUp() public {
        _setUpPropertyBase(SetupState.PurchasedFromPrimaryPool);

        for (uint256 i = 0; i < _propertyActorCount(); i++) {
            handlerActors.push(_propertyActorAt(i));
        }

        handler = new TreasuryAccountingHandler(
            treasury,
            earningsManager,
            marketplace,
            roboshareTokens,
            usdc,
            scenario.assetId,
            scenario.revenueTokenId,
            partner1,
            handlerActors
        );
        targetContract(address(handler));
    }

    function invariantCollateralShapeRemainsConsistent() public view {
        CollateralLib.CollateralInfo memory info = _getCollateralInfo(scenario.assetId);
        assertEq(
            info.totalCollateral,
            info.baseCollateral + info.earningsBuffer + info.protocolBuffer,
            "collateral total != component sum"
        );
    }

    function invariantTotalCollateralTracksSingleAsset() public view {
        CollateralLib.CollateralInfo memory info = _getCollateralInfo(scenario.assetId);
        assertEq(treasury.totalCollateralDeposited(), info.totalCollateral, "treasury total collateral drifted");
    }

    function invariantPendingWithdrawalsCoveredByTreasuryBalance() public view {
        assertLe(
            _sumPendingWithdrawals(), usdc.balanceOf(address(treasury)), "pending withdrawals exceed treasury cash"
        );
    }
}
