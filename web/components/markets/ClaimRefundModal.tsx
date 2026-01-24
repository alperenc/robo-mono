"use client";

import { formatUnits } from "viem";
import { useAccount } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

interface ClaimRefundModalProps {
  isOpen: boolean;
  onClose: () => void;
  listingId: string;
  refundAmount: string;
  vehicleName: string;
}

export const ClaimRefundModal = ({ isOpen, onClose, listingId, vehicleName }: ClaimRefundModalProps) => {
  const { address } = useAccount();
  const { writeContractAsync: writeMarketplace, isPending } = useScaffoldWriteContract({ contractName: "Marketplace" });

  const { data: refundableAmount, isLoading: isLoadingAmount } = useScaffoldReadContract({
    contractName: "Marketplace",
    functionName: "buyerPayments",
    args: [BigInt(listingId), address],
  });

  const handleClaim = async () => {
    try {
      await writeMarketplace({
        functionName: "claimRefund",
        args: [BigInt(listingId)],
      });
      onClose();
    } catch (e) {
      console.error("Error claiming refund:", e);
    }
  };

  if (!isOpen) return null;

  const displayAmount = refundableAmount || 0n;

  return (
    <div className="modal modal-open">
      <div className="modal-backdrop bg-black/50 backdrop-blur-sm hidden sm:block" onClick={onClose} />
      <div className="modal-box relative w-full h-full max-h-full sm:h-auto sm:max-h-[90vh] sm:max-w-md sm:rounded-2xl rounded-none flex flex-col p-0">
        <button
          className="btn btn-sm btn-circle btn-ghost absolute right-4 top-4 z-10"
          onClick={onClose}
          disabled={isPending || isLoadingAmount}
        >
          <XMarkIcon className="h-5 w-5" />
        </button>

        <div className="p-4 border-b border-base-200 shrink-0">
          <h3 className="font-bold text-xl text-error">Claim USDC Refund</h3>
          <p className="text-sm opacity-60 mt-1">{vehicleName}</p>
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          {isLoadingAmount ? (
            <div className="flex justify-center py-10">
              <span className="loading loading-spinner loading-lg" />
            </div>
          ) : (
            <>
              <div className="bg-error/10 rounded-xl p-4 flex flex-col items-center text-center gap-2">
                <span className="text-sm font-medium opacity-70 uppercase tracking-wide">Amount to Refund</span>
                <span className="text-4xl font-bold text-error">
                  ${Number(formatUnits(displayAmount, 6)).toLocaleString(undefined, { minimumFractionDigits: 2 })}
                </span>
                <span className="text-xs opacity-50">USDC</span>
              </div>

              <p className="text-sm opacity-70 mt-6 text-center">
                This listing was cancelled by the seller. You are entitled to a full refund of your purchase amount.
              </p>
            </>
          )}
        </div>

        <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
          <button
            className="btn btn-error btn-block"
            onClick={handleClaim}
            disabled={isPending || isLoadingAmount || displayAmount === 0n}
          >
            {isPending ? <span className="loading loading-spinner loading-sm" /> : "Claim Refund"}
          </button>
        </div>
      </div>
    </div>
  );
};
