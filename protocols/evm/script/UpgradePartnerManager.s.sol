// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { ScaffoldETHDeploy } from "./DeployHelpers.s.sol";
import { PartnerManager } from "../contracts/PartnerManager.sol";

contract UpgradePartnerManager is ScaffoldETHDeploy {
    /**
     * @dev Upgrade PartnerManager implementation
     * Usage: yarn upgrade --contract PartnerManager --proxy-address <addr>
     */
    function run() external scaffoldEthDeployerRunner {
        // Get proxy address from environment variable (set by parseArgs.js)
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        require(proxyAddress != address(0), "Proxy address cannot be zero");

        console.log("=== PartnerManager Upgrade ===");
        console.log("PartnerManager proxy:", proxyAddress);

        // Deploy new PartnerManager implementation
        PartnerManager newImplementation = new PartnerManager();
        console.log("New PartnerManager implementation deployed at:", address(newImplementation));

        // Get the proxy as PartnerManager
        PartnerManager proxy = PartnerManager(proxyAddress);

        // Upgrade the proxy to the new implementation (no reinitializer needed)
        proxy.upgradeToAndCall(address(newImplementation), "");

        // Verify the upgrade
        console.log("=== Upgrade Verification ===");
        console.log("New implementation address:", address(newImplementation));
        console.log("PartnerManager upgrade completed successfully!");
        console.log("");
        console.log("Note: Run any necessary admin functions for this upgrade manually or via script.");
    }

    function help() external pure {
        console.log("Usage: yarn upgrade --contract PartnerManager --proxy-address <addr>");
        console.log("Post-upgrade: Configure via admin functions");
    }
}
