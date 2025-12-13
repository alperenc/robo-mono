// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ScaffoldETHDeploy } from "./DeployHelpers.s.sol";
import { PartnerManager } from "../contracts/PartnerManager.sol";

contract DeployPartnerManager is ScaffoldETHDeploy {
    /**
     * @dev Deploy PartnerManager - no external dependencies required
     * Usage: yarn deploy --contract PartnerManager --network <network>
     */
    function run() external scaffoldEthDeployerRunner returns (address) {
        console.log("Deploying PartnerManager with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);

        // Deploy implementation contract
        PartnerManager partnerImplementation = new PartnerManager();
        console.log("PartnerManager implementation deployed at:", address(partnerImplementation));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSignature("initialize(address)", deployer);

        // Deploy proxy contract
        ERC1967Proxy proxy = new ERC1967Proxy(address(partnerImplementation), initData);
        console.log("PartnerManager proxy deployed at:", address(proxy));

        // Wrap proxy in interface
        PartnerManager partnerManager = PartnerManager(address(proxy));

        // Verify initialization
        console.log(
            "Admin has DEFAULT_ADMIN_ROLE:", partnerManager.hasRole(partnerManager.DEFAULT_ADMIN_ROLE(), deployer)
        );
        console.log("Admin has PARTNER_ADMIN_ROLE:", partnerManager.hasRole(keccak256("PARTNER_ADMIN_ROLE"), deployer));
        console.log("Admin has UPGRADER_ROLE:", partnerManager.hasRole(keccak256("UPGRADER_ROLE"), deployer));
        console.log("Initial partner count:", partnerManager.getPartnerCount());

        // Log deployment summary
        console.log("=== Deployment Summary ===");
        console.log("Implementation:", address(partnerImplementation));
        console.log("Proxy (main contract):", address(proxy));
        console.log("Deployer/Admin:", deployer);
        console.log("==========================");

        return address(proxy);
    }
}
