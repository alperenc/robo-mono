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

  // Fetch pending withdrawal amount (Treasury)
  const { data: pendingTreasuryAmount, isLoading: isLoadingTreasury } = useReadContract({
    address: deployedContracts[31337]?.Treasury?.address,
    abi: deployedContracts[31337]?.Treasury?.abi,
    functionName: "getPendingWithdrawal",
    args: address ? [address] : undefined,
    query: { enabled: !!address && isOpen },
  });

  // Fetch listing proceeds (Marketplace)
  const { data: listingProceeds, isLoading: isLoadingMarketplace } = useReadContract({
    address: deployedContracts[31337]?.Marketplace?.address,
    abi: deployedContracts[31337]?.Marketplace?.abi,
    functionName: "listingProceeds",
    args: [BigInt(listingId)],
    query: { enabled: isOpen },
  });

  const isLoading = isLoadingTreasury || isLoadingMarketplace;
  const listingAmount = (listingProceeds as bigint) || 0n;
  const pendingAmountVal = (pendingTreasuryAmount as bigint) || 0n;
  const totalProceeds = listingAmount + pendingAmountVal;

  const formattedTokenAmount = Number(tokenAmount).toLocaleString();
  const formattedTotal = formatUnits(totalProceeds, 6);
  const formattedListingPart = formatUnits(listingAmount, 6);
  const formattedPendingPart = formatUnits(pendingAmountVal, 6);

  const hasProceeds = totalProceeds > 0n;

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
          <p className="text-sm opacity-60 mt-1">End listing and withdraw proceeds</p>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-4">
          <div className="flex flex-col gap-4">
            {isLoading ? (
              <div className="flex justify-center py-8">
                <span className="loading loading-spinner loading-lg" />
              </div>
            ) : (
              <>
                {/* What will happen */}
                <div className="bg-base-200 rounded-xl p-4 space-y-3">
                  <div className="font-semibold">This action will:</div>

                  {Number(tokenAmount) > 0 && (
                    <div className="flex items-start gap-3">
                      <div className="badge badge-warning badge-sm mt-0.5">1</div>
                      <div className="text-sm">
                        End your listing and return <span className="font-bold">{formattedTokenAmount}</span> unsold
                        tokens to your wallet
                      </div>
                    </div>
                  )}

                  {hasProceeds && (
                    <div className="flex items-start gap-3">
                      <div className="badge badge-success badge-sm mt-0.5">{Number(tokenAmount) > 0 ? 2 : 1}</div>
                      <div>
                        <div className="text-sm">
                          Withdraw{" "}
                          <span className="font-bold text-success">${Number(formattedTotal).toLocaleString()}</span>{" "}
                          USDC total
                        </div>
                        <div className="text-xs opacity-60 mt-1 space-y-0.5">
                          {listingAmount > 0n && (
                            <div>• ${Number(formattedListingPart).toLocaleString()} from this listing</div>
                          )}
                          {pendingAmountVal > 0n && (
                            <div>• ${Number(formattedPendingPart).toLocaleString()} from treasury balance</div>
                          )}
                        </div>
                      </div>
                    </div>
                  )}

                  <div className="flex items-start gap-3">
                    <div className="badge badge-info badge-sm mt-0.5">
                      {Number(tokenAmount) > 0 && hasProceeds ? 3 : 2}
                    </div>
                    <div className="text-sm">Enable buyers to claim their purchased tokens</div>
                  </div>
                </div>

                {/* Info */}
                <p className="text-sm opacity-70">
                  This is a convenience function that combines ending your listing, enabling buyer claims, and
                  withdrawing all available proceeds in a single transaction.
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
