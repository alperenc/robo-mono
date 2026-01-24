"use client";

import { useAccount } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

interface ClaimTokensModalProps {
  isOpen: boolean;
  onClose: () => void;
  listingId: string;
  tokenAmount: string;
  vehicleName: string;
}

export const ClaimTokensModal = ({ isOpen, onClose, listingId, vehicleName }: ClaimTokensModalProps) => {
  const { address } = useAccount();
  const { writeContractAsync: writeMarketplace, isPending } = useScaffoldWriteContract({ contractName: "Marketplace" });

  const { data: escrowedAmount, isLoading: isLoadingAmount } = useScaffoldReadContract({
    contractName: "Marketplace",
    functionName: "buyerTokens",
    args: [BigInt(listingId), address],
  });

  const handleClaim = async () => {
    try {
      await writeMarketplace({
        functionName: "claimTokens",
        args: [BigInt(listingId)],
      });
      onClose();
    } catch (e) {
      console.error("Error claiming tokens:", e);
    }
  };

  if (!isOpen) return null;

  const displayAmount = escrowedAmount || 0n;

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
          <h3 className="font-bold text-xl text-success">Claim Revenue Tokens</h3>
          <p className="text-sm opacity-60 mt-1">{vehicleName}</p>
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          {isLoadingAmount ? (
            <div className="flex justify-center py-10">
              <span className="loading loading-spinner loading-lg" />
            </div>
          ) : (
            <>
              <div className="bg-success/10 rounded-xl p-4 flex flex-col items-center text-center gap-2">
                <span className="text-sm font-medium opacity-70 uppercase tracking-wide">Tokens to Claim</span>
                <span className="text-4xl font-bold text-success">{Number(displayAmount).toLocaleString()}</span>
                <span className="text-xs opacity-50">Revenue Rights Tokens</span>
              </div>

              <p className="text-sm opacity-70 mt-6 text-center">
                The listing for this asset has successfully ended. You can now claim your tokens and they will be
                transferred to your wallet.
              </p>
            </>
          )}
        </div>

        <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
          <button
            className="btn btn-primary btn-block"
            onClick={handleClaim}
            disabled={isPending || isLoadingAmount || displayAmount === 0n}
          >
            {isPending ? <span className="loading loading-spinner loading-sm" /> : "Claim Tokens"}
          </button>
        </div>
      </div>
    </div>
  );
};
