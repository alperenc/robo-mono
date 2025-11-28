// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/Marketplace.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployMarketplace is Script {
    /**
     * @dev Deploy Marketplace with dependency addresses as parameters
     * Usage: forge script DeployMarketplace --sig "run(address,address,address,address,address,address,address)" ...
     */
    function run(
        address roboshareTokensAddress,
        address routerAddress,
        address partnerManagerAddress,
        address treasuryAddress,
        address usdcTokenAddress,
        address treasuryFeeAddress,
        address deployerAddress
    ) external returns (address) {
        address deployer = deployerAddress;

        console.log("Deploying Marketplace with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("Dependencies:");
        console.log("  - RoboshareTokens:", roboshareTokensAddress);
        console.log("  - Router:", routerAddress);
        console.log("  - PartnerManager:", partnerManagerAddress);
        console.log("  - Treasury:", treasuryAddress);
        console.log("  - USDC Token:", usdcTokenAddress);
        console.log("  - Treasury Fee Address:", treasuryFeeAddress);

        // Validate dependency addresses
        require(roboshareTokensAddress != address(0), "RoboshareTokens address cannot be zero");
        require(routerAddress != address(0), "Router address cannot be zero");
        require(partnerManagerAddress != address(0), "PartnerManager address cannot be zero");
        require(treasuryAddress != address(0), "Treasury address cannot be zero");
        require(usdcTokenAddress != address(0), "USDC Token address cannot be zero");
        require(treasuryFeeAddress != address(0), "Treasury fee address cannot be zero");

        // Deploy implementation contract
        Marketplace marketplaceImplementation = new Marketplace();
        console.log("Marketplace implementation deployed at:", address(marketplaceImplementation));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address,address,address,address,address)",
            deployer, // admin
            roboshareTokensAddress, // roboshareTokens
            partnerManagerAddress, // partnerManager
            routerAddress, // router
            treasuryAddress, // treasury
            usdcTokenAddress, // usdcToken
            treasuryFeeAddress // treasuryAddress (for fees)
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
        console.log("Router reference:", address(marketplace.router()));
        console.log("PartnerManager reference:", address(marketplace.partnerManager()));
        console.log("Treasury reference:", address(marketplace.treasury()));
        console.log("USDC Token reference:", address(marketplace.usdcToken()));
        console.log("Treasury fee address:", marketplace.treasuryFeeRecipient());
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
     * @dev Default run function for backwards compatibility
     * This will fail with a clear error message if called without parameters
     */
    function run() external pure returns (address) {
        revert(
            "Marketplace deployment requires dependency addresses. "
            "Use: forge script DeployMarketplace --sig 'run(address,address,address,address,address,address,address)' ..."
        );
    }
}
