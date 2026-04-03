"use client";

import { Abi, Address, Hex, encodeFunctionData } from "viem";
import { useSelectedNetwork } from "~~/hooks/scaffold-eth";
import { useAtomicCalls } from "~~/hooks/useAtomicCalls";
import { usePaymentToken } from "~~/hooks/usePaymentToken";
import { getDeployedContract } from "~~/utils/contracts";
import { notification } from "~~/utils/scaffold-eth";

type MintMockTokenParams = {
  recipient?: Address;
  amount: bigint;
};

type MintMockTokenResult = {
  recipient: Address;
  transactionHash?: Hex;
};

export const useMockTokenFaucetMint = () => {
  const selectedNetwork = useSelectedNetwork();
  const { address: paymentTokenAddress, isMockToken } = usePaymentToken();
  const { isPending, sendAtomicCalls, supportsAtomicBatch, supportsPaymasterService, transactingAddress } =
    useAtomicCalls();
  const mockTokenContract = getDeployedContract(selectedNetwork.id, "MockUSDC");

  const mintMockToken = async ({
    recipient,
    amount,
  }: MintMockTokenParams): Promise<MintMockTokenResult | undefined> => {
    const targetRecipient = recipient ?? transactingAddress;

    if (!isMockToken || !paymentTokenAddress || !mockTokenContract) {
      notification.error("Mock payment token is not configured on this network.");
      return;
    }

    if (!targetRecipient) {
      notification.error("Log in to create a smart wallet before using the sponsored faucet.");
      return;
    }

    if (!supportsAtomicBatch) {
      notification.error("Log in with the embedded smart wallet to use the sponsored faucet on this network.");
      return;
    }

    if (!supportsPaymasterService) {
      notification.error("Gas sponsorship is not available for the connected smart wallet on this network.");
      return;
    }

    const batchStatus = await sendAtomicCalls({
      calls: [
        {
          to: paymentTokenAddress,
          data: encodeFunctionData({
            abi: mockTokenContract.abi as Abi,
            functionName: "mint",
            args: [targetRecipient, amount],
          }),
        },
      ],
    });

    if (batchStatus.status !== "success") {
      throw new Error("Test funds request did not complete successfully.");
    }

    const transactionHash = (batchStatus.receipts?.[0] as { transactionHash?: Hex } | undefined)?.transactionHash;

    return {
      recipient: targetRecipient,
      transactionHash,
    };
  };

  return {
    isPending,
    mintMockToken,
    transactingAddress,
  };
};
