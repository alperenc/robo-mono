//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";

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
        } else if (block.chainid == 137) {
            activeNetworkConfig = getPolygonConfig();
        } else if (block.chainid == 42161) {
            activeNetworkConfig = getArbitrumConfig();
        } else if (block.chainid == 8453) {
            activeNetworkConfig = getBaseConfig();
        } else {
            // Testnets and localhost use MockUSDC
            activeNetworkConfig = getLocalOrTestNetworkConfig();
        }
    }

    /// @notice Use this modifier on your run() function on your deploy scripts
    modifier scaffoldEthDeployerRunner() {
        deployer = _startBroadcast();
        if (deployer == address(0)) {
            revert InvalidPrivateKey("Invalid private key");
        }
        _;
        _stopBroadcast();
        exportDeployments();
    }

    function saveDeployment(string memory name, address addr) public {
        deployments.push(Deployment({ name: name, addr: addr }));
    }

    function _startBroadcast() internal returns (address) {
        vm.startBroadcast();
        (, address _deployer,) = vm.readCallers();

        if (block.chainid == 31337 && _deployer.balance == 0) {
            try this.anvilSetBalance(_deployer, ANVIL_BASE_BALANCE) {
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

        string memory chainName = _getChainName();
        jsonWrite = vm.serializeString(jsonWrite, "networkName", chainName);
        vm.writeJson(jsonWrite, path);
    }

    function _getChainName() internal returns (string memory) {
        try vm.rpcUrl("mainnet") returns (string memory) {
            Chain memory chain = getChain(block.chainid);
            return chain.name;
        } catch {
            return findChainName();
        }
    }

    function getChain() public returns (Chain memory) {
        return getChain(block.chainid);
    }

    function anvilSetBalance(address addr, uint256 amount) public {
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

        // forge-lint: disable-next-line(unsafe-cheatcode)
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

    function getMainnetConfig() public view returns (NetworkConfig memory) {
        address treasuryRecipient = _getTreasuryFeeRecipientFromEnv();
        require(treasuryRecipient != address(0), "TREASURY_FEE_RECIPIENT env var required for mainnet");
        NetworkConfig memory mainnetConfig = NetworkConfig({
            usdcToken: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, // Mainnet USDC (corrected address)
            treasuryFeeRecipient: treasuryRecipient
        });
        return mainnetConfig;
    }

    function getPolygonConfig() public view returns (NetworkConfig memory) {
        address treasuryRecipient = _getTreasuryFeeRecipientFromEnv();
        require(treasuryRecipient != address(0), "TREASURY_FEE_RECIPIENT env var required for polygon");
        NetworkConfig memory polygonConfig = NetworkConfig({
            usdcToken: 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359, // Polygon USDC (native)
            treasuryFeeRecipient: treasuryRecipient
        });
        return polygonConfig;
    }

    function getArbitrumConfig() public view returns (NetworkConfig memory) {
        address treasuryRecipient = _getTreasuryFeeRecipientFromEnv();
        require(treasuryRecipient != address(0), "TREASURY_FEE_RECIPIENT env var required for arbitrum");
        NetworkConfig memory arbitrumConfig = NetworkConfig({
            usdcToken: 0xaf88d065e77c8cC2239327C5EDb3A432268e5831, // Arbitrum USDC
            treasuryFeeRecipient: treasuryRecipient
        });
        return arbitrumConfig;
    }

    function getBaseConfig() public view returns (NetworkConfig memory) {
        address treasuryRecipient = _getTreasuryFeeRecipientFromEnv();
        require(treasuryRecipient != address(0), "TREASURY_FEE_RECIPIENT env var required for base");
        NetworkConfig memory baseConfig = NetworkConfig({
            usdcToken: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913, // Base USDC
            treasuryFeeRecipient: treasuryRecipient
        });
        return baseConfig;
    }

    /// @notice Config for localhost and testnets - uses MockUSDC
    function getLocalOrTestNetworkConfig() public view returns (NetworkConfig memory) {
        // For testnets and localhost, use address(0) as placeholder
        // Deploy scripts will deploy MockUSDC and use deployer as fallback for treasuryFeeRecipient
        address usdc = address(0);
        try vm.envAddress("USDC_ADDRESS") returns (address _usdc) {
            usdc = _usdc;
        } catch { }
        NetworkConfig memory testConfig = NetworkConfig({
            usdcToken: usdc, // Will deploy MockUSDC if not set
            treasuryFeeRecipient: address(0) // Will use deployer as fallback
        });
        return testConfig;
    }

    /// @notice Read TREASURY_FEE_RECIPIENT from environment variable
    function _getTreasuryFeeRecipientFromEnv() internal view returns (address) {
        try vm.envAddress("TREASURY_FEE_RECIPIENT") returns (address recipient) {
            return recipient;
        } catch {
            return address(0);
        }
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

    /// @notice Check if we're on a local network or testnet
    /// MockUSDC will be deployed on these networks
    function isLocalOrTestNetwork() public view returns (bool) {
        return block.chainid == 31337 // Anvil (localhost)
            || block.chainid == 11155111 // Sepolia
            || block.chainid == 84532 // Base Sepolia
            || block.chainid == 421614 // Arbitrum Sepolia
            || block.chainid == 80002; // Polygon Amoy
    }

    /// @notice Get network name for logging
    function getNetworkName() public view returns (string memory) {
        if (block.chainid == 1) return "mainnet";
        if (block.chainid == 137) return "polygon";
        if (block.chainid == 42161) return "arbitrum";
        if (block.chainid == 8453) return "base";
        if (block.chainid == 11155111) return "sepolia";
        if (block.chainid == 84532) return "baseSepolia";
        if (block.chainid == 421614) return "arbitrumSepolia";
        if (block.chainid == 80002) return "polygonAmoy";
        if (block.chainid == 31337) return "anvil";
        return "unknown";
    }
}
