// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { RoboshareTokens } from "../contracts/RoboshareTokens.sol";
import { PartnerManager } from "../contracts/PartnerManager.sol";
import { RegistryRouter } from "../contracts/RegistryRouter.sol";
import { VehicleRegistry } from "../contracts/VehicleRegistry.sol";
import { Treasury } from "../contracts/Treasury.sol";
import { Marketplace } from "../contracts/Marketplace.sol";
import { ScaffoldETHDeploy } from "./DeployHelpers.s.sol";

contract Deploy is ScaffoldETHDeploy {
    // Contract instances
    RoboshareTokens public roboshareTokens;
    PartnerManager public partnerManager;
    RegistryRouter public router;
    VehicleRegistry public vehicleRegistry;
    Treasury public treasury;
    Marketplace public marketplace;

    // Implementation contract instances
    RoboshareTokens public tokenImplementation;
    PartnerManager public partnerImplementation;
    RegistryRouter public routerImplementation;
    VehicleRegistry public vehicleImplementation;
    Treasury public treasuryImplementation;
    Marketplace public marketplaceImplementation;

    function run()
        external
        ScaffoldEthDeployerRunner
        returns (
            RoboshareTokens,
            PartnerManager,
            RegistryRouter,
            VehicleRegistry,
            Treasury,
            Marketplace,
            RoboshareTokens,
            PartnerManager,
            RegistryRouter,
            VehicleRegistry,
            Treasury,
            Marketplace
        )
    {
        // Get network configuration
        NetworkConfig memory config = getActiveNetworkConfig();

        // Deploy RoboshareTokens
        tokenImplementation = new RoboshareTokens();
        bytes memory tokenInitData = abi.encodeWithSignature("initialize(address)", deployer);
        ERC1967Proxy tokenProxy = new ERC1967Proxy(address(tokenImplementation), tokenInitData);
        roboshareTokens = RoboshareTokens(address(tokenProxy));

        // Deploy PartnerManager
        partnerImplementation = new PartnerManager();
        bytes memory partnerInitData = abi.encodeWithSignature("initialize(address)", deployer);
        ERC1967Proxy partnerProxy = new ERC1967Proxy(address(partnerImplementation), partnerInitData);
        partnerManager = PartnerManager(address(partnerProxy));

        // Deploy RegistryRouter
        routerImplementation = new RegistryRouter();
        bytes memory routerInitData =
            abi.encodeWithSignature("initialize(address,address)", deployer, address(roboshareTokens));
        ERC1967Proxy routerProxy = new ERC1967Proxy(address(routerImplementation), routerInitData);
        router = RegistryRouter(address(routerProxy));

        // Deploy VehicleRegistry
        vehicleImplementation = new VehicleRegistry();
        bytes memory vehicleInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address)",
            deployer,
            address(roboshareTokens),
            address(partnerManager),
            address(router)
        );
        ERC1967Proxy vehicleProxy = new ERC1967Proxy(address(vehicleImplementation), vehicleInitData);
        vehicleRegistry = VehicleRegistry(address(vehicleProxy));

        // Deploy Treasury
        treasuryImplementation = new Treasury();
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

        // Deploy Marketplace
        marketplaceImplementation = new Marketplace();
        bytes memory marketplaceInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address,address)",
            deployer,
            address(roboshareTokens),
            address(partnerManager),
            address(router),
            address(treasury),
            config.usdcToken,
            config.treasuryFeeRecipient
        );
        ERC1967Proxy marketplaceProxy = new ERC1967Proxy(address(marketplaceImplementation), marketplaceInitData);
        marketplace = Marketplace(address(marketplaceProxy));

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

        return (
            roboshareTokens,
            partnerManager,
            router,
            vehicleRegistry,
            treasury,
            marketplace,
            tokenImplementation,
            partnerImplementation,
            routerImplementation,
            vehicleImplementation,
            treasuryImplementation,
            marketplaceImplementation
        );
    }
}
