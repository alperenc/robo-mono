"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { formatUnits } from "viem";
import { useAccount } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

interface BuyTokensModalProps {
  isOpen: boolean;
  onClose: () => void;
  onPurchaseComplete?: () => void;
  listing: {
    id: string;
    tokenId: string;
    assetId: string;
    pricePerToken: string;
    amount: string;
    seller: string;
    buyerPaysFee?: boolean;
  };
  totalSupply?: string;
  vehicleName?: string;
  partnerName?: string;
}

const PERCENTAGE_OPTIONS = [25, 50, 75, 100];

export function BuyTokensModal({
  isOpen,
  onClose,
  onPurchaseComplete,
  listing,
  totalSupply,
  vehicleName = "Asset",
  partnerName,
}: BuyTokensModalProps) {
  const { address } = useAccount();
  const [amount, setAmount] = useState("");
  const [step, setStep] = useState<"input" | "approving" | "purchasing" | "success" | "error">("input");
  const [error, setError] = useState<string | null>(null);

  // Contract addresses
  const chainId = 31337; // localhost
  const marketplaceAddress = deployedContracts[chainId]?.Marketplace?.address;

  // Read USDC balance
  const { data: usdcBalance } = useScaffoldReadContract({
    contractName: "MockUSDC",
    functionName: "balanceOf",
    args: [address],
  });

  // Read user's current revenue token balance
  const revenueTokenId = BigInt(listing.assetId) + 1n;
  const { data: userTokenBalance, refetch: refetchTokenBalance } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "balanceOf",
    args: [address, revenueTokenId],
  });

  // Read USDC allowance for Marketplace
  const { data: usdcAllowance, refetch: refetchAllowance } = useScaffoldReadContract({
    contractName: "MockUSDC",
    functionName: "allowance",
    args: [address, marketplaceAddress],
    watch: true,
  });

  // Calculate purchase cost
  const { data: purchaseCostData } = useScaffoldReadContract({
    contractName: "Marketplace",
    functionName: "calculatePurchaseCost",
    args: [BigInt(listing.id), amount ? BigInt(amount) : 0n],
  });

  // Write contracts
  const { writeContractAsync: approveUsdc, isPending: isApproving } = useScaffoldWriteContract({
    contractName: "MockUSDC",
  });

  const { writeContractAsync: purchaseTokens, isPending: isPurchasing } = useScaffoldWriteContract({
    contractName: "Marketplace",
  });

  // Calculate max affordable tokens based on USDC balance
  const maxAffordableTokens = useMemo(() => {
    if (!usdcBalance) return 0n;

    const pricePerToken = BigInt(listing.pricePerToken);
    if (pricePerToken === 0n) return 0n;

    // Rough estimate (not accounting for fees exactly, but close enough)
    const buyerPaysFee = listing.buyerPaysFee ?? true;
    const feeMultiplier = buyerPaysFee ? 103n : 100n; // ~3% protocol fee buffer
    const effectivePricePerToken = (pricePerToken * feeMultiplier) / 100n;

    return usdcBalance / effectivePricePerToken;
  }, [usdcBalance, listing.pricePerToken, listing.buyerPaysFee]);

  // Max tokens = min(listing amount, affordable tokens)
  const maxTokens = useMemo(() => {
    const listingAmount = BigInt(listing.amount);
    return maxAffordableTokens < listingAmount ? maxAffordableTokens : listingAmount;
  }, [maxAffordableTokens, listing.amount]);

  // Parse cost data
  const totalCost = purchaseCostData?.[0] ?? 0n;
  const protocolFee = purchaseCostData?.[1] ?? 0n;
  const expectedPayment = purchaseCostData?.[2] ?? 0n;

  // Check if approval needed
  const needsApproval = useMemo(() => {
    if (!usdcAllowance || !expectedPayment) return true;
    return usdcAllowance < expectedPayment;
  }, [usdcAllowance, expectedPayment]);

  // Format values for display
  const formattedBalance = usdcBalance ? formatUnits(usdcBalance, 6) : "0";
  const formattedCost = formatUnits(totalCost, 6);
  const formattedFee = formatUnits(protocolFee, 6);
  const formattedTotal = formatUnits(expectedPayment, 6);
  const pricePerTokenDisplay = formatUnits(BigInt(listing.pricePerToken), 6);

  // Handle percentage selection
  const handlePercentageSelect = useCallback(
    (percentage: number) => {
      const tokens = (maxTokens * BigInt(percentage)) / 100n;
      setAmount(tokens.toString());
    },
    [maxTokens],
  );

  // Handle slider change
  const handleSliderChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const percentage = parseInt(e.target.value);
      const tokens = (maxTokens * BigInt(percentage)) / 100n;
      setAmount(tokens.toString());
    },
    [maxTokens],
  );

  // Current percentage for slider
  const currentPercentage = useMemo(() => {
    if (!amount || maxTokens === 0n) return 0;
    return Number((BigInt(amount) * 100n) / maxTokens);
  }, [amount, maxTokens]);

  // Handle combined approve + purchase flow
  const handleBuy = async () => {
    if (!amount || BigInt(amount) === 0n) return;
    if (!marketplaceAddress || expectedPayment === 0n) {
      setError("Unable to calculate purchase amount");
      return;
    }

    setError(null);

    try {
      // Step 1: Approve if needed
      if (needsApproval) {
        setStep("approving");
        await approveUsdc({
          functionName: "approve",
          args: [marketplaceAddress as `0x${string}`, expectedPayment],
        });
        await refetchAllowance();
      }

      // Step 2: Purchase
      setStep("purchasing");
      await purchaseTokens({
        functionName: "purchaseTokens",
        args: [BigInt(listing.id), BigInt(amount)],
      });
      setStep("success");
      // Refetch token balance to show updated holdings
      await refetchTokenBalance();
      // Trigger data refresh
      onPurchaseComplete?.();
    } catch (e: any) {
      console.error("Transaction error:", e);
      setError(e.message || "Transaction failed");
      setStep("error");
    }
  };

  // Reset on close
  useEffect(() => {
    if (!isOpen) {
      setAmount("");
      setStep("input");
      setError(null);
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const isLoading = isApproving || isPurchasing;
  const hasValidAmount = amount && BigInt(amount) > 0n && BigInt(amount) <= BigInt(listing.amount);
  const hasInsufficientBalance = expectedPayment > (usdcBalance ?? 0n);

  return (
    <div className="modal modal-open">
      <div className="modal-backdrop bg-black/50 backdrop-blur-sm hidden sm:block" onClick={onClose} />
      <div className="modal-box relative w-full h-full max-h-full sm:h-auto sm:max-h-[90vh] sm:max-w-md sm:rounded-2xl rounded-none flex flex-col p-0">
        {/* Close Button */}
        <button
          className="btn btn-sm btn-circle btn-ghost absolute right-4 top-4 z-10"
          onClick={onClose}
          disabled={isLoading}
        >
          <XMarkIcon className="w-5 h-5" />
        </button>

        {/* Header */}
        <div className="p-4 border-b border-base-200 shrink-0">
          <h3 className="font-bold text-xl">Buy Revenue Tokens</h3>
          <p className="text-sm opacity-60 mt-1">{vehicleName}</p>
          {partnerName && <p className="text-xs opacity-50">by {partnerName}</p>}
        </div>

        {/* Scrollable Content */}
        <div className="flex-1 overflow-y-auto p-4">
          {step === "success" ? (
            <div className="text-center py-8">
              <div className="text-6xl mb-4">🎉</div>
              <h4 className="text-xl font-bold text-success mb-2">Purchase Complete!</h4>
              <p className="opacity-70 mb-4">
                You&apos;ve acquired <span className="font-bold">{Number(amount).toLocaleString()}</span> revenue rights
                tokens for {vehicleName}.
              </p>

              {/* Ownership percentage */}
              {totalSupply && (
                <div className="bg-base-200 rounded-lg p-4 mb-4">
                  <div className="text-sm opacity-70 mb-1">This Purchase</div>
                  <div className="text-2xl font-bold text-primary">
                    {((Number(amount) / Number(totalSupply)) * 100).toFixed(2)}%
                  </div>
                  <div className="text-xs opacity-50">of total revenue rights</div>
                </div>
              )}

              {/* Total holdings after purchase */}
              {userTokenBalance !== undefined && totalSupply && (
                <div className="bg-success/10 rounded-lg p-4">
                  <div className="text-sm opacity-70 mb-1">Your Total Revenue Rights</div>
                  <div className="text-2xl font-bold text-success">
                    {((Number(userTokenBalance) / Number(totalSupply)) * 100).toFixed(2)}%
                  </div>
                  <div className="text-xs opacity-50">{Number(userTokenBalance).toLocaleString()} tokens</div>
                </div>
              )}
            </div>
          ) : (
            <div className="flex flex-col gap-3">
              {/* Asset Info */}
              <div className="bg-base-200 rounded-lg p-3">
                <div className="flex justify-between text-sm">
                  <span className="opacity-70">Price per Token:</span>
                  <span className="font-bold">${pricePerTokenDisplay}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="opacity-70">Available:</span>
                  <span>{Number(listing.amount).toLocaleString()} tokens</span>
                </div>
              </div>

              {/* USDC Balance */}
              <div className="flex justify-between items-center">
                <span className="text-sm opacity-70">Your USDC Balance</span>
                <span className="font-mono">
                  ${Number(formattedBalance).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                </span>
              </div>

              {/* Amount Input */}
              <div className="form-control">
                <label className="label py-1">
                  <span className="label-text text-xs font-bold uppercase opacity-60">Amount to Buy</span>
                  <span className="label-text-alt">Max: {maxTokens.toString()}</span>
                </label>
                <input
                  type="number"
                  className="input input-bordered w-full"
                  placeholder="0"
                  value={amount}
                  onChange={e => setAmount(e.target.value)}
                  max={maxTokens.toString()}
                  min="0"
                  disabled={isLoading}
                />
              </div>

              {/* Percentage Quick Selectors */}
              <div className="flex gap-2">
                {PERCENTAGE_OPTIONS.map(pct => (
                  <button
                    key={pct}
                    className={`btn btn-sm flex-1 ${currentPercentage === pct ? "btn-primary" : "btn-outline"}`}
                    onClick={() => handlePercentageSelect(pct)}
                    disabled={isLoading || maxTokens === 0n}
                  >
                    {pct}%
                  </button>
                ))}
              </div>

              {/* Slider */}
              <div>
                <input
                  type="range"
                  min="0"
                  max="100"
                  value={currentPercentage}
                  onChange={handleSliderChange}
                  className="range range-primary range-sm w-full"
                  disabled={isLoading || maxTokens === 0n}
                />
                <div className="flex justify-between text-xs opacity-50 mt-1">
                  <span>0%</span>
                  <span>50%</span>
                  <span>100%</span>
                </div>
              </div>

              {/* Cost Breakdown */}
              {hasValidAmount && (
                <div className="bg-base-200 rounded-lg p-3 space-y-1">
                  <div className="flex justify-between text-sm">
                    <span>Subtotal</span>
                    <span>${Number(formattedCost).toLocaleString(undefined, { minimumFractionDigits: 2 })}</span>
                  </div>
                  <div className="flex justify-between text-sm opacity-70">
                    <span>Protocol Fee</span>
                    <span>${Number(formattedFee).toLocaleString(undefined, { minimumFractionDigits: 2 })}</span>
                  </div>
                  <div className="divider my-1"></div>
                  <div className="flex justify-between font-bold">
                    <span>Total</span>
                    <span className={hasInsufficientBalance ? "text-error" : ""}>
                      ${Number(formattedTotal).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                    </span>
                  </div>
                  {hasInsufficientBalance && <div className="text-xs text-error mt-1">Insufficient USDC balance</div>}
                </div>
              )}

              {/* Error Display */}
              {error && (
                <div className="alert alert-error">
                  <span className="text-sm">{error}</span>
                </div>
              )}
            </div>
          )}
        </div>

        {/* Sticky Footer */}
        <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
          <div className="flex gap-3">
            {step === "success" ? (
              <button className="btn btn-primary flex-1" onClick={onClose}>
                Done
              </button>
            ) : (
              <>
                <button className="btn btn-ghost flex-1" onClick={onClose} disabled={isLoading}>
                  Cancel
                </button>

                <button
                  className="btn btn-primary flex-1"
                  onClick={handleBuy}
                  disabled={isLoading || !hasValidAmount || hasInsufficientBalance}
                >
                  {isApproving ? (
                    <>
                      <span className="loading loading-spinner loading-sm"></span>
                      Approving...
                    </>
                  ) : isPurchasing ? (
                    <>
                      <span className="loading loading-spinner loading-sm"></span>
                      Completing...
                    </>
                  ) : needsApproval ? (
                    "Approve & Buy"
                  ) : (
                    "Buy Tokens"
                  )}
                </button>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
