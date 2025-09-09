// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/VehicleRegistry.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployVehicleRegistry is Script {
    /**
     * @dev Deploy VehicleRegistry with dependency addresses as parameters
     * Usage: forge script DeployVehicleRegistry --sig "run(address,address)" $TOKENS_ADDR $PARTNER_ADDR
     */
    function run(address roboshareTokensAddress, address partnerManagerAddress, address deployerAddress)
        external
        returns (address)
    {
        address deployer = deployerAddress;

        console.log("Deploying VehicleRegistry with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("Dependencies:");
        console.log("  - RoboshareTokens:", roboshareTokensAddress);
        console.log("  - PartnerManager:", partnerManagerAddress);

        // Validate dependency addresses
        require(roboshareTokensAddress != address(0), "RoboshareTokens address cannot be zero");
        require(partnerManagerAddress != address(0), "PartnerManager address cannot be zero");

        // Deploy implementation contract
        VehicleRegistry vehicleImplementation = new VehicleRegistry();
        console.log("VehicleRegistry implementation deployed at:", address(vehicleImplementation));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address)", deployer, roboshareTokensAddress, partnerManagerAddress
        );

        // Deploy proxy contract
        ERC1967Proxy proxy = new ERC1967Proxy(address(vehicleImplementation), initData);
        console.log("VehicleRegistry proxy deployed at:", address(proxy));

        // Wrap proxy in interface
        VehicleRegistry vehicleRegistry = VehicleRegistry(address(proxy));

        // Verify initialization
        console.log(
            "Admin has DEFAULT_ADMIN_ROLE:", vehicleRegistry.hasRole(vehicleRegistry.DEFAULT_ADMIN_ROLE(), deployer)
        );
        console.log("Admin has UPGRADER_ROLE:", vehicleRegistry.hasRole(keccak256("UPGRADER_ROLE"), deployer));
        console.log("RoboshareTokens reference:", address(vehicleRegistry.roboshareTokens()));
        console.log("PartnerManager reference:", address(vehicleRegistry.partnerManager()));
        console.log("Initial token counter:", vehicleRegistry.getCurrentTokenId());

        // Log deployment summary
        console.log("=== Deployment Summary ===");
        console.log("Implementation:", address(vehicleImplementation));
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
            "VehicleRegistry deployment requires dependency addresses. "
            "Use: forge script DeployVehicleRegistry --sig 'run(address,address)' $TOKENS_ADDR $PARTNER_ADDR"
        );
    }
}
