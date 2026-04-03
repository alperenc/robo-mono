"use client";

import { useCallback, useMemo, useState } from "react";
import { useSmartWallets } from "@privy-io/react-auth/smart-wallets";
import { type WaitForCallsStatusReturnType, waitForCallsStatus, waitForTransactionReceipt } from "@wagmi/core";
import { Address, Hex } from "viem";
import { useAccount, useCapabilities, useConfig, useSendCalls } from "wagmi";

export type AtomicCall = {
  data?: Hex;
  to?: Address;
  value?: bigint;
};

type SendAtomicCallsParameters = {
  calls: readonly AtomicCall[];
  timeout?: number;
};

export const useAtomicCalls = () => {
  const config = useConfig();
  const { address, chainId, connector } = useAccount();
  const { client: smartWalletClient } = useSmartWallets();
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
            chainId: smartWalletClient.chain.id,
            hash,
            timeout,
          });

          return {
            atomic: true,
            chainId: smartWalletClient.chain.id,
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
