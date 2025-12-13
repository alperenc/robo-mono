// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { ScaffoldETHDeploy } from "./DeployHelpers.s.sol";
import { Treasury } from "../contracts/Treasury.sol";

contract UpgradeTreasury is ScaffoldETHDeploy {
    /**
     * @dev Upgrade Treasury implementation with delegation architecture
     * Usage: yarn upgrade --contract Treasury --proxy-address <addr>
     */
    function run() external scaffoldEthDeployerRunner {
        // Get proxy address from environment variable (set by parseArgs.js)
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        require(proxyAddress != address(0), "Proxy address cannot be zero");

        console.log("=== Treasury Upgrade ===");
        console.log("Treasury proxy:", proxyAddress);

        // Deploy new Treasury implementation
        Treasury newImplementation = new Treasury();
        console.log("New Treasury implementation deployed at:", address(newImplementation));

        // Get the proxy as Treasury
        Treasury proxy = Treasury(proxyAddress);

        // Upgrade the proxy to the new implementation (no reinitializer needed)
        proxy.upgradeToAndCall(address(newImplementation), "");

        // Verify the upgrade
        console.log("=== Upgrade Verification ===");
        console.log("New implementation address:", address(newImplementation));
        console.log("Treasury upgrade completed successfully!");
        console.log("");
        console.log("Note: Run any necessary admin functions for this upgrade manually or via script.");
    }

    function help() external pure {
        console.log("Usage: yarn upgrade --contract Treasury --proxy-address <addr>");
        console.log("Post-upgrade: Configure via admin functions");
    }
}
