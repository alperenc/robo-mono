"use client";

import { useEffect, useMemo, useState } from "react";
import { useEscClose } from "./useEscClose";
import { parseUnits } from "viem";
import { useAccount, useChainId } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { usePaymentToken } from "~~/hooks/usePaymentToken";
import { getDeployedContract } from "~~/utils/contracts";

interface SettleAssetModalProps {
  isOpen: boolean;
  onClose: () => void;
  assetId: string;
  assetName: string;
}

export const SettleAssetModal = ({ isOpen, onClose, assetId, assetName }: SettleAssetModalProps) => {
  const { address: connectedAddress } = useAccount();
  const chainId = useChainId();
  const { symbol, decimals } = usePaymentToken();
  const [topUpAmount, setTopUpAmount] = useState("");
  const [isConfirmed, setIsConfirmed] = useState(false);
  const [mode, setMode] = useState<"settle" | "liquidate">("settle");
  const [pendingAction, setPendingAction] = useState<"settle" | "liquidate" | null>(null);

  useEscClose(isOpen, onClose);

  const { writeContractAsync: writeVehicleRegistry, isPending } = useScaffoldWriteContract({
    contractName: "VehicleRegistry",
  });

  const treasuryAddress = getDeployedContract(chainId, "Treasury")?.address;

  const assetIdBigInt = BigInt(assetId);

  const { data: assetNftBalance } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "balanceOf",
    args: [connectedAddress, assetIdBigInt],
    query: { enabled: isOpen && !!connectedAddress },
  });

  const { data: liquidationPreview } = useScaffoldReadContract({
    contractName: "RegistryRouter",
    functionName: "previewLiquidationEligibility",
    args: [assetIdBigInt],
    query: { enabled: isOpen },
  });

  const isAssetOwner = (assetNftBalance ?? 0n) > 0n;
  const liquidationEligible = liquidationPreview ? liquidationPreview[0] : false;
  const liquidationReason = liquidationPreview ? Number(liquidationPreview[1]) : 3;
  const isAlreadySettled = liquidationReason === 2;
  const hasSettleAction = isAssetOwner;
  const hasLiquidateAction = liquidationEligible;
  const hasBothActions = hasSettleAction && hasLiquidateAction;
  const isLiquidationOnly = !hasSettleAction;

  const modeLabel = mode === "settle" ? "Begin Final Payout" : "Force Final Payout";
  const showTopUpControls = mode === "settle" && hasSettleAction;
  const isPaymentPending = pendingAction === "settle" && isPending;

  // Check payment token allowance (settlement top-up path only)
  const { data: paymentTokenAllowance } = useScaffoldReadContract({
    contractName: "MockUSDC",
    functionName: "allowance",
    args: [connectedAddress, treasuryAddress],
    watch: true,
    query: { enabled: isOpen && !!connectedAddress && !!treasuryAddress && showTopUpControls },
  });

  const { writeContractAsync: writePaymentToken } = useScaffoldWriteContract({ contractName: "MockUSDC" });

  useEffect(() => {
    if (!isOpen) {
      setTopUpAmount("");
      setIsConfirmed(false);
      setMode("settle");
      setPendingAction(null);
      return;
    }

    // Role-aware default presentation.
    if (isLiquidationOnly) {
      setMode("liquidate");
    } else {
      setMode("settle");
    }
  }, [isOpen, isLiquidationOnly]);

  const handleSettle = async () => {
    if (!treasuryAddress) return;
    if (!hasSettleAction || isAlreadySettled) return;

    try {
      setPendingAction("settle");
      const topUpBigInt = topUpAmount ? parseUnits(topUpAmount, decimals) : 0n;

      // Approve if needed and top-up amount is provided
      if (topUpBigInt > 0n && (!paymentTokenAllowance || paymentTokenAllowance < topUpBigInt)) {
        await writePaymentToken({
          functionName: "approve",
          args: [treasuryAddress, topUpBigInt],
        });
      }

      // Settle the asset via VehicleRegistry
      await writeVehicleRegistry({
        functionName: "settleAsset",
        args: [assetIdBigInt, topUpBigInt],
      });

      setTopUpAmount("");
      setIsConfirmed(false);
      onClose();
    } catch (e) {
      console.error("Error settling asset:", e);
    } finally {
      setPendingAction(null);
    }
  };

  const handleLiquidate = async () => {
    if (!hasLiquidateAction || isAlreadySettled) return;

    try {
      setPendingAction("liquidate");
      await writeVehicleRegistry({
        functionName: "liquidateAsset",
        args: [assetIdBigInt],
      });

      setTopUpAmount("");
      setIsConfirmed(false);
      onClose();
    } catch (e) {
      console.error("Error liquidating asset:", e);
    } finally {
      setPendingAction(null);
    }
  };

  const liquidationReasonLabel = useMemo(() => {
    if (!hasLiquidateAction) return null;
    if (liquidationReason === 0) return "Eligible for final payout at term end";
    if (liquidationReason === 1) return "Eligible for forced final payout";
    return "Eligible";
  }, [hasLiquidateAction, liquidationReason]);

  const disableSettle = !isConfirmed || isPending || !hasSettleAction || isAlreadySettled;
  const disableLiquidate = !isConfirmed || isPending || !hasLiquidateAction || isAlreadySettled;

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-backdrop bg-black/50 backdrop-blur-sm hidden sm:block" onClick={onClose} />
      <div className="modal-box relative w-full h-full max-h-full sm:h-auto sm:max-h-[90vh] sm:max-w-xl sm:rounded-2xl rounded-none flex flex-col p-0">
        <div className="flex flex-col h-full w-full">
          {/* Close Button */}
          <button
            type="button"
            className="btn btn-sm btn-circle btn-ghost absolute right-4 top-4 z-10"
            onClick={onClose}
            disabled={isPending}
          >
            <XMarkIcon className="h-5 w-5" />
          </button>

          {/* Header */}
          <div className="p-4 border-b border-base-200 shrink-0">
            <h3 className={`font-bold text-xl ${mode === "liquidate" ? "text-error" : ""}`}>{modeLabel}</h3>
            <p className="text-sm opacity-60 mt-1">
              {mode === "settle"
                ? "End payouts and make final holder payouts available"
                : "Force final resolution and make holder payouts available"}
            </p>
          </div>

          {/* Scrollable Content */}
          <div className="flex-1 overflow-y-auto p-4">
            <div className="flex flex-col gap-3">
              {hasBothActions && (
                <div className="join w-full">
                  <button
                    type="button"
                    className={`btn join-item flex-1 ${mode === "settle" ? "btn-primary" : "btn-ghost border-base-300"}`}
                    onClick={() => setMode("settle")}
                    disabled={isPending}
                  >
                    Begin Final Payout
                  </button>
                  <button
                    type="button"
                    className={`btn join-item flex-1 ${mode === "liquidate" ? "btn-error" : "btn-ghost border-base-300"}`}
                    onClick={() => setMode("liquidate")}
                    disabled={isPending}
                  >
                    Force Final Payout
                  </button>
                </div>
              )}

              {/* Warning Alert */}
              <div className={`alert ${mode === "liquidate" ? "alert-error" : "alert-warning"}`}>
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  className="stroke-current shrink-0 h-6 w-6"
                  fill="none"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                  />
                </svg>
                <div>
                  <div className="font-semibold">This action is irreversible</div>
                  <div className="text-sm">
                    {mode === "settle" ? (
                      <>
                        Starting final payout for <strong>{assetName}</strong> will end payouts and allow holders to
                        claim their final payout.
                      </>
                    ) : (
                      <>
                        Force closing <strong>{assetName}</strong> will trigger final resolution and allow holders to
                        claim their final payout.
                      </>
                    )}
                  </div>
                </div>
              </div>

              {hasLiquidateAction && liquidationReasonLabel && (
                <div
                  className={`rounded-lg border p-3 text-sm ${mode === "liquidate" ? "border-error/30 bg-error/10" : "border-warning/30 bg-warning/10"}`}
                >
                  <div className="font-medium">{liquidationReasonLabel}</div>
                  <div className="opacity-75 mt-1">
                    {liquidationReason === 0
                      ? "This asset can be force closed because it has reached maturity."
                      : liquidationReason === 1
                        ? "This asset can be force closed due to insolvency after missed-payout shortfall accrual."
                        : "This asset can be force closed under the current rules."}
                    {mode === "settle" && hasSettleAction
                      ? " You may still choose to begin final payout voluntarily."
                      : ""}
                  </div>
                </div>
              )}

              {!hasLiquidateAction && isLiquidationOnly && (
                <div className="alert alert-info">
                  <span className="text-sm">
                    This asset is not currently eligible for forced final payout. That becomes available only after
                    maturity or insolvency.
                  </span>
                </div>
              )}

              {/* Top-Up Amount */}
              {showTopUpControls && (
                <div className="form-control">
                  <label className="label py-1">
                    <span className="label-text text-xs font-bold uppercase opacity-60">Top-Up Amount (Optional)</span>
                  </label>
                  <div className="join w-full">
                    <input
                      type="number"
                      step="0.000001"
                      min="0"
                      className="input input-bordered join-item w-full"
                      value={topUpAmount}
                      onChange={e => setTopUpAmount(e.target.value)}
                      placeholder="0.00"
                    />
                    <span className="join-item flex items-center px-3 bg-base-200 font-medium">{symbol}</span>
                  </div>
                  <label className="label py-1">
                    <span className="label-text-alt text-xs opacity-60">
                      Add additional {symbol} to increase the settlement pool for token holders
                    </span>
                  </label>
                </div>
              )}

              {/* Confirmation Checkbox */}
              <div className="form-control bg-base-200 p-4 rounded-lg">
                <label className="label cursor-pointer justify-start gap-3 p-0">
                  <input
                    type="checkbox"
                    checked={isConfirmed}
                    onChange={e => setIsConfirmed(e.target.checked)}
                    className="checkbox checkbox-error"
                  />
                  <span className="label-text">I understand this action cannot be undone</span>
                </label>
              </div>
            </div>
          </div>

          {/* Sticky Footer */}
          <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
            <div className="flex gap-3 justify-end">
              <button type="button" className="btn btn-ghost" onClick={onClose} disabled={isPending}>
                Cancel
              </button>
              {hasBothActions ? (
                <>
                  <button type="button" className="btn btn-error" onClick={handleLiquidate} disabled={disableLiquidate}>
                    {pendingAction === "liquidate" && isPending ? (
                      <>
                        <span className="loading loading-spinner loading-sm"></span>
                        Liquidating...
                      </>
                    ) : (
                      "Force Final Payout"
                    )}
                  </button>
                  <button type="button" className="btn btn-primary" onClick={handleSettle} disabled={disableSettle}>
                    {pendingAction === "settle" && isPending ? (
                      <>
                        <span className="loading loading-spinner loading-sm"></span>
                        Settling...
                      </>
                    ) : (
                      "Begin Final Payout"
                    )}
                  </button>
                </>
              ) : hasSettleAction ? (
                <button type="button" className="btn btn-error" onClick={handleSettle} disabled={disableSettle}>
                  {pendingAction === "settle" && isPaymentPending ? (
                    <>
                      <span className="loading loading-spinner loading-sm"></span>
                      Settling...
                    </>
                  ) : (
                    "Begin Final Payout"
                  )}
                </button>
              ) : (
                <button type="button" className="btn btn-error" onClick={handleLiquidate} disabled={disableLiquidate}>
                  {pendingAction === "liquidate" && isPending ? (
                    <>
                      <span className="loading loading-spinner loading-sm"></span>
                      Liquidating...
                    </>
                  ) : (
                    "Force Final Payout"
                  )}
                </button>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
