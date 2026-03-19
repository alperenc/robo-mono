const LOCAL_SUBGRAPH_QUERY_URL = "http://localhost:8000/subgraphs/name/roboshare/protocol";

const CHAIN_SUBGRAPH_URLS: Record<number, string | undefined> = {
  31337: process.env.NEXT_PUBLIC_SUBGRAPH_URL_31337 || LOCAL_SUBGRAPH_QUERY_URL,
  11155111: process.env.NEXT_PUBLIC_SUBGRAPH_URL_11155111,
  80002: process.env.NEXT_PUBLIC_SUBGRAPH_URL_80002,
  421614: process.env.NEXT_PUBLIC_SUBGRAPH_URL_421614,
  84532: process.env.NEXT_PUBLIC_SUBGRAPH_URL_84532,
};

const normalizeSubgraphQueryUrl = (url: string) => url.replace(/\/graphql\/?$/, "");

export const getSubgraphQueryUrl = (chainId: number | undefined): string | undefined => {
  if (!chainId) {
    return LOCAL_SUBGRAPH_QUERY_URL;
  }

  const configuredUrl = CHAIN_SUBGRAPH_URLS[chainId];
  return configuredUrl ? normalizeSubgraphQueryUrl(configuredUrl) : undefined;
};

export const getSubgraphGraphiqlUrl = (chainId: number | undefined): string | undefined => {
  const queryUrl = getSubgraphQueryUrl(chainId);
  return queryUrl ? `${queryUrl}/graphql` : undefined;
};
