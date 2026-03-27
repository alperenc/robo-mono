import * as fs from "fs";

const DEFAULT_NETWORK = "localhost";
const MANIFEST_TEMPLATE_FILE = "./subgraph.yaml";
const NETWORKS_FILE = "./networks.json";
const RENDERED_MANIFEST_FILE = "./subgraph.rendered.yaml";

function parseCliArgs() {
  const args = process.argv.slice(2);
  let networkArg: string | undefined;

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    if ((arg === "--network" || arg === "-n") && args[i + 1]) {
      networkArg = args[i + 1];
      i++;
    }
  }

  return {
    networkName: networkArg ?? process.env.SUBGRAPH_NETWORK ?? DEFAULT_NETWORK,
  };
}

function main() {
  const { networkName } = parseCliArgs();
  const manifestTemplate = fs.readFileSync(MANIFEST_TEMPLATE_FILE, "utf8");
  const networks = JSON.parse(fs.readFileSync(NETWORKS_FILE, "utf8")) as Record<
    string,
    Record<string, { address?: string; startBlock?: number }>
  >;

  const networkConfig = networks[networkName];
  if (!networkConfig) {
    throw new Error(`No subgraph network config found for '${networkName}'.`);
  }

  let renderedManifest = manifestTemplate.replace(/{{\s*network\s*}}/g, networkName);

  for (const [contractName, contractConfig] of Object.entries(networkConfig)) {
    if (!contractConfig.address) {
      throw new Error(`Missing address for ${contractName} on network '${networkName}'.`);
    }

    if (!Number.isInteger(contractConfig.startBlock)) {
      throw new Error(`Missing startBlock for ${contractName} on network '${networkName}'.`);
    }

    renderedManifest = renderedManifest.replace(
      new RegExp(`{{\\s*${contractName}\\.address\\s*}}`, "g"),
      contractConfig.address
    );
    renderedManifest = renderedManifest.replace(
      new RegExp(`{{\\s*${contractName}\\.startBlock\\s*}}`, "g"),
      String(contractConfig.startBlock)
    );
  }

  fs.writeFileSync(RENDERED_MANIFEST_FILE, renderedManifest);
  console.log(`✅  Rendered subgraph manifest for ${networkName} at ${RENDERED_MANIFEST_FILE}.`);
}

main();
