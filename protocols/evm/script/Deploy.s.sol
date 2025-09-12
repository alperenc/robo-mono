//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import { DeployRoboshareTokens } from "./DeployRoboshareTokens.s.sol";
import { DeployPartnerManager } from "./DeployPartnerManager.s.sol";
import { DeployVehicleRegistry } from "./DeployVehicleRegistry.s.sol";
import { DeployTreasury } from "./DeployTreasury.s.sol";
import { DeployMarketplace } from "./DeployMarketplace.s.sol";

/**
 * @notice Main deployment script for Roboshare protocol contracts
 * @dev Deploys all contracts in proper dependency order
 *
 * Example: yarn deploy # runs this script(without`--file` flag)
 */
contract DeployScript is ScaffoldETHDeploy {
    function run() external ScaffoldEthDeployerRunner {
        // Get network configuration (now available from inherited ScaffoldETHDeploy)
        NetworkConfig memory config = getActiveNetworkConfig();
        
        console.log("Deploying to network:", getNetworkName());
        console.log("USDC Token:", config.usdcToken);
        console.log("Treasury Fee Recipient:", config.treasuryFeeRecipient);

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

        // 4. Deploy treasury (depends on vehicle registry + partner manager + tokens)
        DeployTreasury deployTreasury = new DeployTreasury();
        address treasuryProxy = deployTreasury.run(partnerManagerProxy, vehicleRegistryProxy, roboshareTokensProxy, config.usdcToken, deployer);

        // 5. Deploy marketplace (depends on all previous contracts)
        DeployMarketplace deployMarketplace = new DeployMarketplace();
        deployMarketplace.run(
            roboshareTokensProxy,
            vehicleRegistryProxy, 
            partnerManagerProxy,
            treasuryProxy,
            config.usdcToken,
            config.treasuryFeeRecipient,
            deployer
        );
    }
}
