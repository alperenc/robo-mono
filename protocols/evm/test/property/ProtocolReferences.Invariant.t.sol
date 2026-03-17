// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Treasury } from "../../contracts/Treasury.sol";
import { Marketplace } from "../../contracts/Marketplace.sol";
import { PropertyBase } from "./PropertyBase.t.sol";

contract ProtocolReferencesHandler {
    Treasury internal treasury;
    Marketplace internal marketplace;

    constructor(Treasury _treasury, Marketplace _marketplace) {
        treasury = _treasury;
        marketplace = _marketplace;
    }

    function unauthorizedTreasuryUpdateUSDC(address token) external {
        try treasury.updateUSDC(token) { } catch { }
    }

    function unauthorizedMarketplaceUpdateUSDC(address token) external {
        try marketplace.updateUSDC(token) { } catch { }
    }
}

contract ProtocolReferencesInvariantTest is PropertyBase {
    ProtocolReferencesHandler internal handler;

    function setUp() public {
        _setUpPropertyBase(SetupState.ContractsDeployed);

        handler = new ProtocolReferencesHandler(treasury, marketplace);
        targetContract(address(handler));
    }

    function invariantSharedUsdcReference() public view {
        assertEq(address(treasury.usdc()), address(marketplace.usdc()), "treasury.usdc != marketplace.usdc");
    }

    function invariantSharedTokenReference() public view {
        assertEq(
            address(treasury.roboshareTokens()),
            address(marketplace.roboshareTokens()),
            "treasury.tokens != marketplace.tokens"
        );
    }

    function invariantSharedRouterReference() public view {
        assertEq(address(treasury.router()), address(marketplace.router()), "treasury.router != marketplace.router");
    }

    function invariantSharedPartnerManagerReference() public view {
        assertEq(
            address(treasury.partnerManager()), address(marketplace.partnerManager()), "treasury.pm != marketplace.pm"
        );
    }
}
