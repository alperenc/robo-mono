// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ScaffoldETHDeploy } from "./DeployHelpers.s.sol";
import { VehicleRegistry } from "../contracts/VehicleRegistry.sol";

contract DeployVehicleRegistry is ScaffoldETHDeploy {
    /**
     * @dev Deploy VehicleRegistry with dependency addresses
     * Usage: yarn deploy --contract VehicleRegistry --network <network> --args <roboshareTokens>,<partnerManager>,<router>
     */
    function run(address roboshareTokensAddress, address partnerManagerAddress, address routerAddress)
        external
        scaffoldEthDeployerRunner
        returns (address)
    {
        console.log("Deploying VehicleRegistry with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("Dependencies:");
        console.log("  - RoboshareTokens:", roboshareTokensAddress);
        console.log("  - PartnerManager:", partnerManagerAddress);
        console.log("  - Router:", routerAddress);

        // Validate dependency addresses
        require(roboshareTokensAddress != address(0), "RoboshareTokens address cannot be zero");
        require(partnerManagerAddress != address(0), "PartnerManager address cannot be zero");
        require(routerAddress != address(0), "Router address cannot be zero");

        // Deploy implementation contract
        VehicleRegistry vehicleImplementation = new VehicleRegistry();
        console.log("VehicleRegistry implementation deployed at:", address(vehicleImplementation));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address,address)",
            deployer,
            roboshareTokensAddress,
            partnerManagerAddress,
            routerAddress
        );

        // Deploy proxy contract
        ERC1967Proxy proxy = new ERC1967Proxy(address(vehicleImplementation), initData);
        console.log("VehicleRegistry proxy deployed at:", address(proxy));

        // Wrap proxy in interface
        VehicleRegistry vehicleRegistry = VehicleRegistry(address(proxy));

        // Verify initialization
        console.log(
            "Admin has DEFAULT_ADMIN_ROLE:", vehicleRegistry.hasRole(vehicleRegistry.DEFAULT_ADMIN_ROLE(), deployer)
        );
        console.log("Admin has UPGRADER_ROLE:", vehicleRegistry.hasRole(keccak256("UPGRADER_ROLE"), deployer));
        console.log("RoboshareTokens reference:", address(vehicleRegistry.roboshareTokens()));
        console.log("PartnerManager reference:", address(vehicleRegistry.partnerManager()));
        console.log("Router reference:", address(vehicleRegistry.router()));

        // Log deployment summary
        console.log("=== Deployment Summary ===");
        console.log("Implementation:", address(vehicleImplementation));
        console.log("Proxy (main contract):", address(proxy));
        console.log("Deployer/Admin:", deployer);
        console.log("Dependencies verified and connected");
        console.log("==========================");

        return address(proxy);
    }

    /**
     * @dev Default run function - reverts with usage info
     */
    function run() external pure returns (address) {
        revert(
            "VehicleRegistry deployment requires dependency addresses. "
            "Use: yarn deploy --contract VehicleRegistry --network <network> --args <roboshareTokens>,<partnerManager>,<router>"
        );
    }
}
