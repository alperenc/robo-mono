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
    function run() external ScaffoldEthDeployerRunner {
        // Deploy contracts in dependency order

        // 1. Deploy base token contract (no dependencies)
        DeployRoboshareTokens deployTokens = new DeployRoboshareTokens();
        address roboshareTokensProxy = deployTokens.run(deployer);

        // 2. Deploy partner manager (no dependencies)
        DeployPartnerManager deployPartnerManager = new DeployPartnerManager();
        address partnerManagerProxy = deployPartnerManager.run(deployer);

        // 3. Deploy vehicle registry (depends on tokens + partner manager)
        DeployVehicleRegistry deployVehicleRegistry = new DeployVehicleRegistry();
        address vehicleRegistryProxy = deployVehicleRegistry.run(roboshareTokensProxy, partnerManagerProxy, deployer);

        // 4. Deploy treasury (depends on vehicle registry + partner manager)
        // For local testing, we'll use a mock USDC address (zero address will be caught by validation)
        // In production, this should be the actual USDC contract address
        address usdcAddress = address(0x1234567890123456789012345678901234567890); // Mock USDC for local testing

        DeployTreasury deployTreasury = new DeployTreasury();
        deployTreasury.run(partnerManagerProxy, vehicleRegistryProxy, usdcAddress, deployer);
    }
}
