// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import "../contracts/RegistryRouter.sol";

contract UpgradeRegistryRouter is ScaffoldETHDeploy {
    /**
     * @dev Upgrade RegistryRouter implementation
     * Usage: yarn upgrade --contract RegistryRouter --proxy-address <addr>
     */
    function run() external ScaffoldEthDeployerRunner {
        // Get proxy address from environment variable (set by parseArgs.js)
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        require(proxyAddress != address(0), "Proxy address cannot be zero");

        console.log("=== RegistryRouter Upgrade ===");
        console.log("RegistryRouter proxy:", proxyAddress);

        // Deploy new RegistryRouter implementation
        RegistryRouter newImplementation = new RegistryRouter();
        console.log("New RegistryRouter implementation deployed at:", address(newImplementation));

        // Get the proxy as RegistryRouter
        RegistryRouter proxy = RegistryRouter(proxyAddress);

        // Upgrade the proxy to the new implementation (no reinitializer needed)
        proxy.upgradeToAndCall(address(newImplementation), "");

        // Verify the upgrade
        console.log("=== Upgrade Verification ===");
        console.log("New implementation address:", address(newImplementation));
        console.log("RegistryRouter upgrade completed successfully!");
        console.log("");
        console.log("Note: Run any necessary admin functions for this upgrade manually or via script.");
    }

    function help() external pure {
        console.log("Usage: yarn upgrade --contract RegistryRouter --proxy-address <addr>");
        console.log("Post-upgrade: Configure via admin functions");
    }
}
