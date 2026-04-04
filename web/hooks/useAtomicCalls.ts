"use client";

import { useCallback, useMemo, useState } from "react";
import { useSmartWallets } from "@privy-io/react-auth/smart-wallets";
import { type WaitForCallsStatusReturnType, waitForCallsStatus, waitForTransactionReceipt } from "@wagmi/core";
import { Address, Hex } from "viem";
import { useAccount, useCapabilities, useConfig, useSendCalls } from "wagmi";
import { isPrivyEnabled } from "~~/services/web3/privyConfig";

export type AtomicCall = {
  data?: Hex;
  to?: Address;
  value?: bigint;
};

type SendAtomicCallsParameters = {
  calls: readonly AtomicCall[];
  timeout?: number;
};

type AtomicCallsState = {
  capabilities: unknown;
  isPending: boolean;
  reset: () => void;
  sendAtomicCalls: (params: SendAtomicCallsParameters) => Promise<WaitForCallsStatusReturnType>;
  supportsAtomicBatch: boolean;
  supportsPaymasterService: boolean;
  transactingAddress?: Address;
};

type SmartWalletAtomicClient = {
  account?: { address?: Address };
  chain?: { id: number };
  paymaster?: unknown;
  switchChain?: (args: { id: number }) => Promise<void>;
  sendTransaction: (params: { calls: readonly AtomicCall[] }) => Promise<Hex>;
};

const useAtomicCallsBase = (smartWalletClient?: SmartWalletAtomicClient) => {
  const config = useConfig();
  const { address, chainId, connector } = useAccount();
  const [isSmartWalletPending, setIsSmartWalletPending] = useState(false);
  const { data: capabilities } = useCapabilities({
    account: address,
    chainId,
    connector,
    query: {
      enabled: !!address && !!chainId && !!connector,
      retry: false,
    },
  });
  const { sendCallsAsync, isPending, reset } = useSendCalls();
  const connectedCapabilities = capabilities as
    | {
        atomic?: { status: "supported" | "ready" | "unsupported" };
        paymasterService?: { supported: boolean };
      }
    | undefined;

  const atomicStatus = connectedCapabilities?.atomic?.status;
  const supportsAtomicBatch = Boolean(smartWalletClient) || atomicStatus === "ready" || atomicStatus === "supported";
  const supportsPaymasterService =
    Boolean(smartWalletClient?.paymaster) || connectedCapabilities?.paymasterService?.supported === true;
  const transactingAddress = (smartWalletClient?.account?.address as Address | undefined) ?? address;

  const sendAtomicCalls = useCallback(
    async ({ calls, timeout = 120_000 }: SendAtomicCallsParameters) => {
      if (smartWalletClient) {
        const desiredChainId = chainId ?? smartWalletClient.chain?.id;

        if (!desiredChainId) {
          throw new Error("Smart wallet is not configured on the active network");
        }

        if (smartWalletClient.chain?.id !== desiredChainId) {
          await smartWalletClient.switchChain?.({ id: desiredChainId });
        }

        setIsSmartWalletPending(true);

        try {
          const hash = await smartWalletClient.sendTransaction({
            calls: calls.map(call => ({
              data: call.data,
              to: call.to,
              value: call.value,
            })) as never,
          });

          const receipt = await waitForTransactionReceipt(config, {
            chainId: desiredChainId,
            hash,
            timeout,
          });

          return {
            atomic: true,
            chainId: desiredChainId,
            id: hash,
            receipts: [receipt],
            status: receipt.status === "success" ? "success" : "failure",
            statusCode: receipt.status === "success" ? 200 : 500,
            version: "privy-smart-wallet",
          } as unknown as WaitForCallsStatusReturnType;
        } finally {
          setIsSmartWalletPending(false);
        }
      }

      if (!address || !chainId) {
        throw new Error("Please connect your wallet");
      }

      if (!supportsAtomicBatch) {
        throw new Error("Connected wallet does not support atomic batched calls");
      }

      const result = await sendCallsAsync({
        account: address,
        chainId,
        connector,
        calls: calls as never,
        forceAtomic: true,
      });

      return waitForCallsStatus(config, {
        connector,
        id: result.id,
        timeout,
      });
    },
    [address, chainId, config, connector, sendCallsAsync, smartWalletClient, supportsAtomicBatch],
  );

  return useMemo(
    () => ({
      capabilities,
      isPending: isPending || isSmartWalletPending,
      reset,
      sendAtomicCalls,
      supportsAtomicBatch,
      supportsPaymasterService,
      transactingAddress,
    }),
    [
      capabilities,
      isPending,
      isSmartWalletPending,
      reset,
      sendAtomicCalls,
      supportsAtomicBatch,
      supportsPaymasterService,
      transactingAddress,
    ],
  );
};

const useAtomicCallsWithPrivy = () => {
  const { client } = useSmartWallets();
  return useAtomicCallsBase(client as SmartWalletAtomicClient | undefined);
};

const useAtomicCallsWithoutPrivy = () => useAtomicCallsBase();

const useAtomicCallsImpl = isPrivyEnabled() ? useAtomicCallsWithPrivy : useAtomicCallsWithoutPrivy;

export const useAtomicCalls = (): AtomicCallsState => useAtomicCallsImpl();
