import { spawnSync } from "child_process";
import { config } from "dotenv";
import { join, dirname } from "path";
import { readFileSync, existsSync } from "fs";
import { parse } from "toml";
import { fileURLToPath } from "url";
import { selectOrCreateKeystore } from "./selectOrCreateKeystore.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
config();

// Contract signatures for dependency injection
const CONTRACT_SIGNATURES = {
  // No dependencies - default run()
  PartnerManager: { sig: null, params: [] },
  RoboshareTokens: { sig: null, params: [] },
  // 1 dependency
  RegistryRouter: {
    sig: "run(address)",
    params: ["roboshareTokens"],
  },
  // 3 dependencies
  VehicleRegistry: {
    sig: "run(address,address,address)",
    params: ["roboshareTokens", "partnerManager", "router"],
  },
  Treasury: {
    sig: "run(address,address,address)",
    params: ["roboshareTokens", "partnerManager", "router"],
  },
  // 4 dependencies
  Marketplace: {
    sig: "run(address,address,address,address)",
    params: ["roboshareTokens", "partnerManager", "router", "treasury"],
  },
};

// Get all arguments after the script name
const args = process.argv.slice(2);

// Detect command type from package.json script name
const command = process.env.npm_lifecycle_event || "deploy";

let fileName = "Deploy.s.sol";
let network = "localhost";
let keystoreArg = null;
let contractName = null;
let proxyAddress = null;
let sigArgs = []; // For dependency addresses via --args

// Show help message if --help is provided
if (args.includes("--help") || args.includes("-h")) {
  if (command === "upgrade") {
    console.log(`
Usage: yarn upgrade [options]
Options:
  --contract <name>       Specify the contract to upgrade (required)
  --proxy-address <addr>  Specify the proxy contract address (required)
  --network <network>     Specify the network (default: localhost)
  --keystore <name>       Specify the keystore account to use (bypasses selection prompt)
  --help, -h             Show this help message
Examples:
  yarn upgrade --contract VehicleRegistry --proxy-address 0x3dc1ec9c2867fd75f63f089b5c9760b3d259e07d
  yarn upgrade --contract Treasury --proxy-address 0x123... --network sepolia
    `);
  } else {
    console.log(`
Usage: yarn deploy [options]
Options:
  --file <filename>     Specify the deployment script file (default: Deploy.s.sol)
  --contract <name>     Deploy a specific contract (uses Deploy<ContractName>.s.sol)
  --network <network>   Specify the network (default: localhost)
  --args <addresses>    Comma-separated dependency addresses (no spaces)
  --keystore <name>     Specify the keystore account to use (bypasses selection prompt)
  --help, -h           Show this help message

Contracts and their dependencies:
  PartnerManager     - No dependencies
  RoboshareTokens    - No dependencies
  RegistryRouter     - 1 dependency:   roboshareTokens
  VehicleRegistry    - 3 dependencies: roboshareTokens,partnerManager,router
  Treasury           - 3 dependencies: roboshareTokens,partnerManager,router
  Marketplace        - 4 dependencies: roboshareTokens,partnerManager,router,treasury

Examples:
  yarn deploy --contract PartnerManager --network sepolia
  yarn deploy --contract Treasury --network sepolia --args 0xTokens,0xPartner,0xRouter
  yarn deploy --contract Marketplace --network sepolia --args 0xTokens,0xPartner,0xRouter,0xTreasury
    `);
  }
  process.exit(0);
}

// Parse arguments
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--network" && args[i + 1]) {
    network = args[i + 1];
    i++; // Skip next arg since we used it
  } else if (args[i] === "--file" && args[i + 1]) {
    fileName = args[i + 1];
    i++; // Skip next arg since we used it
  } else if (args[i] === "--keystore" && args[i + 1]) {
    keystoreArg = args[i + 1];
    i++; // Skip next arg since we used it
  } else if (args[i] === "--contract" && args[i + 1]) {
    contractName = args[i + 1];
    i++; // Skip next arg since we used it
  } else if (args[i] === "--proxy-address" && args[i + 1]) {
    proxyAddress = args[i + 1];
    i++; // Skip next arg since we used it
  } else if (args[i] === "--args" && args[i + 1]) {
    // Parse comma-separated addresses
    sigArgs = args[i + 1].split(",").map((a) => a.trim());
    i++; // Skip next arg since we used it
  }
}

// Handle upgrade-specific logic
if (command === "upgrade") {
  // Validate required arguments
  if (!contractName) {
    console.log(
      "\n❌ Error: --contract argument is required for upgrade command"
    );
    console.log(
      "Usage: yarn upgrade --contract <ContractName> --proxy-address <address>"
    );
    process.exit(1);
  }
  if (!proxyAddress) {
    console.log(
      "\n❌ Error: --proxy-address argument is required for upgrade command"
    );
    console.log(
      "Usage: yarn upgrade --contract <ContractName> --proxy-address <address>"
    );
    process.exit(1);
  }

  // Construct upgrade script filename from contract name
  fileName = `Upgrade${contractName}.s.sol`;
} else if (command === "deploy" && contractName) {
  // Handle contract-specific deployments
  fileName = `Deploy${contractName}.s.sol`;

  // Validate dependencies if contract has them
  const contractConfig = CONTRACT_SIGNATURES[contractName];
  if (contractConfig && contractConfig.sig) {
    const expectedCount = contractConfig.params.length;
    if (sigArgs.length !== expectedCount) {
      console.log(
        `\n❌ Error: ${contractName} requires ${expectedCount} dependency address(es)`
      );
      console.log(`   Dependencies: ${contractConfig.params.join(", ")}`);
      console.log(
        `\nUsage: yarn deploy --contract ${contractName} --network <network> --args ${contractConfig.params
          .map((p) => `<${p}>`)
          .join(",")}`
      );
      process.exit(1);
    }
  }
}

// Function to check if a keystore exists
function validateKeystore(keystoreName) {
  if (keystoreName === "scaffold-eth-default") {
    return true; // Default keystore is always valid
  }

  const keystorePath = join(
    process.env.HOME,
    ".foundry",
    "keystores",
    keystoreName
  );
  return existsSync(keystorePath);
}

// Check if the network exists in rpc_endpoints
try {
  const foundryTomlPath = join(__dirname, "..", "foundry.toml");
  const tomlString = readFileSync(foundryTomlPath, "utf-8");
  const parsedToml = parse(tomlString);

  if (!parsedToml.rpc_endpoints[network]) {
    console.log(
      `\n❌ Error: Network '${network}' not found in foundry.toml!`,
      "\nPlease check `foundry.toml` for available networks in the [rpc_endpoints] section or add a new network."
    );
    process.exit(1);
  }
} catch (error) {
  console.error("\n❌ Error reading or parsing foundry.toml:", error);
  process.exit(1);
}

// Determine which keystore to use
let selectedKeystore =
  process.env.ETH_KEYSTORE_ACCOUNT || "scaffold-eth-default";

// Handle --keystore flag override
if (keystoreArg) {
  if (!validateKeystore(keystoreArg)) {
    console.log(`\n❌ Error: Keystore '${keystoreArg}' not found!`);
    console.log(
      `Please check that the keystore exists in ~/.foundry/keystores/`
    );
    process.exit(1);
  }
  selectedKeystore = keystoreArg;
  console.log(`\n🔑 Using keystore: ${selectedKeystore}`);
} else if (
  network !== "localhost" &&
  selectedKeystore === "scaffold-eth-default"
) {
  // For non-localhost networks, prompt for keystore selection if using default
  try {
    selectedKeystore = await selectOrCreateKeystore();
  } catch (error) {
    console.error("\n❌ Error selecting keystore:", error);
    process.exit(1);
  }
} else if (selectedKeystore !== "scaffold-eth-default") {
  // Using a custom keystore from .env
  if (!validateKeystore(selectedKeystore)) {
    console.log(`\n❌ Error: Keystore '${selectedKeystore}' not found!`);
    console.log(
      `Please check that the keystore exists in ~/.foundry/keystores/`
    );
    process.exit(1);
  }
  console.log(
    `\n🔑 Using keystore from ETH_KEYSTORE_ACCOUNT: ${selectedKeystore}`
  );
}

// Check for default account on live network
if (selectedKeystore === "scaffold-eth-default" && network !== "localhost") {
  console.log(`
❌ Error: Cannot deploy to live network using default keystore account!

To deploy to ${network}, please follow these steps:

1. If you haven't generated a keystore account yet:
   $ yarn generate

2. Run the deployment command again.

The default account (scaffold-eth-default) can only be used for localhost deployments.
`);
  process.exit(0);
}

// Build the --sig argument if contract has dependencies
let sigArg = "";
if (command === "deploy" && contractName) {
  const contractConfig = CONTRACT_SIGNATURES[contractName];
  if (contractConfig && contractConfig.sig && sigArgs.length > 0) {
    sigArg = `--sig "${contractConfig.sig}" ${sigArgs.join(" ")}`;
  }
}

// Set environment variables for the make command
if (command === "upgrade") {
  process.env.DEPLOY_SCRIPT = `script/${fileName}`;
  process.env.PROXY_ADDRESS = proxyAddress;
  process.env.RPC_URL = network;
  process.env.ETH_KEYSTORE_ACCOUNT = selectedKeystore;
  process.env.SCRIPT_SIG_ARGS = "";

  const result = spawnSync("make", ["deploy-and-generate-abis"], {
    stdio: "inherit",
    shell: true,
  });

  process.exit(result.status);
} else {
  // Deploy command
  process.env.DEPLOY_SCRIPT = `script/${fileName}`;
  process.env.RPC_URL = network;
  process.env.ETH_KEYSTORE_ACCOUNT = selectedKeystore;
  process.env.SCRIPT_SIG_ARGS = sigArg;

  const result = spawnSync("make", ["deploy-and-generate-abis"], {
    stdio: "inherit",
    shell: true,
  });

  process.exit(result.status);
}
