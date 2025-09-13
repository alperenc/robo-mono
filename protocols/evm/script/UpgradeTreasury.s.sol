// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import "../contracts/Treasury.sol";

contract UpgradeTreasury is ScaffoldETHDeploy {
    /**
     * @dev Upgrade Treasury implementation with delegation architecture
     * Usage: yarn upgrade --contract Treasury --proxy-address <addr> --tokens-address <addr> --authorized-contract <addr>
     */
    function run() external ScaffoldEthDeployerRunner {
        // Get addresses from environment variables (set by parseArgs.js)
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        address tokensAddress = vm.envAddress("TOKENS_ADDRESS");
        address authorizedContractAddress = vm.envAddress("AUTHORIZED_CONTRACT_ADDRESS");
        
        require(proxyAddress != address(0), "Proxy address cannot be zero");
        require(tokensAddress != address(0), "Tokens address cannot be zero");
        require(authorizedContractAddress != address(0), "Authorized contract address cannot be zero");
        
        console.log("=== Treasury Upgrade ===");
        console.log("Treasury proxy:", proxyAddress);
        console.log("Tokens address:", tokensAddress);
        console.log("Authorized contract:", authorizedContractAddress);
        
        // Deploy new Treasury implementation
        Treasury newImplementation = new Treasury();
        console.log("New Treasury implementation deployed at:", address(newImplementation));
        
        // Get the proxy as Treasury
        Treasury proxy = Treasury(proxyAddress);
        
        // Upgrade the proxy to the new implementation (no reinitializer needed)
        proxy.upgradeToAndCall(address(newImplementation), "");
        
        // Set tokens reference via admin function
        proxy.setRoboshareTokens(tokensAddress);
        console.log("Tokens reference set");
        
        // Grant authorized contract the required role
        proxy.grantRole(proxy.AUTHORIZED_CONTRACT_ROLE(), authorizedContractAddress);
        console.log("Authorized contract granted AUTHORIZED_CONTRACT_ROLE");
        
        // Verify the upgrade
        console.log("=== Upgrade Verification ===");
        console.log("New implementation address:", address(newImplementation));
        console.log("Tokens reference:", address(proxy.roboshareTokens()));
        console.log("Authorized contract has role:", proxy.hasRole(proxy.AUTHORIZED_CONTRACT_ROLE(), authorizedContractAddress));
        
        console.log("Treasury upgrade completed successfully!");
    }
    
    function help() external pure {
        console.log("Usage: yarn upgrade --contract Treasury --proxy-address <addr> --tokens-address <addr> --authorized-contract <addr>");
    }
}