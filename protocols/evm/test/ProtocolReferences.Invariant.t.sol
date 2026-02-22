// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StdInvariant } from "forge-std/StdInvariant.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { Treasury } from "../contracts/Treasury.sol";
import { Marketplace } from "../contracts/Marketplace.sol";

contract ProtocolReferencesHandler {
    Treasury internal treasury;
    Marketplace internal marketplace;

    constructor(Treasury _treasury, Marketplace _marketplace) {
        treasury = _treasury;
        marketplace = _marketplace;
    }

    function readReferences() external view returns (address, address) {
        return (address(treasury.usdc()), address(marketplace.usdc()));
    }

    function unauthorizedTreasuryUpdateUSDC(address token) external {
        try treasury.updateUSDC(token) { } catch { }
    }

    function unauthorizedMarketplaceUpdateUSDC(address token) external {
        try marketplace.updateUSDC(token) { } catch { }
    }
}

contract ProtocolReferencesInvariantTest is StdInvariant, BaseTest {
    ProtocolReferencesHandler internal handler;

    function setUp() public {
        _ensureState(SetupState.ContractsDeployed);

        handler = new ProtocolReferencesHandler(treasury, marketplace);
        targetContract(address(handler));
    }

    function invariantTreasuryAndMarketplaceShareUSDCReference() public view {
        assertEq(address(treasury.usdc()), address(marketplace.usdc()), "treasury.usdc != marketplace.usdc");
    }
}
