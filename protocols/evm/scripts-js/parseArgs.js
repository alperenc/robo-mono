import { spawnSync } from "child_process";
import { config } from "dotenv";
import { join, dirname } from "path";
import { readFileSync, existsSync } from "fs";
import { parse } from "toml";
import { fileURLToPath } from "url";
import { selectOrCreateKeystore } from "./selectOrCreateKeystore.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
config();

// Get all arguments after the script name
const args = process.argv.slice(2);

// Detect command type from package.json script name
const command = process.env.npm_lifecycle_event || 'deploy';

let fileName = "Deploy.s.sol";
let network = "localhost";
let keystoreArg = null;
let contractName = null;
let proxyAddress = null;
let tokensAddress = null;
let authorizedContract = null;

// Show help message if --help is provided
if (args.includes("--help") || args.includes("-h")) {
  if (command === 'upgrade') {
    console.log(`
Usage: yarn upgrade [options]
Options:
  --contract <name>         Specify the contract to upgrade (required)
  --proxy-address <addr>    Specify the proxy contract address (required)
  --network <network>       Specify the network (default: localhost)
  --keystore <name>         Specify the keystore account to use (bypasses selection prompt)
  --tokens-address <addr>   Specify tokens contract address (script-specific)
  --authorized-contract <addr>  Specify authorized contract address (script-specific)
  --help, -h               Show this help message
Examples:
  yarn upgrade --contract VehicleRegistry --proxy-address 0x3dc1ec9c2867fd75f63f089b5c9760b3d259e07d
  yarn upgrade --contract Treasury --proxy-address 0x123... --tokens-address 0x456... --authorized-contract 0x789...
  yarn upgrade --contract VehicleRegistry --proxy-address 0x3dc1ec9c2867fd75f63f089b5c9760b3d259e07d --network sepolia
    `);
  } else {
    console.log(`
Usage: yarn deploy [options]
Options:
  --file <filename>     Specify the deployment script file (default: Deploy.s.sol)
  --network <network>   Specify the network (default: localhost)
  --keystore <name>     Specify the keystore account to use (bypasses selection prompt)
  --help, -h           Show this help message
Examples:
  yarn deploy --file DeployYourContract.s.sol --network sepolia
  yarn deploy --network sepolia --keystore my-account
  yarn deploy --file DeployYourContract.s.sol
  yarn deploy
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
  } else if (args[i] === "--tokens-address" && args[i + 1]) {
    tokensAddress = args[i + 1];
    i++; // Skip next arg since we used it
  } else if (args[i] === "--authorized-contract" && args[i + 1]) {
    authorizedContract = args[i + 1];
    i++; // Skip next arg since we used it
  }
}

// Handle upgrade-specific logic
if (command === 'upgrade') {
  // Validate required arguments
  if (!contractName) {
    console.log('\n❌ Error: --contract argument is required for upgrade command');
    console.log('Usage: yarn upgrade --contract <ContractName> --proxy-address <address>');
    process.exit(1);
  }
  if (!proxyAddress) {
    console.log('\n❌ Error: --proxy-address argument is required for upgrade command');
    console.log('Usage: yarn upgrade --contract <ContractName> --proxy-address <address>');
    process.exit(1);
  }
  
  // Construct upgrade script filename from contract name
  fileName = `Upgrade${contractName}.s.sol`;
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

if (
  process.env.LOCALHOST_KEYSTORE_ACCOUNT !== "scaffold-eth-default" &&
  network === "localhost"
) {
  console.log(`
⚠️ Warning: Using ${process.env.LOCALHOST_KEYSTORE_ACCOUNT} keystore account on localhost.

You can either:
1. Enter the password for ${process.env.LOCALHOST_KEYSTORE_ACCOUNT} account
   OR
2. Set the localhost keystore account in your .env and re-run the command to skip password prompt:
   LOCALHOST_KEYSTORE_ACCOUNT='scaffold-eth-default'
`);
}

let selectedKeystore = process.env.LOCALHOST_KEYSTORE_ACCOUNT;
if (network !== "localhost") {
  if (keystoreArg) {
    // Use the keystore provided via command line argument
    if (!validateKeystore(keystoreArg)) {
      console.log(`\n❌ Error: Keystore '${keystoreArg}' not found!`);
      console.log(
        `Please check that the keystore exists in ~/.foundry/keystores/`
      );
      process.exit(1);
    }
    selectedKeystore = keystoreArg;
    console.log(`\n🔑 Using keystore: ${selectedKeystore}`);
  } else {
    try {
      selectedKeystore = await selectOrCreateKeystore();
    } catch (error) {
      console.error("\n❌ Error selecting keystore:", error);
      process.exit(1);
    }
  }
} else if (keystoreArg) {
  // Allow overriding the localhost keystore with --keystore flag
  if (!validateKeystore(keystoreArg)) {
    console.log(`\n❌ Error: Keystore '${keystoreArg}' not found!`);
    console.log(
      `Please check that the keystore exists in ~/.foundry/keystores/`
    );
    process.exit(1);
  }
  selectedKeystore = keystoreArg;
  console.log(
    `\n🔑 Using keystore: ${selectedKeystore} for localhost deployment`
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

// Set environment variables for the make command
if (command === 'upgrade') {
  process.env.DEPLOY_SCRIPT = `script/${fileName}`;
  process.env.PROXY_ADDRESS = proxyAddress;
  process.env.RPC_URL = network;
  process.env.ETH_KEYSTORE_ACCOUNT = selectedKeystore;
  
  // Set optional script-specific environment variables
  if (tokensAddress) {
    process.env.TOKENS_ADDRESS = tokensAddress;
  }
  if (authorizedContract) {
    process.env.AUTHORIZED_CONTRACT_ADDRESS = authorizedContract;
  }
  
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

  const result = spawnSync("make", ["deploy-and-generate-abis"], {
    stdio: "inherit",
    shell: true,
  });

  process.exit(result.status);
}
