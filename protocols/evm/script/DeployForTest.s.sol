// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Marketplace } from "../contracts/Marketplace.sol";
import { VehicleRegistry } from "../contracts/VehicleRegistry.sol";
import { RoboshareTokens } from "../contracts/RoboshareTokens.sol";
import { PartnerManager } from "../contracts/PartnerManager.sol";
import { Treasury } from "../contracts/Treasury.sol";
import { ScaffoldETHDeploy } from "./DeployHelpers.s.sol";

contract DeployForTest is ScaffoldETHDeploy {
    // Contract instances
    Marketplace public marketplace;
    VehicleRegistry public vehicleRegistry;
    RoboshareTokens public roboshareTokens;
    PartnerManager public partnerManager;
    Treasury public treasury;

    // Implementation contract instances
    Marketplace public marketplaceImplementation;
    VehicleRegistry public vehicleImplementation;
    RoboshareTokens public tokenImplementation;
    PartnerManager public partnerImplementation;
    Treasury public treasuryImplementation;

    modifier TestDeployerRunner(address _deployer) {
        vm.startPrank(_deployer);
        _;
        vm.stopPrank();
    }

    function run(address _deployer)
        public
        TestDeployerRunner(_deployer)
        returns (
            Marketplace,
            VehicleRegistry,
            RoboshareTokens,
            PartnerManager,
            Treasury,
            Marketplace,
            VehicleRegistry,
            RoboshareTokens,
            PartnerManager,
            Treasury
        )
    {
        // Get network configuration
        NetworkConfig memory config = getActiveNetworkConfig();

        // Deploy RoboshareTokens
        tokenImplementation = new RoboshareTokens();
        bytes memory tokenInitData = abi.encodeWithSignature("initialize(address)", _deployer);
        ERC1967Proxy tokenProxy = new ERC1967Proxy(address(tokenImplementation), tokenInitData);
        roboshareTokens = RoboshareTokens(address(tokenProxy));

        // Deploy PartnerManager
        partnerImplementation = new PartnerManager();
        bytes memory partnerInitData = abi.encodeWithSignature("initialize(address)", _deployer);
        ERC1967Proxy partnerProxy = new ERC1967Proxy(address(partnerImplementation), partnerInitData);
        partnerManager = PartnerManager(address(partnerProxy));

        // Deploy VehicleRegistry
        vehicleImplementation = new VehicleRegistry();
        bytes memory vehicleInitData = abi.encodeWithSignature(
            "initialize(address,address,address)", _deployer, address(roboshareTokens), address(partnerManager)
        );
        ERC1967Proxy vehicleProxy = new ERC1967Proxy(address(vehicleImplementation), vehicleInitData);
        vehicleRegistry = VehicleRegistry(address(vehicleProxy));

        // Deploy Treasury
        treasuryImplementation = new Treasury();
        bytes memory treasuryInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address)",
            _deployer,
            address(partnerManager),
            address(vehicleRegistry),
            address(roboshareTokens),
            config.usdcToken,
            config.treasuryFeeRecipient
        );
        ERC1967Proxy treasuryProxy = new ERC1967Proxy(address(treasuryImplementation), treasuryInitData);
        treasury = Treasury(address(treasuryProxy));

        // Deploy Marketplace
        marketplaceImplementation = new Marketplace();
        bytes memory marketplaceInitData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address,address)",
            _deployer,
            address(roboshareTokens),
            address(vehicleRegistry),
            address(partnerManager),
            address(treasury),
            config.usdcToken,
            config.treasuryFeeRecipient
        );
        ERC1967Proxy marketplaceProxy = new ERC1967Proxy(address(marketplaceImplementation), marketplaceInitData);
        marketplace = Marketplace(address(marketplaceProxy));

        // Set the Treasury address in the VehicleRegistry
        vehicleRegistry.setTreasury(address(treasury));

        return (
            marketplace,
            vehicleRegistry,
            roboshareTokens,
            partnerManager,
            treasury,
            marketplaceImplementation,
            vehicleImplementation,
            tokenImplementation,
            partnerImplementation,
            treasuryImplementation
        );
    }
}
