// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ScaffoldETHDeploy } from "./DeployHelpers.s.sol";
import { RegistryRouter } from "../contracts/RegistryRouter.sol";

contract DeployRegistryRouter is ScaffoldETHDeploy {
    /**
     * @dev Deploy RegistryRouter with dependency address
     * Usage: yarn deploy --contract RegistryRouter --network <network> --args <roboshareTokensAddress>
     */
    function run(address roboshareTokensAddress) external scaffoldEthDeployerRunner returns (address) {
        console.log("Deploying RegistryRouter with deployer:", deployer);
        console.log("Dependencies:");
        console.log("  - RoboshareTokens:", roboshareTokensAddress);

        require(roboshareTokensAddress != address(0), "RoboshareTokens address cannot be zero");

        // Deploy implementation
        RegistryRouter routerImplementation = new RegistryRouter();
        console.log("RegistryRouter implementation deployed at:", address(routerImplementation));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSignature("initialize(address,address)", deployer, roboshareTokensAddress);

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(routerImplementation), initData);
        console.log("RegistryRouter proxy deployed at:", address(proxy));

        // Wrap proxy in interface
        RegistryRouter router = RegistryRouter(address(proxy));

        // Verify initialization
        console.log("Admin has DEFAULT_ADMIN_ROLE:", router.hasRole(router.DEFAULT_ADMIN_ROLE(), deployer));
        console.log("Admin has REGISTRY_ADMIN_ROLE:", router.hasRole(keccak256("REGISTRY_ADMIN_ROLE"), deployer));
        console.log("RoboshareTokens reference:", address(router.roboshareTokens()));

        // Log deployment summary
        console.log("=== Deployment Summary ===");
        console.log("Implementation:", address(routerImplementation));
        console.log("Proxy (main contract):", address(proxy));
        console.log("Deployer/Admin:", deployer);
        console.log("==========================");

        return address(proxy);
    }

    /**
     * @dev Default run function - reverts with usage info
     */
    function run() external pure returns (address) {
        revert(
            "RegistryRouter deployment requires dependency addresses. "
            "Use: yarn deploy --contract RegistryRouter --network <network> --args <roboshareTokensAddress>"
        );
    }
}
