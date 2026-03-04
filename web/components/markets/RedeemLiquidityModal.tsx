"use client";

import { useEffect, useMemo, useState } from "react";
import { formatUnits } from "viem";
import { useAccount, useReadContract } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { usePaymentToken } from "~~/hooks/usePaymentToken";

interface RedeemLiquidityModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: () => void;
  tokenId: string;
  vehicleName: string;
  maxRedeemableAmount: string;
}

const PERCENTAGE_OPTIONS = [25, 50, 75, 100];

export function RedeemLiquidityModal({
  isOpen,
  onClose,
  onSuccess,
  tokenId,
  vehicleName,
  maxRedeemableAmount,
}: RedeemLiquidityModalProps) {
  const { address } = useAccount();
  const { symbol, decimals } = usePaymentToken();
  const [inputAmount, setInputAmount] = useState("");
  const [step, setStep] = useState<"input" | "redeeming" | "success" | "error">("input");
  const [error, setError] = useState<string | null>(null);
  const redeemAmount = inputAmount ? BigInt(inputAmount) : 0n;
  const maxAmount = BigInt(maxRedeemableAmount || "0");

  const { data: redemptionPreview, refetch: refetchPreview } = useReadContract({
    address: deployedContracts[31337]?.Marketplace?.address,
    abi: deployedContracts[31337]?.Marketplace?.abi,
    functionName: "previewPrimaryRedemption",
    args: [BigInt(tokenId), redeemAmount || 1n],
    query: { enabled: isOpen && redeemAmount > 0n },
  });

  const { writeContractAsync: writeMarketplace, isPending } = useScaffoldWriteContract({
    contractName: "Marketplace",
  });

  const payout = redemptionPreview?.[0] ?? 0n;
  const redeemableLiquidity = redemptionPreview?.[1] ?? 0n;
  const circulatingSupply = redemptionPreview?.[2] ?? 0n;
  const formattedPayout = formatUnits(payout, decimals);
  const formattedLiquidity = formatUnits(redeemableLiquidity, decimals);
  const currentPercentage = useMemo(() => {
    if (redeemAmount === 0n || maxAmount === 0n) return 0;
    return Number((redeemAmount * 100n) / maxAmount);
  }, [maxAmount, redeemAmount]);

  useEffect(() => {
    if (!isOpen) {
      setInputAmount("");
      setStep("input");
      setError(null);
    }
  }, [isOpen]);

  const handlePercentageSelect = (percentage: number) => {
    if (maxAmount === 0n) return;
    const amount = (maxAmount * BigInt(percentage)) / 100n;
    setInputAmount(amount.toString());
  };

  const handleSliderChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const percentage = parseInt(e.target.value);
    handlePercentageSelect(percentage);
  };

  const handleRedeem = async () => {
    if (redeemAmount === 0n || !address) return;

    try {
      setError(null);
      setStep("redeeming");
      await writeMarketplace({
        functionName: "redeemPrimaryPool",
        args: [BigInt(tokenId), redeemAmount, payout],
      });
      setStep("success");
      onSuccess?.();
    } catch (e: any) {
      setError(e.message || e.shortMessage || "Redemption failed");
      setStep("error");
      await refetchPreview();
    }
  };

  if (!isOpen) return null;

  const hasValidAmount = redeemAmount > 0n && redeemAmount <= maxAmount;

  return (
    <div className="modal modal-open">
      <div className="modal-backdrop bg-black/50 backdrop-blur-sm hidden sm:block" onClick={onClose} />
      <div className="modal-box relative w-full h-full max-h-full sm:h-auto sm:max-h-[90vh] sm:max-w-xl sm:rounded-2xl rounded-none flex flex-col p-0">
        <button
          className="btn btn-sm btn-circle btn-ghost absolute right-4 top-4 z-10"
          onClick={onClose}
          disabled={isPending}
        >
          <XMarkIcon className="w-5 h-5" />
        </button>

        <div className="p-4 border-b border-base-200 shrink-0">
          <h3 className="font-bold text-xl">Redeem Liquidity</h3>
          <p className="text-sm opacity-60 mt-1">{vehicleName}</p>
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          {step === "success" ? (
            <div className="text-center text-base-content">
              <div className="text-6xl mb-4">💸</div>
              <h4 className="text-xl font-bold text-success mb-2">Liquidity Redeemed</h4>
              <div className="alert text-sm mb-4 text-left bg-base-200/70 text-base-content border border-base-300">
                <span>Your position was redeemed immediately and the liquidity was returned to your wallet.</span>
              </div>
              <p className="text-base-content/80 mb-4">
                You&apos;ve redeemed <span className="font-bold">{redeemAmount.toLocaleString()}</span> units of this
                asset&apos;s revenue-rights position.
              </p>
              <div className="bg-success/20 dark:bg-success/15 border border-success/30 rounded-lg p-4 text-base-content">
                <div className="text-sm text-base-content/70 mb-1">Liquidity Returned</div>
                <div className="text-2xl font-bold text-success">
                  {Number(formattedPayout).toLocaleString(undefined, { minimumFractionDigits: 2 })} {symbol}
                </div>
              </div>
            </div>
          ) : (
            <div className="flex flex-col gap-3">
              <div className="bg-base-200 rounded-lg p-3">
                <div className="flex justify-between text-sm">
                  <span className="opacity-70">Your Position</span>
                  <span>{maxAmount.toLocaleString()} units</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="opacity-70">Redeemable Liquidity</span>
                  <span>
                    {Number(formattedLiquidity).toLocaleString(undefined, { minimumFractionDigits: 2 })} {symbol}
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="opacity-70">Circulating Position</span>
                  <span>{circulatingSupply.toLocaleString()} units</span>
                </div>
              </div>

              <div className="form-control">
                <label className="label py-1">
                  <span className="label-text text-xs font-bold uppercase opacity-60">Position to Redeem</span>
                  <span className="label-text-alt">Max: {maxAmount.toLocaleString()} units</span>
                </label>
                <input
                  type="number"
                  className="input input-bordered w-full"
                  placeholder="0"
                  value={inputAmount}
                  onChange={e => setInputAmount(e.target.value)}
                  max={maxAmount.toString()}
                  min="0"
                  step="1"
                  disabled={isPending}
                />
              </div>

              {hasValidAmount && (
                <div className="flex justify-between items-center text-sm">
                  <span className="opacity-70">Liquidity Returned</span>
                  <span className="font-mono">
                    {Number(formattedPayout).toLocaleString(undefined, { minimumFractionDigits: 2 })} {symbol}
                  </span>
                </div>
              )}

              <div className="flex gap-2">
                {PERCENTAGE_OPTIONS.map(pct => (
                  <button
                    key={pct}
                    className={`btn btn-sm flex-1 ${currentPercentage === pct ? "btn-primary" : "btn-outline"}`}
                    onClick={() => handlePercentageSelect(pct)}
                    disabled={isPending || maxAmount === 0n}
                  >
                    {pct}%
                  </button>
                ))}
              </div>

              <div>
                <input
                  type="range"
                  min="0"
                  max="100"
                  value={currentPercentage}
                  onChange={handleSliderChange}
                  className="range range-primary range-sm w-full"
                  disabled={isPending || maxAmount === 0n}
                />
                <div className="flex justify-between text-xs opacity-50 mt-1">
                  <span>0%</span>
                  <span>50%</span>
                  <span>100%</span>
                </div>
              </div>

              {error && (
                <div className="alert alert-error">
                  <span className="text-sm">{error}</span>
                </div>
              )}
            </div>
          )}
        </div>

        <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
          <div className="flex gap-3">
            {step === "success" ? (
              <button className="btn btn-primary flex-1" onClick={onClose}>
                Done
              </button>
            ) : (
              <>
                <button className="btn btn-ghost flex-1" onClick={onClose} disabled={isPending}>
                  Cancel
                </button>
                <button
                  className="btn btn-primary flex-1"
                  onClick={handleRedeem}
                  disabled={Boolean(isPending || !hasValidAmount || payout === 0n)}
                >
                  {isPending ? (
                    <>
                      <span className="loading loading-spinner loading-sm"></span>Redeeming...
                    </>
                  ) : (
                    "Redeem Liquidity"
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
