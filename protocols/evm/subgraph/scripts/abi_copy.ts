import * as fs from "fs";
import chalk from "chalk";

const parseAndCorrectJSON = (input: string): any => {
  // Add double quotes around keys
  let correctedJSON = input.replace(/(\w+)(?=\s*:)/g, '"$1"');

  // Remove trailing commas
  correctedJSON = correctedJSON.replace(/,(?=\s*[}\]])/g, "");

  try {
    return JSON.parse(correctedJSON);
  } catch (error) {
    console.error("Failed to parse JSON", error);
    throw new Error("Failed to parse JSON");
  }
};

type Contract = {
  address: string;
  abi: any[];
};

const DEFAULT_CHAIN_ID = 31337;
const DEFAULT_NETWORKS_BY_CHAIN_ID: Record<number, string> = {
  31337: "localhost",
  11155111: "sepolia",
};

const GRAPH_DIR = "./";

function publishContract(
  contractName: string,
  contractObject: Contract,
  networkName: string
) {
  try {
    const graphConfigPath = `${GRAPH_DIR}/networks.json`;
    let graphConfig = "{}";
    try {
      if (fs.existsSync(graphConfigPath)) {
        graphConfig = fs.readFileSync(graphConfigPath).toString();
      }
    } catch (e) {
      console.log(e);
    }

    let graphConfigObject = JSON.parse(graphConfig);
    if (!(networkName in graphConfigObject)) {
      graphConfigObject[networkName] = {};
    }
    if (!(contractName in graphConfigObject[networkName])) {
      graphConfigObject[networkName][contractName] = {};
    }
    graphConfigObject[networkName][contractName].address =
      contractObject.address;

    fs.writeFileSync(
      graphConfigPath,
      JSON.stringify(graphConfigObject, null, 2)
    );
    if (!fs.existsSync(`${GRAPH_DIR}/abis`)) fs.mkdirSync(`${GRAPH_DIR}/abis`);
    const abiContent = JSON.stringify(contractObject.abi, null, 2);
    fs.writeFileSync(`${GRAPH_DIR}/abis/${contractName}.json`, abiContent);

    return true;
  } catch (e) {
    console.log(
      "Failed to publish " + chalk.red(contractName) + " to the subgraph."
    );
    console.log(e);
    return false;
  }
}

const DEPLOYED_CONTRACTS_FILE = "../../../web/contracts/deployedContracts.ts";

function parseCliArgs() {
  const args = process.argv.slice(2);
  let chainIdArg: number | undefined;
  let networkArg: string | undefined;

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    if ((arg === "--chain-id" || arg === "-c") && args[i + 1]) {
      chainIdArg = Number.parseInt(args[i + 1] as string, 10);
      i++;
      continue;
    }

    if ((arg === "--network" || arg === "-n") && args[i + 1]) {
      networkArg = args[i + 1];
      i++;
    }
  }

  const chainId =
    chainIdArg ??
    (process.env.SUBGRAPH_CHAIN_ID ? Number.parseInt(process.env.SUBGRAPH_CHAIN_ID, 10) : undefined) ??
    DEFAULT_CHAIN_ID;

  if (!Number.isInteger(chainId)) {
    throw new Error(`Invalid chain id: ${chainId}`);
  }

  const networkName =
    networkArg ?? process.env.SUBGRAPH_NETWORK ?? DEFAULT_NETWORKS_BY_CHAIN_ID[chainId];

  if (!networkName) {
    throw new Error(
      `No subgraph network name provided for chain ${chainId}. Pass --network <graph-network> or set SUBGRAPH_NETWORK.`
    );
  }

  return { chainId, networkName };
}

async function main() {
  const { chainId, networkName } = parseCliArgs();
  const fileContent = fs.readFileSync(DEPLOYED_CONTRACTS_FILE, "utf8");

  const pattern = /const deployedContracts = ({[^;]+}) as const;/s;
  const match = fileContent.match(pattern);

  if (!match || !match[1]) {
    throw new Error(
      `Failed to find deployedContracts in the ${DEPLOYED_CONTRACTS_FILE}`
    );
  }
  const jsonString = match[1];

  // Parse the JSON string
  const deployedContracts = parseAndCorrectJSON(jsonString);
  const targetContracts = deployedContracts[chainId];

  if (!targetContracts) {
    const availableChainIds = Object.keys(deployedContracts)
      .filter(key => Number.isInteger(Number.parseInt(key, 10)))
      .join(", ");
    console.error(
      `No contracts found for chain ${chainId}. Available chain ids in deployedContracts.ts: ${availableChainIds || "none"}`
    );
    return;
  }

  for (const contractName in targetContracts) {
    const contractObject = targetContracts[contractName];
    if (!contractObject) {
      console.error(
        `Contract ${contractName} does not have an ABI or address. Skipping.`
      );
      continue;
    }
    publishContract(contractName, contractObject, networkName);
  }

  console.log(`✅  Published contracts for chain ${chainId} to the subgraph package as ${networkName}.`);
}
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
