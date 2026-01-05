// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/Script.sol";
import { DeployCore } from "./DeployCore.s.sol";
import { MockUSDC } from "../contracts/mocks/MockUSDC.sol";
import { RoboshareTokens } from "../contracts/RoboshareTokens.sol";
import { PartnerManager } from "../contracts/PartnerManager.sol";
import { RegistryRouter } from "../contracts/RegistryRouter.sol";
import { VehicleRegistry } from "../contracts/VehicleRegistry.sol";
import { Treasury } from "../contracts/Treasury.sol";
import { Marketplace } from "../contracts/Marketplace.sol";

/**
 * @title Deploy
 * @dev Production deployment script. Uses shared deployment logic from DeployCore.
 */
contract Deploy is DeployCore {
    function run()
        external
        scaffoldEthDeployerRunner
        returns (
            RoboshareTokens roboshareTokens,
            PartnerManager partnerManager,
            RegistryRouter router,
            VehicleRegistry vehicleRegistry,
            Treasury treasury,
            Marketplace marketplace
        )
    {
        // Get network configuration
        NetworkConfig memory config = getActiveNetworkConfig();

        // For local Anvil, deploy mock USDC if not set
        if (config.usdcToken == address(0)) {
            MockUSDC mockUsdc = new MockUSDC();
            config.usdcToken = address(mockUsdc);
            console.log("Mock USDC (6 decimals) deployed at:", address(mockUsdc));

            // Mint initial supply to deployer for testing
            mockUsdc.mint(deployer, 1_000_000 * 1e6); // 1M USDC
        }

        // Use deployer as treasuryFeeRecipient fallback for local testing
        if (config.treasuryFeeRecipient == address(0)) {
            config.treasuryFeeRecipient = deployer;
            console.log("Using deployer as treasuryFeeRecipient:", deployer);
        }

        // Update active config
        activeNetworkConfig = config;

        // Deploy all contracts using shared core logic
        DeployedContracts memory contracts = _deployCore(deployer, config);

        // Unpack for return values
        roboshareTokens = contracts.roboshareTokens;
        partnerManager = contracts.partnerManager;
        router = contracts.router;
        vehicleRegistry = contracts.vehicleRegistry;
        treasury = contracts.treasury;
        marketplace = contracts.marketplace;

        // Save deployments for frontend generation
        saveDeployment("RoboshareTokens", address(roboshareTokens));
        saveDeployment("PartnerManager", address(partnerManager));
        saveDeployment("RegistryRouter", address(router));
        saveDeployment("VehicleRegistry", address(vehicleRegistry));
        saveDeployment("Treasury", address(treasury));
        saveDeployment("Marketplace", address(marketplace));
        if (config.usdcToken != address(0)) {
            // If local network, save the mock USDC deployment
            if (getActiveNetworkConfig().usdcToken != address(0) && isLocalNetwork()) {
                saveDeployment("MockUSDC", config.usdcToken);
            }
        }
    }
}
