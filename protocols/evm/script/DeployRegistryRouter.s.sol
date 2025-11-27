// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/RegistryRouter.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployRegistryRouter is Script {
    /**
     * @dev Deploy RegistryRouter with dependency addresses as parameters
     * Usage: forge script DeployRegistryRouter --sig "run(address,address)" $TOKENS_ADDR $ADMIN_ADDR
     */
    function run(address roboshareTokensAddress, address adminAddress) external returns (address) {
        address deployer = adminAddress;

        console.log("Deploying RegistryRouter with deployer:", deployer);
        console.log("Dependencies:");
        console.log("  - RoboshareTokens:", roboshareTokensAddress);

        require(roboshareTokensAddress != address(0), "RoboshareTokens address cannot be zero");
        require(adminAddress != address(0), "Admin address cannot be zero");

        // Deploy implementation
        RegistryRouter routerImplementation = new RegistryRouter();
        console.log("RegistryRouter implementation deployed at:", address(routerImplementation));

        // Prepare initialization data
        bytes memory initData =
            abi.encodeWithSignature("initialize(address,address)", adminAddress, roboshareTokensAddress);

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(routerImplementation), initData);
        console.log("RegistryRouter proxy deployed at:", address(proxy));

        // Wrap proxy in interface
        RegistryRouter router = RegistryRouter(address(proxy));

        // Verify initialization
        console.log("Admin has DEFAULT_ADMIN_ROLE:", router.hasRole(router.DEFAULT_ADMIN_ROLE(), adminAddress));
        console.log("Admin has REGISTRY_ADMIN_ROLE:", router.hasRole(keccak256("REGISTRY_ADMIN_ROLE"), adminAddress));
        console.log("RoboshareTokens reference:", address(router.roboshareTokens()));

        return address(proxy);
    }

    function run() external pure returns (address) {
        revert("RegistryRouter deployment requires dependency addresses.");
    }
}
