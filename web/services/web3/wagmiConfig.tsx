import { getWagmiConnectors } from "./wagmiConnectors";
import { Chain, createClient, fallback, http } from "viem";
import { foundry, mainnet } from "viem/chains";
import { Config, createConfig } from "wagmi";
import scaffoldConfig, { DEFAULT_ALCHEMY_API_KEY, ScaffoldConfig } from "~~/scaffold.config";
import { getRuntimeLocalChain } from "~~/utils/localServiceUrls";
import { getAlchemyHttpUrl } from "~~/utils/scaffold-eth";

const { targetNetworks } = scaffoldConfig;

// We always want to have mainnet enabled (ENS resolution, ETH price, etc). But only once.
export const enabledChains = targetNetworks.find((network: Chain) => network.id === 1)
  ? targetNetworks
  : [...targetNetworks, mainnet];

let wagmiConfigSingleton: Config | undefined;

export const getWagmiConfig = () => {
  if (wagmiConfigSingleton) {
    return wagmiConfigSingleton;
  }

  const runtimeEnabledChains = enabledChains.map(chain =>
    chain.id === foundry.id ? getRuntimeLocalChain() : chain,
  ) as [Chain, ...Chain[]];

  wagmiConfigSingleton = createConfig({
    chains: runtimeEnabledChains,
    connectors: getWagmiConnectors(),
    ssr: true,
    client({ chain }) {
      let rpcFallbacks = [http()];

      const rpcOverrideUrl = (scaffoldConfig.rpcOverrides as ScaffoldConfig["rpcOverrides"])?.[chain.id];
      if (rpcOverrideUrl) {
        rpcFallbacks = [http(rpcOverrideUrl), http()];
      } else {
        const alchemyHttpUrl = getAlchemyHttpUrl(chain.id);
        if (alchemyHttpUrl) {
          const isUsingDefaultKey = scaffoldConfig.alchemyApiKey === DEFAULT_ALCHEMY_API_KEY;
          // If using default Scaffold-ETH 2 API key, we prioritize the default RPC
          rpcFallbacks = isUsingDefaultKey ? [http(), http(alchemyHttpUrl)] : [http(alchemyHttpUrl), http()];
        }
      }

      return createClient({
        chain,
        transport: fallback(rpcFallbacks),
        ...(chain.id !== (foundry as Chain).id
          ? {
              pollingInterval: scaffoldConfig.pollingInterval,
            }
          : {}),
      });
    },
  });

  return wagmiConfigSingleton;
};

export const wagmiConfig = getWagmiConfig();
