"use client";

import { useEffect, useMemo, useState } from "react";
import { formatUnits, parseUnits } from "viem";
import { useAccount, useChainId, useReadContract } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { usePaymentToken } from "~~/hooks/usePaymentToken";
import { getDeployedContract } from "~~/utils/contracts";

interface RedeemLiquidityModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: () => void;
  tokenId: string;
  vehicleName: string;
  totalPositionAmount: string;
  maxRedeemableAmount: string;
  pricePerToken: string;
}

const PERCENTAGE_OPTIONS = [25, 50, 75, 100];

const formatTokenInput = (amount: bigint, decimals: number) => {
  const formatted = formatUnits(amount, decimals);
  if (!formatted.includes(".")) return formatted;
  return formatted.replace(/\.?0+$/, "");
};

const ceilDiv = (a: bigint, b: bigint) => (a + b - 1n) / b;

export function RedeemLiquidityModal({
  isOpen,
  onClose,
  onSuccess,
  tokenId,
  vehicleName,
  totalPositionAmount,
  maxRedeemableAmount,
  pricePerToken,
}: RedeemLiquidityModalProps) {
  const { address } = useAccount();
  const chainId = useChainId();
  const { symbol, decimals } = usePaymentToken();
  const [fundsInput, setFundsInput] = useState("");
  const [step, setStep] = useState<"input" | "redeeming" | "success" | "error">("input");
  const [error, setError] = useState<string | null>(null);
  const [successSnapshot, setSuccessSnapshot] = useState<{ redeemAmount: bigint; payout: bigint } | null>(null);
  const totalPosition = BigInt(totalPositionAmount || "0");
  const maxAmount = BigInt(maxRedeemableAmount || "0");
  const pricePerUnit = BigInt(pricePerToken || "0");

  const marketplaceContract = getDeployedContract(chainId, "Marketplace");
  const { data: fullPositionRedemptionPreview } = useReadContract({
    address: marketplaceContract?.address,
    abi: marketplaceContract?.abi,
    functionName: "previewPrimaryRedemption",
    args: address ? [BigInt(tokenId), address, maxAmount] : undefined,
    query: { enabled: isOpen && !!address && !!marketplaceContract },
  });

  const { writeContractAsync: writeMarketplace, isPending } = useScaffoldWriteContract({
    contractName: "Marketplace",
  });

  const fullPositionPreviewTuple = fullPositionRedemptionPreview as
    | readonly [bigint, bigint, bigint, bigint]
    | undefined;
  const fullPositionPayout = fullPositionPreviewTuple?.[0] ?? 0n;
  const availableLiquidityNow = fullPositionPreviewTuple?.[1] ?? 0n;
  const withdrawableSupplyNow = fullPositionPreviewTuple?.[2] ?? 0n;
  const maxFunds = fullPositionPayout;
  const totalPositionValue = totalPosition * pricePerUnit;
  const enteredFunds = useMemo(() => {
    if (!fundsInput.trim()) return 0n;
    try {
      return parseUnits(fundsInput, decimals);
    } catch {
      return 0n;
    }
  }, [decimals, fundsInput]);
  const redeemAmount = useMemo(() => {
    if (enteredFunds === 0n || maxFunds === 0n || maxAmount === 0n) return 0n;
    return ceilDiv(enteredFunds * maxAmount, maxFunds);
  }, [enteredFunds, maxAmount, maxFunds]);
  const { data: redemptionPreview, refetch: refetchPreview } = useReadContract({
    address: marketplaceContract?.address,
    abi: marketplaceContract?.abi,
    functionName: "previewPrimaryRedemption",
    args: address ? [BigInt(tokenId), address, redeemAmount] : undefined,
    query: { enabled: isOpen && !!address && !!marketplaceContract },
  });
  const previewTuple = redemptionPreview as readonly [bigint, bigint, bigint, bigint] | undefined;
  const payout = previewTuple?.[0] ?? 0n;
  const formattedFullPositionPayout = formatUnits(fullPositionPayout, decimals);
  const formattedTotalPositionValue = formatUnits(totalPositionValue, decimals);
  const formattedAvailableLiquidityNow = formatUnits(availableLiquidityNow, decimals);
  const currentPercentage = useMemo(() => {
    if (enteredFunds === 0n || maxFunds === 0n) return 0;
    return Number((enteredFunds * 100n) / maxFunds);
  }, [enteredFunds, maxFunds]);
  const hasRestrictedWithdrawalWindow = maxAmount < totalPosition;

  useEffect(() => {
    if (!isOpen) {
      setFundsInput("");
      setStep("input");
      setError(null);
      setSuccessSnapshot(null);
    }
  }, [isOpen]);

  const handlePercentageSelect = (percentage: number) => {
    if (maxFunds === 0n) return;
    const amount = (maxFunds * BigInt(percentage)) / 100n;
    setFundsInput(formatTokenInput(amount, decimals));
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
      const submittedRedeemAmount = redeemAmount;
      const submittedPayout = payout;
      await writeMarketplace({
        functionName: "redeemPrimaryPool",
        args: [BigInt(tokenId), redeemAmount, payout],
      });
      setSuccessSnapshot({ redeemAmount: submittedRedeemAmount, payout: submittedPayout });
      setStep("success");
      onSuccess?.();
    } catch (e: any) {
      setError(e.message || e.shortMessage || "Redemption failed");
      setStep("error");
      await refetchPreview();
    }
  };

  if (!isOpen) return null;

  const hasValidAmount =
    enteredFunds > 0n && enteredFunds <= maxFunds && redeemAmount > 0n && redeemAmount <= maxAmount && payout > 0n;
  const successRedeemAmount = successSnapshot?.redeemAmount ?? 0n;
  const successPayout = successSnapshot?.payout ?? 0n;
  const formattedSuccessPayout = formatUnits(successPayout, decimals);

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
          <h3 className="font-bold text-xl">Withdraw</h3>
          <p className="text-sm opacity-60 mt-1">{vehicleName}</p>
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          {step === "success" ? (
            <div className="text-center text-base-content">
              <div className="text-6xl mb-4">💸</div>
              <h4 className="text-xl font-bold text-success mb-2">Withdrawal Complete</h4>
              <div className="alert text-sm mb-4 text-left bg-base-200/70 text-base-content border border-base-300">
                <span>Your withdrawal has been completed and the redeemed funds were sent to your wallet.</span>
              </div>
              <p className="text-base-content/80 mb-4">
                You redeemed <span className="font-bold">{successRedeemAmount.toLocaleString()}</span> units from this
                position for{" "}
                <span className="font-bold">
                  {Number(formattedSuccessPayout).toLocaleString(undefined, { minimumFractionDigits: 2 })} {symbol}
                </span>
                .
              </p>
              <div className="bg-success/20 dark:bg-success/15 border border-success/30 rounded-lg p-4 text-base-content">
                <div className="text-sm text-base-content/70 mb-1">Funds Received</div>
                <div className="text-2xl font-bold text-success">
                  {Number(formattedSuccessPayout).toLocaleString(undefined, { minimumFractionDigits: 2 })} {symbol}
                </div>
              </div>
            </div>
          ) : (
            <div className="flex flex-col gap-3">
              <div className="bg-base-200 rounded-lg p-3">
                <div className="flex justify-between text-sm">
                  <span className="opacity-70">Your Position Value</span>
                  <span>
                    {Number(formattedTotalPositionValue).toLocaleString(undefined, { minimumFractionDigits: 2 })}{" "}
                    {symbol}
                  </span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="opacity-70">Funds You Can Receive Now</span>
                  <span>
                    {Number(formattedFullPositionPayout).toLocaleString(undefined, { minimumFractionDigits: 2 })}{" "}
                    {symbol}
                  </span>
                </div>
              </div>

              {hasRestrictedWithdrawalWindow && (
                <div className="alert text-sm bg-base-200/70 text-base-content border border-base-300">
                  <span>
                    Why can&apos;t you withdraw the full position? This pool releases proceeds immediately, so only the
                    units bought after the last proceeds release can be withdrawn here right now.
                  </span>
                </div>
              )}

              {hasRestrictedWithdrawalWindow && (
                <p className="text-xs opacity-60 px-1">
                  Pool status:{" "}
                  {Number(formattedAvailableLiquidityNow).toLocaleString(undefined, { minimumFractionDigits: 2 })}{" "}
                  {symbol} backing {withdrawableSupplyNow.toLocaleString()} currently withdrawable units.
                </p>
              )}

              <div className="form-control">
                <label className="label py-1">
                  <span className="label-text text-xs font-bold uppercase opacity-60">Funds to Receive</span>
                  <span className="label-text-alt">
                    Max: {Number(formattedFullPositionPayout).toLocaleString(undefined, { minimumFractionDigits: 2 })}{" "}
                    {symbol}
                  </span>
                </label>
                <input
                  type="number"
                  className="input input-bordered w-full"
                  placeholder="0"
                  value={fundsInput}
                  onChange={e => setFundsInput(e.target.value)}
                  max={formattedFullPositionPayout}
                  min="0"
                  step="any"
                  disabled={isPending}
                />
              </div>

              {hasValidAmount && (
                <div className="flex justify-between items-center text-sm">
                  <span className="opacity-70">Units That Will Be Redeemed</span>
                  <span className="font-mono">{redeemAmount.toLocaleString()} units</span>
                </div>
              )}

              <div className="flex gap-2">
                {PERCENTAGE_OPTIONS.map(pct => (
                  <button
                    key={pct}
                    className={`btn btn-sm flex-1 ${currentPercentage === pct ? "btn-primary" : "btn-outline"}`}
                    onClick={() => handlePercentageSelect(pct)}
                    disabled={isPending || maxFunds === 0n}
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
                  disabled={isPending || maxFunds === 0n}
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
                      <span className="loading loading-spinner loading-sm"></span>Withdrawing...
                    </>
                  ) : (
                    "Withdraw"
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
