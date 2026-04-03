"use client";

import { useMemo, useState } from "react";
import { createWalletClient, erc20Abi, http, parseEther, parseUnits } from "viem";
import { hardhat } from "viem/chains";
import { useAccount } from "wagmi";
import { BanknotesIcon } from "@heroicons/react/24/outline";
import { TestFundsNotification } from "~~/components/scaffold-eth/TestFundsNotification";
import { useTransactor } from "~~/hooks/scaffold-eth";
import { useWatchBalance } from "~~/hooks/scaffold-eth/useWatchBalance";
import { useMockTokenFaucetMint } from "~~/hooks/useMockTokenFaucetMint";
import { usePaymentToken } from "~~/hooks/usePaymentToken";
import { getLocalRpcUrl, getRuntimeLocalChain } from "~~/utils/localServiceUrls";
import { getBlockExplorerTxLink, notification } from "~~/utils/scaffold-eth";

// Number of ETH faucet sends to an address
const NUM_OF_ETH = "1";
const NUM_OF_PAYMENT_TOKEN = "10";
const FAUCET_ADDRESS = "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f";

/**
 * FaucetButton button which lets you grab eth.
 */
export const FaucetButton = () => {
  const { address, chain: ConnectedChain } = useAccount();
  const isLocalChain = ConnectedChain?.id === hardhat.id;
  const {
    address: paymentTokenAddress,
    symbol: paymentTokenSymbol,
    decimals: paymentTokenDecimals,
    isMockToken,
  } = usePaymentToken();
  const { isPending: isMintingMockToken, mintMockToken, transactingAddress } = useMockTokenFaucetMint();
  const localWalletClient = useMemo(
    () =>
      createWalletClient({
        chain: getRuntimeLocalChain(),
        transport: http(getLocalRpcUrl()),
      }),
    [],
  );

  const { data: balance } = useWatchBalance({ address });

  const [loading, setLoading] = useState(false);

  const faucetTxn = useTransactor(localWalletClient);

  const sendFunds = async () => {
    if (!address) return;
    try {
      setLoading(true);
      if (isLocalChain) {
        await faucetTxn({
          account: FAUCET_ADDRESS,
          to: address,
          value: parseEther(NUM_OF_ETH),
        });
      }
      if (paymentTokenAddress) {
        if (isLocalChain) {
          await faucetTxn(() =>
            localWalletClient.writeContract({
              address: paymentTokenAddress,
              abi: erc20Abi,
              functionName: "transfer",
              args: [address, parseUnits(NUM_OF_PAYMENT_TOKEN, paymentTokenDecimals)],
              account: FAUCET_ADDRESS,
            }),
          );
        } else if (isMockToken) {
          const mintResult = await mintMockToken({
            recipient: transactingAddress ?? address,
            amount: parseUnits(NUM_OF_PAYMENT_TOKEN, paymentTokenDecimals),
          });

          if (mintResult) {
            notification.success(
              <TestFundsNotification
                message={`Added ${NUM_OF_PAYMENT_TOKEN} demo ${paymentTokenSymbol}.`}
                recipientAddress={mintResult.recipient}
                blockExplorerLink={
                  mintResult.transactionHash && ConnectedChain?.id
                    ? getBlockExplorerTxLink(ConnectedChain.id, mintResult.transactionHash)
                    : undefined
                }
              />,
              { icon: "🎉", duration: 5000 },
            );
          }
        }
      }
      setLoading(false);
    } catch (error) {
      notification.error(
        error instanceof Error && /fetch|network|connection|socket/i.test(error.message)
          ? "Cannot connect to the local faucet chain."
          : "Could not add test funds.",
      );
      console.error("⚡️ ~ file: FaucetButton.tsx:sendETH ~ error", error);
      setLoading(false);
    }
  };

  if (!isLocalChain && !isMockToken) {
    return null;
  }

  const isBalanceZero = balance && balance.value === 0n;
  const isBusy = loading || isMintingMockToken;

  return (
    <div
      className={
        !isBalanceZero
          ? "ml-1"
          : "ml-1 tooltip tooltip-bottom tooltip-primary tooltip-open font-bold before:left-auto before:transform-none before:content-[attr(data-tip)] before:-translate-x-2/5"
      }
      data-tip={isLocalChain ? "Get local test funds" : `Get demo ${paymentTokenSymbol}`}
    >
      <button
        className="btn btn-secondary btn-sm px-2 rounded-full"
        onClick={sendFunds}
        disabled={isBusy}
        aria-label="Get test funds"
      >
        {!isBusy ? <BanknotesIcon className="h-4 w-4" /> : <span className="loading loading-spinner loading-xs"></span>}
      </button>
    </div>
  );
};
