// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RegistryRouter } from "../../contracts/RegistryRouter.sol";
import { EarningsManager } from "../../contracts/EarningsManager.sol";
import { Treasury } from "../../contracts/Treasury.sol";
import { Marketplace } from "../../contracts/Marketplace.sol";
import { PropertyBase } from "./PropertyBase.t.sol";

contract ProtocolReferencesHandler {
    RegistryRouter internal router;
    EarningsManager internal earningsManager;
    Treasury internal treasury;
    Marketplace internal marketplace;

    constructor(
        RegistryRouter _router,
        EarningsManager _earningsManager,
        Treasury _treasury,
        Marketplace _marketplace
    ) {
        router = _router;
        earningsManager = _earningsManager;
        treasury = _treasury;
        marketplace = _marketplace;
    }

    function unauthorizedRouterSetEarningsManager(address target) external {
        try router.setEarningsManager(target) { } catch { }
    }

    function unauthorizedRouterUpdateRoboshareTokens(address target) external {
        try router.updateRoboshareTokens(target) { } catch { }
    }

    function unauthorizedRouterUpdatePartnerManager(address target) external {
        try router.updatePartnerManager(target) { } catch { }
    }

    function unauthorizedTreasuryUpdatePartnerManager(address target) external {
        try treasury.updatePartnerManager(target) { } catch { }
    }

    function unauthorizedTreasuryUpdateUSDC(address token) external {
        try treasury.updateUSDC(token) { } catch { }
    }

    function unauthorizedTreasuryUpdateRoboshareTokens(address target) external {
        try treasury.updateRoboshareTokens(target) { } catch { }
    }

    function unauthorizedTreasuryUpdateRouter(address target) external {
        try treasury.updateRouter(target) { } catch { }
    }

    function unauthorizedTreasurySetEarningsManager(address target) external {
        try treasury.setEarningsManager(target) { } catch { }
    }

    function unauthorizedMarketplaceUpdatePartnerManager(address target) external {
        try marketplace.updatePartnerManager(target) { } catch { }
    }

    function unauthorizedMarketplaceUpdateUSDC(address token) external {
        try marketplace.updateUSDC(token) { } catch { }
    }

    function unauthorizedMarketplaceUpdateRoboshareTokens(address target) external {
        try marketplace.updateRoboshareTokens(target) { } catch { }
    }

    function unauthorizedMarketplaceUpdateRouter(address target) external {
        try marketplace.updateRouter(target) { } catch { }
    }

    function unauthorizedMarketplaceUpdateTreasury(address target) external {
        try marketplace.updateTreasury(target) { } catch { }
    }

    function unauthorizedEarningsManagerUpdateTreasury(address target) external {
        try earningsManager.updateTreasury(target) { } catch { }
    }

    function unauthorizedEarningsManagerUpdateRouter(address target) external {
        try earningsManager.updateRouter(target) { } catch { }
    }

    function unauthorizedEarningsManagerUpdatePartnerManager(address target) external {
        try earningsManager.updatePartnerManager(target) { } catch { }
    }

    function unauthorizedEarningsManagerUpdateRoboshareTokens(address target) external {
        try earningsManager.updateRoboshareTokens(target) { } catch { }
    }

    function unauthorizedEarningsManagerUpdateUSDC(address token) external {
        try earningsManager.updateUSDC(token) { } catch { }
    }
}

contract ProtocolReferencesInvariantTest is PropertyBase {
    ProtocolReferencesHandler internal handler;

    function setUp() public {
        _setUpPropertyBase(SetupState.ContractsDeployed);

        handler = new ProtocolReferencesHandler(router, earningsManager, treasury, marketplace);
        targetContract(address(handler));
    }

    function invariantSharedUsdcReference() public view {
        assertEq(address(treasury.usdc()), address(marketplace.usdc()), "treasury.usdc != marketplace.usdc");
        assertEq(address(treasury.usdc()), address(earningsManager.usdc()), "treasury.usdc != earningsManager.usdc");
    }

    function invariantSharedTokenReference() public view {
        assertEq(
            address(treasury.roboshareTokens()),
            address(marketplace.roboshareTokens()),
            "treasury.tokens != marketplace.tokens"
        );
        assertEq(
            address(treasury.roboshareTokens()),
            address(earningsManager.roboshareTokens()),
            "treasury.tokens != earningsManager.tokens"
        );
        assertEq(
            address(treasury.roboshareTokens()), address(router.roboshareTokens()), "treasury.tokens != router.tokens"
        );
    }

    function invariantSharedRouterReference() public view {
        assertEq(address(treasury.router()), address(marketplace.router()), "treasury.router != marketplace.router");
        assertEq(
            address(treasury.router()), address(earningsManager.router()), "treasury.router != earningsManager.router"
        );
    }

    function invariantSharedPartnerManagerReference() public view {
        assertEq(
            address(treasury.partnerManager()), address(marketplace.partnerManager()), "treasury.pm != marketplace.pm"
        );
        assertEq(
            address(treasury.partnerManager()),
            address(earningsManager.partnerManager()),
            "treasury.pm != earningsManager.pm"
        );
        assertEq(address(treasury.partnerManager()), address(router.partnerManager()), "treasury.pm != router.pm");
    }

    function invariantSharedTreasuryReference() public view {
        assertEq(address(marketplace.treasury()), address(treasury), "marketplace.treasury != treasury");
        assertEq(address(earningsManager.treasury()), address(treasury), "earningsManager.treasury != treasury");
        assertEq(address(router.treasury()), address(treasury), "router.treasury != treasury");
    }

    function invariantSharedEarningsManagerReference() public view {
        assertEq(address(treasury.earningsManager()), address(earningsManager), "treasury.em != earningsManager");
        assertEq(address(router.earningsManager()), address(earningsManager), "router.em != earningsManager");
    }
}
