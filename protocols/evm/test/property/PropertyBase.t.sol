// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdInvariant } from "forge-std/StdInvariant.sol";
import { TreasuryFlowBaseTest } from "../base/TreasuryFlowBaseTest.t.sol";

abstract contract PropertyBase is StdInvariant, TreasuryFlowBaseTest {
    address internal buyer2 = makeAddr("buyer2");
    address internal outsider = makeAddr("outsider");
    address[] internal propertyActors;

    function _setUpPropertyBase(SetupState requiredState) internal {
        _ensureState(requiredState);

        if (propertyActors.length == 0) {
            propertyActors.push(admin);
            propertyActors.push(partner1);
            propertyActors.push(partner2);
            propertyActors.push(buyer);
            propertyActors.push(buyer2);
            propertyActors.push(outsider);
        }

        for (uint256 i = 0; i < propertyActors.length; i++) {
            address actor = propertyActors[i];

            // Property suites must treat tracked actors as EOAs even if a forked run
            // later maps one of these deterministic addresses to deployed code.
            vm.etch(actor, bytes(""));
            vm.deal(actor, 100 ether);
            _fundAddressWithUsdc(actor, 1_000_000 * 1e6);

            vm.startPrank(actor);
            usdc.approve(address(marketplace), type(uint256).max);
            usdc.approve(address(treasury), type(uint256).max);
            roboshareTokens.setApprovalForAll(address(marketplace), true);
            vm.stopPrank();
        }
    }

    function _propertyActorCount() internal view returns (uint256) {
        return propertyActors.length;
    }

    function _propertyActorAt(uint256 index) internal view returns (address) {
        return propertyActors[index];
    }

    function _sumTrackedBalances(uint256 tokenId) internal view returns (uint256 totalBalance) {
        for (uint256 i = 0; i < propertyActors.length; i++) {
            totalBalance += roboshareTokens.balanceOf(propertyActors[i], tokenId);
        }
    }

    function _sumPendingWithdrawals() internal view returns (uint256 totalPending) {
        for (uint256 i = 0; i < propertyActors.length; i++) {
            totalPending += treasury.pendingWithdrawals(propertyActors[i]);
        }
    }
}
