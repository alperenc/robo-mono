"use client";

import { type ReactNode, createContext, useContext } from "react";
import { useSmartWallets } from "@privy-io/react-auth/smart-wallets";
import type { Address, Hash, Hex } from "viem";
import { useAccount } from "wagmi";

type SmartWalletCall = {
  data?: Hex;
  to?: Address;
  value?: bigint;
};

type SmartWalletClient = {
  account?: { address?: Address };
  chain?: { id: number };
  sendTransaction: (params: { calls: readonly SmartWalletCall[] }) => Promise<Hash>;
};

type TransactingAccountState = {
  address?: Address;
  chainId?: number;
  connectedAddress?: Address;
  connectedChainId?: number;
  isSmartWallet: boolean;
  smartWalletClient?: SmartWalletClient;
};

const TransactingAccountContext = createContext<TransactingAccountState>({
  address: undefined,
  chainId: undefined,
  connectedAddress: undefined,
  connectedChainId: undefined,
  isSmartWallet: false,
});

const DefaultTransactingAccountProvider = ({ children }: { children: ReactNode }) => {
  const { address, chainId } = useAccount();

  return (
    <TransactingAccountContext.Provider
      value={{
        address,
        chainId,
        connectedAddress: address,
        connectedChainId: chainId,
        isSmartWallet: false,
        smartWalletClient: undefined,
      }}
    >
      {children}
    </TransactingAccountContext.Provider>
  );
};

const PrivyTransactingAccountProvider = ({ children }: { children: ReactNode }) => {
  const { address: connectedAddress, chainId: connectedChainId } = useAccount();
  const { client: smartWalletClient } = useSmartWallets();
  const address = (smartWalletClient?.account?.address as Address | undefined) ?? connectedAddress;
  const chainId = smartWalletClient?.chain?.id ?? connectedChainId;

  return (
    <TransactingAccountContext.Provider
      value={{
        address,
        chainId,
        connectedAddress,
        connectedChainId,
        isSmartWallet: Boolean(smartWalletClient),
        smartWalletClient: smartWalletClient as SmartWalletClient | undefined,
      }}
    >
      {children}
    </TransactingAccountContext.Provider>
  );
};

export const TransactingAccountProvider = ({
  children,
  privyEnabled,
}: {
  children: ReactNode;
  privyEnabled: boolean;
}) => {
  if (privyEnabled) {
    return <PrivyTransactingAccountProvider>{children}</PrivyTransactingAccountProvider>;
  }

  return <DefaultTransactingAccountProvider>{children}</DefaultTransactingAccountProvider>;
};

export const useTransactingAccount = () => useContext(TransactingAccountContext);
