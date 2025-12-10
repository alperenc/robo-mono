// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./DeployHelpers.s.sol";
import "../contracts/Marketplace.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DeployMarketplace is ScaffoldETHDeploy {
    /**
     * @dev Deploy Marketplace with dependency addresses
     * Usage: yarn deploy --contract Marketplace --network <network> --args <roboshareTokens>,<partnerManager>,<router>,<treasury>
     * Note: USDC is read from network config
     */
    function run(
        address roboshareTokensAddress,
        address partnerManagerAddress,
        address routerAddress,
        address treasuryAddress
    ) external ScaffoldEthDeployerRunner returns (address) {
        // Get USDC from network config
        NetworkConfig memory config = getActiveNetworkConfig();

        // For local Anvil/testing, deploy mock USDC if not set
        if (config.usdcToken == address(0)) {
            ERC20Mock mockUsdc = new ERC20Mock();
            config.usdcToken = address(mockUsdc);
            console.log("Mock USDC deployed at:", address(mockUsdc));
        }

        console.log("Deploying Marketplace with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("Dependencies:");
        console.log("  - RoboshareTokens:", roboshareTokensAddress);
        console.log("  - PartnerManager:", partnerManagerAddress);
        console.log("  - Router:", routerAddress);
        console.log("  - Treasury:", treasuryAddress);
        console.log("  - USDC (from config):", config.usdcToken);

        // Validate dependency addresses
        require(roboshareTokensAddress != address(0), "RoboshareTokens address cannot be zero");
        require(partnerManagerAddress != address(0), "PartnerManager address cannot be zero");
        require(routerAddress != address(0), "Router address cannot be zero");
        require(treasuryAddress != address(0), "Treasury address cannot be zero");
        require(config.usdcToken != address(0), "USDC Token address cannot be zero");

        // Deploy implementation contract
        Marketplace marketplaceImplementation = new Marketplace();
        console.log("Marketplace implementation deployed at:", address(marketplaceImplementation));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address)",
            deployer, // admin
            roboshareTokensAddress,
            partnerManagerAddress,
            routerAddress,
            treasuryAddress,
            config.usdcToken
        );

        // Deploy proxy contract
        ERC1967Proxy proxy = new ERC1967Proxy(address(marketplaceImplementation), initData);
        console.log("Marketplace proxy deployed at:", address(proxy));

        // Wrap proxy in interface
        Marketplace marketplace = Marketplace(address(proxy));

        // Verify initialization
        console.log("Admin has DEFAULT_ADMIN_ROLE:", marketplace.hasRole(marketplace.DEFAULT_ADMIN_ROLE(), deployer));
        console.log("Admin has UPGRADER_ROLE:", marketplace.hasRole(keccak256("UPGRADER_ROLE"), deployer));
        console.log("RoboshareTokens reference:", address(marketplace.roboshareTokens()));
        console.log("PartnerManager reference:", address(marketplace.partnerManager()));
        console.log("Router reference:", address(marketplace.router()));
        console.log("Treasury reference:", address(marketplace.treasury()));
        console.log("USDC Token reference:", address(marketplace.usdcToken()));
        console.log("Initial listing counter:", marketplace.getCurrentListingId());

        // Log deployment summary
        console.log("=== Deployment Summary ===");
        console.log("Implementation:", address(marketplaceImplementation));
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
            "Marketplace deployment requires dependency addresses. "
            "Use: yarn deploy --contract Marketplace --network <network> --args <roboshareTokens>,<partnerManager>,<router>,<treasury>"
        );
    }
}
