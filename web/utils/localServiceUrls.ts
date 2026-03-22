import { Chain, foundry } from "viem/chains";

const normalizeBaseHost = (value: string) => {
  const trimmed = value.trim().replace(/\/+$/, "");
  if (!trimmed) return "";
  return /^https?:\/\//.test(trimmed) ? trimmed : `http://${trimmed}`;
};

const toWsBase = (value: string) => {
  if (value.startsWith("https://")) return `wss://${value.slice("https://".length)}`;
  if (value.startsWith("http://")) return `ws://${value.slice("http://".length)}`;
  return `ws://${value}`;
};

const buildUrl = (base: string | undefined, port: number, path = "") => {
  if (!base) return undefined;
  const normalized = normalizeBaseHost(base);
  if (!normalized) return undefined;
  return `${normalized}:${port}${path}`;
};

const buildWsUrl = (base: string | undefined, port: number, path = "") => {
  if (!base) return undefined;
  const normalized = toWsBase(base.trim().replace(/\/+$/, ""));
  return `${normalized}:${port}${path}`;
};

const getRuntimeLocalDevHost = () => {
  if (typeof window !== "undefined" && window.location.hostname) {
    return window.location.hostname;
  }

  return undefined;
};

export const getLocalRpcUrl = () => buildUrl(getRuntimeLocalDevHost(), 8545);

export const getLocalWsRpcUrl = () => buildWsUrl(getRuntimeLocalDevHost(), 8545);

export const getLocalSubgraphUrl = () =>
  process.env.NEXT_PUBLIC_SUBGRAPH_URL_31337 ||
  buildUrl(getRuntimeLocalDevHost(), 8000, "/subgraphs/name/roboshare/protocol");

export const getLocalIpfsGatewayUrl = () =>
  process.env.NEXT_PUBLIC_IPFS_GATEWAY || buildUrl(getRuntimeLocalDevHost(), 8080, "/ipfs/");

export const getRuntimeLocalChain = (): Chain => {
  const localRpcUrl = getLocalRpcUrl();
  const localWsRpcUrl = getLocalWsRpcUrl();

  if (!localRpcUrl) {
    return foundry;
  }

  return {
    ...foundry,
    rpcUrls: {
      default: {
        http: [localRpcUrl],
        ...(localWsRpcUrl ? { webSocket: [localWsRpcUrl] } : {}),
      },
      public: {
        http: [localRpcUrl],
        ...(localWsRpcUrl ? { webSocket: [localWsRpcUrl] } : {}),
      },
    },
  };
};
