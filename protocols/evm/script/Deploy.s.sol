//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import { DeployRoboshareTokens } from "./DeployRoboshareTokens.s.sol";
import { DeployPartnerManager } from "./DeployPartnerManager.s.sol";
import { DeployVehicleRegistry } from "./DeployVehicleRegistry.s.sol";
import { DeployTreasury } from "./DeployTreasury.s.sol";

/**
 * @notice Main deployment script for Roboshare protocol contracts
 * @dev Deploys all contracts in proper dependency order
 *
 * Example: yarn deploy # runs this script(without`--file` flag)
 */
contract DeployScript is ScaffoldETHDeploy {
    function run() external {
        // Deploy contracts in dependency order
        
        // 1. Deploy base token contract (no dependencies)
        DeployRoboshareTokens deployTokens = new DeployRoboshareTokens();
        deployTokens.run();

        // 2. Deploy partner manager (no dependencies) 
        DeployPartnerManager deployPartnerManager = new DeployPartnerManager();
        deployPartnerManager.run();

        // 3. Deploy vehicle registry (depends on tokens + partner manager)
        DeployVehicleRegistry deployVehicleRegistry = new DeployVehicleRegistry();
        deployVehicleRegistry.run();

        // 4. Deploy treasury (depends on vehicle registry + partner manager)
        DeployTreasury deployTreasury = new DeployTreasury();
        deployTreasury.run();
    }
}
