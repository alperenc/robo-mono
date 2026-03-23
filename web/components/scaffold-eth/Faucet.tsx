"use client";

import { useEffect, useMemo, useState } from "react";
import { createPortal } from "react-dom";
import {
  Address as AddressType,
  createWalletClient,
  erc20Abi,
  formatEther,
  formatUnits,
  http,
  parseEther,
  parseUnits,
} from "viem";
import { hardhat } from "viem/chains";
import { useAccount } from "wagmi";
import { BanknotesIcon } from "@heroicons/react/24/outline";
import { Address, AddressInput, EtherInput } from "~~/components/scaffold-eth";
import { useScaffoldWriteContract, useTransactor } from "~~/hooks/scaffold-eth";
import { useWatchBalance } from "~~/hooks/scaffold-eth/useWatchBalance";
import { useWatchTokenBalance } from "~~/hooks/scaffold-eth/useWatchTokenBalance";
import { usePaymentToken } from "~~/hooks/usePaymentToken";
import { getLocalRpcUrl, getRuntimeLocalChain } from "~~/utils/localServiceUrls";
import { notification } from "~~/utils/scaffold-eth";

const FAUCET_ADDRESS = "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f" as AddressType;

/**
 * Faucet modal which lets you send ETH to any address.
 */
export const Faucet = () => {
  const [isOpen, setIsOpen] = useState(false);
  const [isMounted, setIsMounted] = useState(false);
  const [loading, setLoading] = useState(false);
  const [inputAddress, setInputAddress] = useState<AddressType>();
  const [faucetAddress, setFaucetAddress] = useState<AddressType>();
  const [sendEthValue, setSendEthValue] = useState("");
  const [sendTokenValue, setSendTokenValue] = useState("");

  const { address: connectedAddress, chain: ConnectedChain } = useAccount();
  const isLocalChain = ConnectedChain?.id === hardhat.id;
  const {
    address: paymentTokenAddress,
    symbol: paymentTokenSymbol,
    decimals: paymentTokenDecimals,
  } = usePaymentToken();
  const { writeContractAsync: mintPaymentToken } = useScaffoldWriteContract({ contractName: "MockUSDC" });

  const localWalletClient = useMemo(
    () =>
      createWalletClient({
        chain: getRuntimeLocalChain(),
        transport: http(getLocalRpcUrl()),
      }),
    [],
  );

  const faucetTxn = useTransactor(localWalletClient);
  const { data: faucetNativeBalance } = useWatchBalance({ address: faucetAddress });

  const { data: faucetTokenBalance, refetch: refetchFaucetTokenBalance } = useWatchTokenBalance({
    tokenAddress: paymentTokenAddress,
    ownerAddress: faucetAddress,
  });

  useEffect(() => {
    setFaucetAddress(FAUCET_ADDRESS);
  }, []);

  useEffect(() => {
    setIsMounted(true);
  }, []);

  useEffect(() => {
    if (connectedAddress) {
      setInputAddress(prev => prev ?? (connectedAddress as AddressType));
    }
  }, [connectedAddress]);

  const sendFunds = async () => {
    if (!faucetAddress || !inputAddress) {
      return;
    }
    const normalizedEth = sendEthValue.trim();
    const normalizedToken = sendTokenValue.trim();
    if (!normalizedEth && !normalizedToken) {
      notification.error(
        isLocalChain ? "Enter an ETH amount, a token amount, or both." : `Enter a ${paymentTokenSymbol} amount.`,
      );
      return;
    }
    try {
      setLoading(true);
      if (isLocalChain && normalizedEth) {
        await faucetTxn({
          to: inputAddress,
          value: parseEther(normalizedEth as `${number}`),
          account: faucetAddress,
        });
      }
      if (normalizedToken && paymentTokenAddress) {
        if (isLocalChain) {
          await faucetTxn(() =>
            localWalletClient.writeContract({
              address: paymentTokenAddress,
              abi: erc20Abi,
              functionName: "transfer",
              args: [inputAddress, parseUnits(normalizedToken, paymentTokenDecimals)],
              account: faucetAddress,
            }),
          );
        } else {
          await mintPaymentToken({
            functionName: "mint",
            args: [inputAddress, parseUnits(normalizedToken, paymentTokenDecimals)],
          });
        }
      }
      await refetchFaucetTokenBalance();
      setLoading(false);
      setInputAddress(undefined);
      setSendEthValue("");
      setSendTokenValue("");
    } catch (error) {
      notification.error(
        error instanceof Error && /fetch|network|connection|socket/i.test(error.message)
          ? "Cannot connect to the local faucet chain."
          : "Faucet transfer failed.",
      );
      console.error("⚡️ ~ file: Faucet.tsx:sendFunds ~ error", error);
      setLoading(false);
    }
  };

  if (!isLocalChain && !paymentTokenAddress) {
    return null;
  }

  const formattedNativeBalance = faucetNativeBalance
    ? Number(formatEther(faucetNativeBalance.value)).toLocaleString(undefined, {
        minimumFractionDigits: 4,
        maximumFractionDigits: 4,
      })
    : (0).toLocaleString(undefined, {
        minimumFractionDigits: 4,
        maximumFractionDigits: 4,
      });
  const formattedTokenBalance = Number(
    formatUnits((faucetTokenBalance as bigint | undefined) ?? 0n, paymentTokenDecimals),
  ).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });

  return (
    <div>
      <button type="button" className="btn btn-primary btn-sm font-normal gap-1" onClick={() => setIsOpen(true)}>
        <BanknotesIcon className="h-4 w-4" />
        <span>Faucet</span>
      </button>
      {isOpen && isMounted
        ? createPortal(
            <div className="modal modal-open z-[200]">
              <div
                className="modal-backdrop bg-black/50 backdrop-blur-sm hidden sm:block"
                onClick={() => setIsOpen(false)}
              />
              <div className="modal-box relative z-[201] w-full h-full max-h-full sm:h-auto sm:max-h-[90vh] sm:max-w-md sm:rounded-2xl rounded-none flex flex-col p-0 overflow-hidden">
                <button
                  type="button"
                  className="btn btn-ghost btn-lg btn-circle absolute right-4 top-4 z-10 min-h-12 h-12 w-12"
                  aria-label="Close faucet"
                  onClick={() => setIsOpen(false)}
                >
                  ✕
                </button>
                <div className="shrink-0 border-b border-base-200 p-4">
                  <h3 className="text-xl font-bold">
                    {isLocalChain ? "Local Faucet" : `${paymentTokenSymbol} Faucet`}
                  </h3>
                  <p className="mt-1 text-sm opacity-60">
                    {isLocalChain
                      ? `Send local ETH and ${paymentTokenSymbol} from the faucet account.`
                      : `Mint ${paymentTokenSymbol} on this testnet.`}
                  </p>
                </div>
                <div className="flex-1 overflow-y-auto p-4">
                  <div className="space-y-3">
                    <div className="rounded-2xl border border-base-300 bg-base-200/50 p-4">
                      <div className="text-sm font-bold">{isLocalChain ? "From" : "Mode"}</div>
                      {isLocalChain ? (
                        <div className="mt-1">
                          <Address address={faucetAddress} onlyEnsOrAddress />
                        </div>
                      ) : (
                        <div className="mt-1 text-sm font-medium text-base-content/70">
                          Mint on demand from the {paymentTokenSymbol} contract
                        </div>
                      )}
                      <div className="mt-3 flex flex-col gap-1 text-sm">
                        {isLocalChain ? (
                          <div className="flex items-center justify-between gap-3">
                            <span className="font-semibold text-base-content/70">ETH Available</span>
                            <span className="font-semibold">
                              {formattedNativeBalance} <span className="text-base-content/70">ETH</span>
                            </span>
                          </div>
                        ) : null}
                        {paymentTokenAddress ? (
                          <div className="flex items-center justify-between gap-3">
                            <span className="font-semibold text-base-content/70">
                              {isLocalChain ? `${paymentTokenSymbol} Available` : `${paymentTokenSymbol} Faucet`}
                            </span>
                            <span className="font-semibold tabular-nums">
                              {isLocalChain ? (
                                <>
                                  {formattedTokenBalance}{" "}
                                  <span className="text-base-content/70">{paymentTokenSymbol}</span>
                                </>
                              ) : (
                                <span className="text-base-content/70">Mint on demand</span>
                              )}
                            </span>
                          </div>
                        ) : null}
                      </div>
                    </div>
                    <div className="flex flex-col space-y-3">
                      <AddressInput
                        placeholder="Destination Address"
                        value={inputAddress ?? ""}
                        onChange={value => setInputAddress(value as AddressType)}
                      />
                      {isLocalChain ? (
                        <EtherInput
                          placeholder="ETH amount to send"
                          value={sendEthValue}
                          onChange={value => setSendEthValue(value)}
                        />
                      ) : null}
                      {paymentTokenAddress ? (
                        <div className="flex border-2 border-base-300 bg-base-200 rounded-full text-accent">
                          <input
                            type="number"
                            min="0"
                            step="any"
                            className="input input-ghost focus-within:border-transparent focus:outline-hidden focus:bg-transparent h-[2.2rem] min-h-[2.2rem] px-4 border w-full font-medium placeholder:text-accent/70 text-base-content/70 focus:text-base-content/70"
                            placeholder={`${paymentTokenSymbol} amount to send`}
                            value={sendTokenValue}
                            onChange={e => setSendTokenValue(e.target.value)}
                          />
                          <span className="mr-1 flex items-center self-center rounded-full bg-base-300 px-3 py-1 text-xs font-medium text-base-content/80">
                            {paymentTokenSymbol}
                          </span>
                        </div>
                      ) : null}
                    </div>
                  </div>
                </div>
                <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
                  <button className="h-11 btn btn-primary w-full rounded-full" onClick={sendFunds} disabled={loading}>
                    {!loading ? (
                      <BanknotesIcon className="h-6 w-6" />
                    ) : (
                      <span className="loading loading-spinner loading-sm"></span>
                    )}
                    <span>Send Funds</span>
                  </button>
                </div>
              </div>
            </div>,
            document.body,
          )
        : null}
    </div>
  );
};
