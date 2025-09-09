// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/Treasury.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployTreasury is Script {
    /**
     * @dev Deploy Treasury with dependency addresses as parameters
     * Usage: forge script DeployTreasury --sig "run(address,address,address,address)" $PARTNER_MANAGER_ADDR $VEHICLE_REGISTRY_ADDR $USDC_ADDR $ADMIN_ADDR
     */
    function run(
        address partnerManagerAddress,
        address vehicleRegistryAddress,
        address usdcAddress,
        address adminAddress
    ) external returns (address) {
        address deployer = adminAddress; // Use admin as deployer for logging consistency

        console.log("Deploying Treasury with deployer:", deployer);
        console.log("Deployer balance:", deployer.balance);
        console.log("Dependencies:");
        console.log("  - PartnerManager:", partnerManagerAddress);
        console.log("  - VehicleRegistry:", vehicleRegistryAddress);
        console.log("  - USDC:", usdcAddress);
        console.log("  - Admin:", adminAddress);

        // Validate dependency addresses
        require(partnerManagerAddress != address(0), "PartnerManager address cannot be zero");
        require(vehicleRegistryAddress != address(0), "VehicleRegistry address cannot be zero");
        require(usdcAddress != address(0), "USDC address cannot be zero");
        require(adminAddress != address(0), "Admin address cannot be zero");

        // Deploy implementation contract
        Treasury treasuryImplementation = new Treasury();
        console.log("Treasury implementation deployed at:", address(treasuryImplementation));

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address,address)",
            adminAddress,
            partnerManagerAddress,
            vehicleRegistryAddress,
            usdcAddress
        );

        // Deploy proxy contract
        ERC1967Proxy proxy = new ERC1967Proxy(address(treasuryImplementation), initData);
        console.log("Treasury proxy deployed at:", address(proxy));

        // Wrap proxy in interface
        Treasury treasury = Treasury(address(proxy));

        // Verify initialization
        console.log("Admin has DEFAULT_ADMIN_ROLE:", treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), adminAddress));
        console.log("Admin has UPGRADER_ROLE:", treasury.hasRole(keccak256("UPGRADER_ROLE"), adminAddress));
        console.log("Admin has TREASURER_ROLE:", treasury.hasRole(keccak256("TREASURER_ROLE"), adminAddress));
        console.log("PartnerManager reference:", address(treasury.partnerManager()));
        console.log("VehicleRegistry reference:", address(treasury.vehicleRegistry()));
        console.log("USDC reference:", address(treasury.usdc()));
        console.log("Total collateral deposited:", treasury.totalCollateralDeposited());

        // Log deployment summary
        console.log("=== Treasury Deployment Summary ===");
        console.log("Implementation:", address(treasuryImplementation));
        console.log("Proxy (main contract):", address(proxy));
        console.log("Admin:", adminAddress);
        console.log("Dependencies verified and connected");
        console.log("USDC-based collateral management ready");
        console.log("=====================================");

        return address(proxy);
    }

    /**
     * @dev Default run function for backwards compatibility
     * This will fail with a clear error message if called without parameters
     */
    function run() external pure returns (address) {
        revert(
            "Treasury deployment requires dependency addresses. "
            "Use: forge script DeployTreasury --sig 'run(address,address,address,address)' $PARTNER_MANAGER $VEHICLE_REGISTRY $USDC $ADMIN"
        );
    }
}
