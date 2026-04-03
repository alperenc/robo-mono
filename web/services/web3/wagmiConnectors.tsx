import { connectorsForWallets } from "@rainbow-me/rainbowkit";
import {
  coinbaseWallet,
  ledgerWallet,
  metaMaskWallet,
  rabbyWallet,
  rainbowWallet,
  safeWallet,
  walletConnectWallet,
} from "@rainbow-me/rainbowkit/wallets";
import { rainbowkitBurnerWallet } from "burner-connector";
import * as chains from "viem/chains";
import scaffoldConfig from "~~/scaffold.config";

const { onlyLocalBurnerWallet, targetNetworks } = scaffoldConfig;
const LOCAL_CHAIN_ID = chains.foundry.id;
const burnerWallets =
  !targetNetworks.some(network => network.id !== LOCAL_CHAIN_ID) || !onlyLocalBurnerWallet
    ? ([rainbowkitBurnerWallet] as unknown as (typeof metaMaskWallet)[])
    : [];

const wallets = [
  metaMaskWallet,
  walletConnectWallet,
  ledgerWallet,
  coinbaseWallet,
  rabbyWallet,
  rainbowWallet,
  safeWallet,
  ...burnerWallets,
];

/**
 * wagmi connectors for the wagmi context
 */
export const getWagmiConnectors = () =>
  connectorsForWallets(
    [
      {
        groupName: "Supported Wallets",
        wallets,
      },
    ],

    {
      appName: "Roboshare",
      projectId: scaffoldConfig.walletConnectProjectId,
    },
  );
