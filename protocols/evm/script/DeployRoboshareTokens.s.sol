// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/RoboshareTokens.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployRoboshareTokens is Script {
    function run(address deployerAddress) external returns (address) {
        address deployer = deployerAddress;

        console.log("Deploying RoboshareTokens with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);

        // Deploy implementation contract
        RoboshareTokens tokenImplementation = new RoboshareTokens();
        console.log("RoboshareTokens implementation deployed at:", address(tokenImplementation));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSignature("initialize(address)", deployer);

        // Deploy proxy contract
        ERC1967Proxy proxy = new ERC1967Proxy(address(tokenImplementation), initData);
        console.log("RoboshareTokens proxy deployed at:", address(proxy));

        // Wrap proxy in interface
        RoboshareTokens tokens = RoboshareTokens(address(proxy));

        // Verify initialization
        console.log("Admin has DEFAULT_ADMIN_ROLE:", tokens.hasRole(tokens.DEFAULT_ADMIN_ROLE(), deployer));
        console.log("Admin has MINTER_ROLE:", tokens.hasRole(keccak256("MINTER_ROLE"), deployer));
        console.log("Admin has BURNER_ROLE:", tokens.hasRole(keccak256("BURNER_ROLE"), deployer));
        console.log("Next token ID:", tokens.getNextTokenId());

        // Log deployment summary
        console.log("=== Deployment Summary ===");
        console.log("Implementation:", address(tokenImplementation));
        console.log("Proxy (main contract):", address(proxy));
        console.log("Deployer/Admin:", deployer);
        console.log("==========================");

        return address(proxy);
    }
}
