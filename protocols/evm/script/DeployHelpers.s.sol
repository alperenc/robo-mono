//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { Vm } from "forge-std/Vm.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract ScaffoldETHDeploy is Script {
    error InvalidChain();
    error DeployerHasNoBalance();
    error InvalidPrivateKey(string);

    event AnvilSetBalance(address account, uint256 amount);
    event FailedAnvilRequest();

    struct Deployment {
        string name;
        address addr;
    }

    // Network configuration structure
    struct NetworkConfig {
        address usdcToken; // USDC token address
        address treasuryFeeRecipient; // Where protocol fees go
    }

    string root;
    string path;
    Deployment[] public deployments;
    uint256 constant ANVIL_BASE_BALANCE = 10000 ether;
    
    // Network configuration constants
    uint8 public constant USDC_DECIMALS = 6;
    uint256 public constant INITIAL_USDC_SUPPLY = 1000000 * 10 ** USDC_DECIMALS; // 1M USDC

    /// @notice The deployer address for every run
    address deployer;
    
    /// @notice Active network configuration
    NetworkConfig public activeNetworkConfig;

    /// @notice Constructor to initialize network configuration
    constructor() {
        if (block.chainid == 1) {
            activeNetworkConfig = getMainnetConfig();
        } else if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else if (block.chainid == 137) {
            activeNetworkConfig = getPolygonConfig();
        } else if (block.chainid == 42161) {
            activeNetworkConfig = getArbitrumConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    /// @notice Use this modifier on your run() function on your deploy scripts
    modifier ScaffoldEthDeployerRunner() {
        deployer = _startBroadcast();
        if (deployer == address(0)) {
            revert InvalidPrivateKey("Invalid private key");
        }
        _;
        _stopBroadcast();
        exportDeployments();
    }

    function _startBroadcast() internal returns (address) {
        vm.startBroadcast();
        (, address _deployer,) = vm.readCallers();

        if (block.chainid == 31337 && _deployer.balance == 0) {
            try this.anvil_setBalance(_deployer, ANVIL_BASE_BALANCE) {
                emit AnvilSetBalance(_deployer, ANVIL_BASE_BALANCE);
            } catch {
                emit FailedAnvilRequest();
            }
        }
        return _deployer;
    }

    function _stopBroadcast() internal {
        vm.stopBroadcast();
    }

    function exportDeployments() internal {
        // fetch already existing contracts
        root = vm.projectRoot();
        path = string.concat(root, "/deployments/");
        string memory chainIdStr = vm.toString(block.chainid);
        path = string.concat(path, string.concat(chainIdStr, ".json"));

        string memory jsonWrite;

        uint256 len = deployments.length;

        for (uint256 i = 0; i < len; i++) {
            vm.serializeString(jsonWrite, vm.toString(deployments[i].addr), deployments[i].name);
        }

        string memory chainName;

        try this.getChain() returns (Chain memory chain) {
            chainName = chain.name;
        } catch {
            chainName = findChainName();
        }
        jsonWrite = vm.serializeString(jsonWrite, "networkName", chainName);
        vm.writeJson(jsonWrite, path);
    }

    function getChain() public returns (Chain memory) {
        return getChain(block.chainid);
    }

    function anvil_setBalance(address addr, uint256 amount) public {
        string memory addressString = vm.toString(addr);
        string memory amountString = vm.toString(amount);
        string memory requestPayload = string.concat(
            '{"method":"anvil_setBalance","params":["', addressString, '","', amountString, '"],"id":1,"jsonrpc":"2.0"}'
        );

        string[] memory inputs = new string[](8);
        inputs[0] = "curl";
        inputs[1] = "-X";
        inputs[2] = "POST";
        inputs[3] = "http://localhost:8545";
        inputs[4] = "-H";
        inputs[5] = "Content-Type: application/json";
        inputs[6] = "--data";
        inputs[7] = requestPayload;

        vm.ffi(inputs);
    }

    function findChainName() public returns (string memory) {
        uint256 thisChainId = block.chainid;
        string[2][] memory allRpcUrls = vm.rpcUrls();
        for (uint256 i = 0; i < allRpcUrls.length; i++) {
            try vm.createSelectFork(allRpcUrls[i][1]) {
                if (block.chainid == thisChainId) {
                    return allRpcUrls[i][0];
                }
            } catch {
                continue;
            }
        }
        revert InvalidChain();
    }

    // Network Configuration Methods

    function getMainnetConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory mainnetConfig = NetworkConfig({
            usdcToken: 0xa0B86a33e6A6c5e4F5b8F8f4A1a7F4c5a6c9B7d8, // Mainnet USDC
            treasuryFeeRecipient: 0x1234567890123456789012345678901234567890 // Replace with actual treasury
        });
        return mainnetConfig;
    }

    function getSepoliaConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            usdcToken: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238, // Sepolia USDC
            treasuryFeeRecipient: 0x1234567890123456789012345678901234567890 // Replace with actual treasury
        });
        return sepoliaConfig;
    }

    function getPolygonConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory polygonConfig = NetworkConfig({
            usdcToken: 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174, // Polygon USDC
            treasuryFeeRecipient: 0x1234567890123456789012345678901234567890 // Replace with actual treasury
        });
        return polygonConfig;
    }

    function getArbitrumConfig() public pure returns (NetworkConfig memory) {
        NetworkConfig memory arbitrumConfig = NetworkConfig({
            usdcToken: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831, // Arbitrum USDC
            treasuryFeeRecipient: 0x1234567890123456789012345678901234567890 // Replace with actual treasury
        });
        return arbitrumConfig;
    }

    function getOrCreateAnvilConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.usdcToken != address(0)) {
            return activeNetworkConfig;
        }

        // Deploy mock USDC for local testing
        vm.startBroadcast();
        ERC20Mock mockUsdc = new ERC20Mock();
        // Mint initial supply to deployer for testing
        mockUsdc.mint(msg.sender, INITIAL_USDC_SUPPLY);
        vm.stopBroadcast();

        NetworkConfig memory anvilConfig = NetworkConfig({
            usdcToken: address(mockUsdc),
            treasuryFeeRecipient: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 // Anvil default deployer
        });
        return anvilConfig;
    }

    // Helper functions for network management

    /// @notice Get current network config
    function getActiveNetworkConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    /// @notice Check if we're on a local network
    function isLocalNetwork() public view returns (bool) {
        return block.chainid == 31337; // Anvil chain ID
    }

    /// @notice Get network name for logging
    function getNetworkName() public view returns (string memory) {
        if (block.chainid == 1) {
            return "mainnet";
        } else if (block.chainid == 11155111) {
            return "sepolia";
        } else if (block.chainid == 137) {
            return "polygon";
        } else if (block.chainid == 42161) {
            return "arbitrum";
        } else if (block.chainid == 31337) {
            return "anvil";
        } else {
            return "unknown";
        }
    }
}
