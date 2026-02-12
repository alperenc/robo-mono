"use client";

import { XMarkIcon } from "@heroicons/react/24/outline";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

interface ClaimSettlementModalProps {
  isOpen: boolean;
  onClose: () => void;
  assetId: string;
  vehicleName: string;
}

export const ClaimSettlementModal = ({ isOpen, onClose, assetId, vehicleName }: ClaimSettlementModalProps) => {
  const { writeContractAsync: writeRouter, isPending } = useScaffoldWriteContract({
    contractName: "RegistryRouter",
  });

  const handleClaim = async () => {
    try {
      await writeRouter({
        functionName: "claimSettlement",
        args: [BigInt(assetId), false],
      });
      onClose();
    } catch (e) {
      console.error("Error claiming settlement:", e);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-backdrop bg-black/50 backdrop-blur-sm hidden sm:block" onClick={onClose} />
      <div className="modal-box relative w-full h-full max-h-full sm:h-auto sm:max-h-[90vh] sm:max-w-md sm:rounded-2xl rounded-none flex flex-col p-0">
        <button
          className="btn btn-sm btn-circle btn-ghost absolute right-4 top-4 z-10"
          onClick={onClose}
          disabled={isPending}
        >
          <XMarkIcon className="h-5 w-5" />
        </button>

        <div className="p-4 border-b border-base-200 shrink-0">
          <h3 className="font-bold text-xl text-primary">Claim Settlement</h3>
          <p className="text-sm opacity-60 mt-1">{vehicleName}</p>
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          <div className="bg-base-200 rounded-xl p-4 text-sm opacity-70">
            Claim your settlement payout. This will burn your revenue tokens for this asset.
          </div>
        </div>

        <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
          <button className="btn btn-primary btn-block" onClick={handleClaim} disabled={isPending}>
            {isPending ? <span className="loading loading-spinner loading-sm" /> : "Claim Settlement"}
          </button>
        </div>
      </div>
    </div>
  );
};
