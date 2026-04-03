import type { PrivyClientConfig } from "@privy-io/react-auth";
import { mainnet } from "viem/chains";
import scaffoldConfig from "~~/scaffold.config";

const { targetNetworks, walletConnectProjectId } = scaffoldConfig;

export const enabledPrivyChains = targetNetworks.find(network => network.id === mainnet.id)
  ? targetNetworks
  : [...targetNetworks, mainnet];

export const getPrivyAppId = () => process.env.NEXT_PUBLIC_PRIVY_APP_ID;

export const isPrivyEnabled = () => Boolean(getPrivyAppId());

export const getPrivyConfig = (theme: "light" | "dark"): PrivyClientConfig => ({
  appearance: {
    theme,
    accentColor: "#2299dd",
    showWalletLoginFirst: false,
    landingHeader: "Roboshare",
    loginMessage: "Access tokenized markets with an embedded wallet or your existing wallet.",
  },
  // Work around a missing-key warning in Privy's default landing screen renderer by
  // using the ordered-login variant instead.
  loginMethodsAndOrder: {
    primary: ["email", "google", "detected_ethereum_wallets"],
    overflow: ["wallet_connect"],
  },
  walletConnectCloudProjectId: walletConnectProjectId,
  supportedChains: [...enabledPrivyChains],
  defaultChain: enabledPrivyChains[0],
  embeddedWallets: {
    ethereum: {
      createOnLogin: "users-without-wallets",
    },
  },
});
