"use client";

import { useMemo, useState } from "react";
import { XMarkIcon } from "@heroicons/react/24/outline";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

interface ForceFinalPayoutModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: () => void;
  assetId: string;
  vehicleName: string;
  liquidationReason?: number;
}

export const ForceFinalPayoutModal = ({
  isOpen,
  onClose,
  onSuccess,
  assetId,
  vehicleName,
  liquidationReason,
}: ForceFinalPayoutModalProps) => {
  const assetIdBigInt = BigInt(assetId);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const { data: liquidationPreview } = useScaffoldReadContract({
    contractName: "RegistryRouter",
    functionName: "previewLiquidationEligibility",
    args: [assetIdBigInt],
    query: { enabled: isOpen },
  });
  const { writeContractAsync: writeRouter, isPending } = useScaffoldWriteContract({
    contractName: "RegistryRouter",
  });
  const isBusy = isSubmitting || isPending;

  const liquidationEligible = liquidationPreview ? liquidationPreview[0] : false;
  const resolvedLiquidationReason = liquidationReason ?? (liquidationPreview ? Number(liquidationPreview[1]) : 3);
  const isInsolvencyFlow = resolvedLiquidationReason === 1;
  const reasonLabel = useMemo(() => {
    if (resolvedLiquidationReason === 1) return "This asset is eligible for forced final payout due to insolvency.";
    if (resolvedLiquidationReason === 0) return "This asset is eligible for final payout because it reached maturity.";
    if (resolvedLiquidationReason === 2) return "This asset has already been finalized.";
    return "This asset is not currently eligible for forced final payout.";
  }, [resolvedLiquidationReason]);

  const handleForceFinalPayout = async () => {
    if (!liquidationEligible || isBusy) return;

    try {
      setIsSubmitting(true);
      await writeRouter({
        functionName: "liquidateAsset",
        args: [assetIdBigInt],
      });
      onSuccess?.();
      onClose();
    } catch (error) {
      console.error("Error forcing final payout:", error);
      setIsSubmitting(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div
        className="modal-backdrop bg-black/50 backdrop-blur-sm hidden sm:block"
        onClick={isBusy ? undefined : onClose}
      />
      <div className="modal-box relative w-full h-full max-h-full sm:h-auto sm:max-h-[90vh] sm:max-w-xl sm:rounded-2xl rounded-none flex flex-col p-0">
        <button
          className="btn btn-sm btn-circle btn-ghost absolute right-4 top-4 z-10"
          onClick={onClose}
          disabled={isBusy}
        >
          <XMarkIcon className="h-5 w-5" />
        </button>

        <div className="p-4 border-b border-base-200 shrink-0">
          <h3 className="font-bold text-xl">{isInsolvencyFlow ? "Force Final Payout" : "Finalize at Maturity"}</h3>
          <p className="text-sm opacity-60 mt-1">{vehicleName}</p>
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          <div className="flex flex-col gap-4">
            <div className="alert alert-warning">
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
                <div className="font-semibold">Public protocol action</div>
                <div className="text-sm">
                  {isInsolvencyFlow
                    ? "Anyone can trigger forced final payout once an asset becomes insolvent. This closes the asset and makes final holder payouts claimable."
                    : "Anyone can finalize an asset at maturity once it becomes eligible. This closes the asset and makes final holder payouts claimable."}
                </div>
              </div>
            </div>

            <div className="rounded-xl border border-base-300 bg-base-200 p-4">
              <div className="text-sm font-medium">Eligibility</div>
              <div className="mt-2 text-sm opacity-75">{reasonLabel}</div>
            </div>
          </div>
        </div>

        <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
          <div className="flex gap-3 justify-end">
            <button className="btn btn-ghost" onClick={onClose} disabled={isBusy}>
              Cancel
            </button>
            <button
              className={isInsolvencyFlow ? "btn btn-error" : "btn btn-primary"}
              onClick={handleForceFinalPayout}
              disabled={isBusy || !liquidationEligible}
            >
              {isBusy ? (
                <>
                  <span className="loading loading-spinner loading-sm" />
                  Processing...
                </>
              ) : isInsolvencyFlow ? (
                "Force Final Payout"
              ) : (
                "Finalize at Maturity"
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
