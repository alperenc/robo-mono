import { config } from "dotenv";
import { dirname, join } from "path";
import { fileURLToPath } from "url";
import { parseScriptSelectionArgs, runMakeTarget } from "./cliUtils.js";

const __dirname = dirname(fileURLToPath(import.meta.url));
config({ path: join(__dirname, "..", ".env") });

const args = process.argv.slice(2);
const { network, help } = parseScriptSelectionArgs(args, {
  defaultNetwork: "mainnet",
  allowRpcUrl: true,
});

if (help) {
  console.log(`
Usage: yarn fork [network-or-rpc-url] [options]
Options:
  --network <network>   Specify the RPC alias or full RPC URL (default: mainnet)
  --help, -h            Show this help message

Examples:
  yarn fork
  yarn fork sepolia
  yarn fork --network https://eth-mainnet.g.alchemy.com/v2/<key>
  `);
  process.exit(0);
}

runMakeTarget("fork", {
  FORK_URL: network,
});
