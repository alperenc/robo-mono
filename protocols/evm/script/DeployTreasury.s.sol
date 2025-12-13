// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { MockUSDC } from "../contracts/mocks/MockUSDC.sol";
import { ScaffoldETHDeploy } from "./DeployHelpers.s.sol";
import { Treasury } from "../contracts/Treasury.sol";

contract DeployTreasury is ScaffoldETHDeploy {
    /**
     * @dev Deploy Treasury with dependency addresses
     * Usage: yarn deploy --contract Treasury --network <network> --args <roboshareTokens>,<partnerManager>,<router>
     * Note: USDC and treasuryFeeRecipient are read from network config
     */
    function run(address roboshareTokensAddress, address partnerManagerAddress, address routerAddress)
        external
        scaffoldEthDeployerRunner
        returns (address)
    {
        // Get USDC and treasuryFeeRecipient from network config
        NetworkConfig memory config = getActiveNetworkConfig();

        // For local Anvil/testing, deploy mock USDC if not set
        if (config.usdcToken == address(0)) {
            MockUSDC mockUsdc = new MockUSDC();
            config.usdcToken = address(mockUsdc);
            console.log("Mock USDC deployed at:", address(mockUsdc));
        }

        // Use deployer as treasuryFeeRecipient fallback for local testing
        if (config.treasuryFeeRecipient == address(0)) {
            config.treasuryFeeRecipient = deployer;
            console.log("Using deployer as treasuryFeeRecipient:", deployer);
        }

        console.log("Deploying Treasury with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("Dependencies:");
        console.log("  - RoboshareTokens:", roboshareTokensAddress);
        console.log("  - PartnerManager:", partnerManagerAddress);
        console.log("  - Router:", routerAddress);
        console.log("  - USDC (from config):", config.usdcToken);
        console.log("  - TreasuryFeeRecipient (from config):", config.treasuryFeeRecipient);

        // Validate dependency addresses
        require(roboshareTokensAddress != address(0), "RoboshareTokens address cannot be zero");
        require(partnerManagerAddress != address(0), "PartnerManager address cannot be zero");
        require(routerAddress != address(0), "Router address cannot be zero");
        require(config.usdcToken != address(0), "USDC address cannot be zero");
        require(config.treasuryFeeRecipient != address(0), "TreasuryFeeRecipient address cannot be zero");

        // Deploy implementation contract
        Treasury treasuryImplementation = new Treasury();
        console.log("Treasury implementation deployed at:", address(treasuryImplementation));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address)",
            deployer, // admin
            roboshareTokensAddress,
            partnerManagerAddress,
            routerAddress,
            config.usdcToken,
            config.treasuryFeeRecipient
        );

        // Deploy proxy contract
        ERC1967Proxy proxy = new ERC1967Proxy(address(treasuryImplementation), initData);
        console.log("Treasury proxy deployed at:", address(proxy));

        // Wrap proxy in interface
        Treasury treasury = Treasury(address(proxy));

        // Verify initialization
        console.log("Admin has DEFAULT_ADMIN_ROLE:", treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), deployer));
        console.log("Admin has UPGRADER_ROLE:", treasury.hasRole(keccak256("UPGRADER_ROLE"), deployer));
        console.log("Admin has TREASURER_ROLE:", treasury.hasRole(keccak256("TREASURER_ROLE"), deployer));
        console.log("RoboshareTokens reference:", address(treasury.roboshareTokens()));
        console.log("PartnerManager reference:", address(treasury.partnerManager()));
        console.log("Router reference:", address(treasury.router()));
        console.log("USDC reference:", address(treasury.usdc()));
        console.log("TreasuryFeeRecipient:", treasury.treasuryFeeRecipient());

        // Log deployment summary
        console.log("=== Treasury Deployment Summary ===");
        console.log("Implementation:", address(treasuryImplementation));
        console.log("Proxy (main contract):", address(proxy));
        console.log("Admin:", deployer);
        console.log("Dependencies verified and connected");
        console.log("===================================");

        return address(proxy);
    }

    /**
     * @dev Default run function - reverts with usage info
     */
    function run() external pure returns (address) {
        revert(
            "Treasury deployment requires dependency addresses. "
            "Use: yarn deploy --contract Treasury --network <network> --args <roboshareTokens>,<partnerManager>,<router>"
        );
    }
}
