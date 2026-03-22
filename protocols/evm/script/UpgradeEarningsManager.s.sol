// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { ScaffoldETHDeploy } from "./DeployHelpers.s.sol";
import { EarningsManager } from "../contracts/EarningsManager.sol";

contract UpgradeEarningsManager is ScaffoldETHDeploy {
    /**
     * @dev Upgrade EarningsManager implementation
     * Usage: yarn upgrade --contract EarningsManager --proxy-address <addr>
     */
    function run() external scaffoldEthDeployerRunner {
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        require(proxyAddress != address(0), "Proxy address cannot be zero");

        console.log("=== EarningsManager Upgrade ===");
        console.log("EarningsManager proxy:", proxyAddress);

        EarningsManager newImplementation = new EarningsManager();
        console.log("New EarningsManager implementation deployed at:", address(newImplementation));

        EarningsManager proxy = EarningsManager(proxyAddress);
        proxy.upgradeToAndCall(address(newImplementation), "");

        console.log("=== Upgrade Verification ===");
        console.log("New implementation address:", address(newImplementation));
        console.log("EarningsManager upgrade completed successfully!");
        console.log("");
        console.log("Note: Run any necessary admin functions for this upgrade manually or via script.");
    }

    function help() external pure {
        console.log("Usage: yarn upgrade --contract EarningsManager --proxy-address <addr>");
        console.log("Post-upgrade: Configure via admin functions");
    }
}
