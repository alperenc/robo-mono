// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ScaffoldETHDeploy } from "./DeployHelpers.s.sol";
import { EarningsManager } from "../contracts/EarningsManager.sol";

contract DeployEarningsManager is ScaffoldETHDeploy {
    /**
     * @dev Deploy EarningsManager with dependency addresses
     * Usage: yarn deploy --contract EarningsManager --network <network> --args <roboshareTokens>,<partnerManager>,<router>,<treasury>
     * Note: USDC is read from network config
     */
    function run(
        address roboshareTokensAddress,
        address partnerManagerAddress,
        address routerAddress,
        address treasuryAddress
    ) external scaffoldEthDeployerRunner returns (address) {
        NetworkConfig memory config = getActiveNetworkConfig();

        if (config.usdcToken == address(0)) {
            config.usdcToken = ensureLocalOrTestUsdc(deployer);
            console.log("Mock USDC deployed at:", config.usdcToken);
        }

        activeNetworkConfig = config;

        console.log("Deploying EarningsManager with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("Dependencies:");
        console.log("  - RoboshareTokens:", roboshareTokensAddress);
        console.log("  - PartnerManager:", partnerManagerAddress);
        console.log("  - Router:", routerAddress);
        console.log("  - Treasury:", treasuryAddress);
        console.log("  - USDC (from config):", config.usdcToken);

        require(roboshareTokensAddress != address(0), "RoboshareTokens address cannot be zero");
        require(partnerManagerAddress != address(0), "PartnerManager address cannot be zero");
        require(routerAddress != address(0), "Router address cannot be zero");
        require(treasuryAddress != address(0), "Treasury address cannot be zero");
        require(config.usdcToken != address(0), "USDC address cannot be zero");

        EarningsManager earningsManagerImplementation = new EarningsManager();
        console.log("EarningsManager implementation deployed at:", address(earningsManagerImplementation));

        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address)",
            deployer,
            roboshareTokensAddress,
            partnerManagerAddress,
            routerAddress,
            treasuryAddress,
            config.usdcToken
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(earningsManagerImplementation), initData);
        console.log("EarningsManager proxy deployed at:", address(proxy));

        EarningsManager earningsManager = EarningsManager(address(proxy));

        console.log(
            "Admin has DEFAULT_ADMIN_ROLE:", earningsManager.hasRole(earningsManager.DEFAULT_ADMIN_ROLE(), deployer)
        );
        console.log("Admin has UPGRADER_ROLE:", earningsManager.hasRole(keccak256("UPGRADER_ROLE"), deployer));
        console.log("RoboshareTokens reference:", address(earningsManager.roboshareTokens()));
        console.log("PartnerManager reference:", address(earningsManager.partnerManager()));
        console.log("Router reference:", address(earningsManager.router()));
        console.log("Treasury reference:", address(earningsManager.treasury()));
        console.log("USDC reference:", address(earningsManager.usdc()));

        console.log("=== EarningsManager Deployment Summary ===");
        console.log("Implementation:", address(earningsManagerImplementation));
        console.log("Proxy (main contract):", address(proxy));
        console.log("Deployer/Admin:", deployer);
        console.log("Dependencies verified and connected");
        console.log("==========================================");
        console.log("");
        console.log("Post-deploy: call RegistryRouter.setEarningsManager(<earningsManager>)");
        console.log("Post-deploy: call Treasury.setEarningsManager(<earningsManager>)");

        saveDeployment("EarningsManager", address(proxy));

        return address(proxy);
    }

    function run() external pure returns (address) {
        revert(
            "EarningsManager deployment requires dependency addresses. "
            "Use: yarn deploy --contract EarningsManager --network <network> --args <roboshareTokens>,<partnerManager>,<router>,<treasury>"
        );
    }
}
