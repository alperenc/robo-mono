// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import "../contracts/VehicleRegistry.sol";

contract UpgradeVehicleRegistry is ScaffoldETHDeploy {
    /**
     * @dev Upgrade VehicleRegistry implementation
     * Usage: forge script UpgradeVehicleRegistry --sig "run(address)" $PROXY_ADDRESS
     */
    function run() external ScaffoldEthDeployerRunner {
        // Get proxy address from environment variable (set by parseArgs.js)
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        require(proxyAddress != address(0), "Proxy address cannot be zero");
        
        console.log("Upgrading VehicleRegistry proxy at:", proxyAddress);
        
        // Deploy new implementation
        // Note: Implementation is intentionally left uninitialized
        // The proxy retains all existing storage (partnerManager, roboshareTokens, vehicles, etc.)
        VehicleRegistry newImplementation = new VehicleRegistry();
        console.log("New VehicleRegistry implementation deployed at:", address(newImplementation));
        
        // Get the proxy as VehicleRegistry to call upgradeToAndCall
        VehicleRegistry proxy = VehicleRegistry(proxyAddress);
        
        // Upgrade the proxy to the new implementation
        proxy.upgradeToAndCall(address(newImplementation), "");
        
        // Verify the upgrade
        console.log("=== Upgrade Verification ===");
        console.log("Proxy address:", proxyAddress);
        console.log("New implementation address:", address(newImplementation));
        console.log("Current token counter:", proxy.getCurrentTokenId());
        
        console.log("Upgrade completed successfully!");
    }
    
    function help() external pure {
        console.log(
            "Use: forge script UpgradeVehicleRegistry --sig 'run(address)' $PROXY_ADDRESS"
        );
    }
}