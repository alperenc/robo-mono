"use client";

import { formatUnits } from "viem";
import { useAccount, useReadContract } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

interface FinalizeListingModalProps {
  isOpen: boolean;
  onClose: () => void;
  listingId: string;
  tokenAmount: string;
}

export const FinalizeListingModal = ({ isOpen, onClose, listingId, tokenAmount }: FinalizeListingModalProps) => {
  const { address } = useAccount();
  const { writeContractAsync: writeMarketplace, isPending } = useScaffoldWriteContract({ contractName: "Marketplace" });

  // Fetch pending withdrawal amount
  const { data: pendingAmount, isLoading: isLoadingPending } = useReadContract({
    address: deployedContracts[31337]?.Treasury?.address,
    abi: deployedContracts[31337]?.Treasury?.abi,
    functionName: "getPendingWithdrawal",
    args: address ? [address] : undefined,
    query: { enabled: !!address && isOpen },
  });

  const formattedTokenAmount = Number(tokenAmount).toLocaleString();
  const formattedProceedsAmount = pendingAmount ? formatUnits(pendingAmount as bigint, 6) : "0";
  const hasProceeds = pendingAmount && (pendingAmount as bigint) > 0n;

  const handleFinalize = async () => {
    try {
      await writeMarketplace({
        functionName: "finalizeListing",
        args: [BigInt(listingId)],
      });
      onClose();
    } catch (e) {
      console.error("Error finalizing listing:", e);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-backdrop bg-black/50 backdrop-blur-sm hidden sm:block" onClick={onClose} />
      <div className="modal-box relative w-full h-full max-h-full sm:h-auto sm:max-h-[90vh] sm:max-w-md sm:rounded-2xl rounded-none flex flex-col p-0">
        {/* Close Button */}
        <button
          className="btn btn-sm btn-circle btn-ghost absolute right-4 top-4 z-10"
          onClick={onClose}
          disabled={isPending}
        >
          <XMarkIcon className="h-5 w-5" />
        </button>

        {/* Header */}
        <div className="p-4 border-b border-base-200 shrink-0">
          <h3 className="font-bold text-xl">Finalize Listing</h3>
          <p className="text-sm opacity-60 mt-1">Cancel listing and withdraw all proceeds</p>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-4">
          <div className="flex flex-col gap-4">
            {isLoadingPending ? (
              <div className="flex justify-center py-8">
                <span className="loading loading-spinner loading-lg" />
              </div>
            ) : (
              <>
                {/* What will happen */}
                <div className="bg-base-200 rounded-xl p-4 space-y-3">
                  <div className="font-semibold">This action will:</div>
                  <div className="flex items-start gap-3">
                    <div className="badge badge-warning badge-sm mt-0.5">1</div>
                    <div className="text-sm">
                      Cancel your listing and return <span className="font-bold">{formattedTokenAmount}</span> tokens to
                      your wallet
                    </div>
                  </div>
                  {hasProceeds && (
                    <div className="flex items-start gap-3">
                      <div className="badge badge-success badge-sm mt-0.5">2</div>
                      <div className="text-sm">
                        Withdraw{" "}
                        <span className="font-bold text-success">
                          ${Number(formattedProceedsAmount).toLocaleString()}
                        </span>{" "}
                        USDC in pending proceeds
                      </div>
                    </div>
                  )}
                </div>

                {/* Info */}
                <p className="text-sm opacity-70">
                  This is a convenience function that combines canceling your listing with withdrawing any pending sales
                  proceeds in a single transaction.
                </p>
              </>
            )}
          </div>
        </div>

        {/* Footer */}
        <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
          <div className="flex gap-3 justify-end">
            <button className="btn btn-ghost" onClick={onClose} disabled={isPending}>
              Cancel
            </button>
            <button className="btn btn-primary" onClick={handleFinalize} disabled={isPending}>
              {isPending ? (
                <>
                  <span className="loading loading-spinner loading-sm" />
                  Finalizing...
                </>
              ) : (
                "Finalize Listing"
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
