// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ScaffoldETHDeploy } from "./DeployHelpers.s.sol";
import { MockUSDC } from "../contracts/mocks/MockUSDC.sol";
import { RoboshareTokens } from "../contracts/RoboshareTokens.sol";
import { PartnerManager } from "../contracts/PartnerManager.sol";
import { RegistryRouter } from "../contracts/RegistryRouter.sol";
import { VehicleRegistry } from "../contracts/VehicleRegistry.sol";
import { Treasury } from "../contracts/Treasury.sol";
import { Marketplace } from "../contracts/Marketplace.sol";

contract Deploy is ScaffoldETHDeploy {
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

        // Deploy RoboshareTokens
        {
            RoboshareTokens tokenImplementation = new RoboshareTokens();
            bytes memory tokenInitData = abi.encodeWithSignature("initialize(address)", deployer);
            ERC1967Proxy tokenProxy = new ERC1967Proxy(address(tokenImplementation), tokenInitData);
            roboshareTokens = RoboshareTokens(address(tokenProxy));
        }

        // Deploy PartnerManager
        {
            PartnerManager partnerImplementation = new PartnerManager();
            bytes memory partnerInitData = abi.encodeWithSignature("initialize(address)", deployer);
            ERC1967Proxy partnerProxy = new ERC1967Proxy(address(partnerImplementation), partnerInitData);
            partnerManager = PartnerManager(address(partnerProxy));
        }

        // Deploy RegistryRouter
        {
            RegistryRouter routerImplementation = new RegistryRouter();
            bytes memory routerInitData =
                abi.encodeWithSignature("initialize(address,address)", deployer, address(roboshareTokens));
            ERC1967Proxy routerProxy = new ERC1967Proxy(address(routerImplementation), routerInitData);
            router = RegistryRouter(address(routerProxy));
        }

        // Deploy VehicleRegistry
        {
            VehicleRegistry vehicleImplementation = new VehicleRegistry();
            bytes memory vehicleInitData = abi.encodeWithSignature(
                "initialize(address,address,address,address)",
                deployer,
                address(roboshareTokens),
                address(partnerManager),
                address(router)
            );
            ERC1967Proxy vehicleProxy = new ERC1967Proxy(address(vehicleImplementation), vehicleInitData);
            vehicleRegistry = VehicleRegistry(address(vehicleProxy));
        }

        // Deploy Treasury
        {
            Treasury treasuryImplementation = new Treasury();
            bytes memory treasuryInitData = abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address)",
                deployer,
                address(roboshareTokens),
                address(partnerManager),
                address(router),
                config.usdcToken,
                config.treasuryFeeRecipient
            );
            ERC1967Proxy treasuryProxy = new ERC1967Proxy(address(treasuryImplementation), treasuryInitData);
            treasury = Treasury(address(treasuryProxy));
        }

        // Deploy Marketplace
        {
            Marketplace marketplaceImplementation = new Marketplace();
            bytes memory marketplaceInitData = abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address)",
                deployer,
                address(roboshareTokens),
                address(partnerManager),
                address(router),
                address(treasury),
                config.usdcToken
            );
            ERC1967Proxy marketplaceProxy = new ERC1967Proxy(address(marketplaceImplementation), marketplaceInitData);
            marketplace = Marketplace(address(marketplaceProxy));
        }

        // --- Configuration & Role Granting ---

        // 1. Configure Router
        router.setTreasury(address(treasury));

        // 2. Grant Roles
        // Grant AUTHORIZED_REGISTRY_ROLE to VehicleRegistry
        router.grantRole(router.AUTHORIZED_REGISTRY_ROLE(), address(vehicleRegistry));

        // Grant MINTER_ROLE to Router (for reserving token IDs) and to VehicleRegistry (for minting revenue tokens on registration)
        roboshareTokens.grantRole(roboshareTokens.MINTER_ROLE(), address(router));
        roboshareTokens.grantRole(roboshareTokens.MINTER_ROLE(), address(vehicleRegistry));

        // Grant BURNER_ROLE to VehicleRegistry (for burning revenue tokens on retirement)
        roboshareTokens.grantRole(roboshareTokens.BURNER_ROLE(), address(vehicleRegistry));

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
