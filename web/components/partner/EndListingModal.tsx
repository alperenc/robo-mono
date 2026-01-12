"use client";

import { XMarkIcon } from "@heroicons/react/24/outline";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

interface EndListingModalProps {
  isOpen: boolean;
  onClose: () => void;
  listingId: string;
  tokenAmount: string;
}

export const EndListingModal = ({ isOpen, onClose, listingId, tokenAmount }: EndListingModalProps) => {
  const { writeContractAsync: writeMarketplace, isPending } = useScaffoldWriteContract({ contractName: "Marketplace" });

  const formattedTokenAmount = Number(tokenAmount).toLocaleString();

  const handleConfirm = async () => {
    try {
      await writeMarketplace({
        functionName: "cancelListing",
        args: [BigInt(listingId)],
      });

      onClose();
    } catch (e) {
      console.error("Error cancelling listing:", e);
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
          <h3 className="font-bold text-xl">End Listing</h3>
          <p className="text-sm opacity-60 mt-1">Cancel your active marketplace listing</p>
        </div>

        {/* Scrollable Content */}
        <div className="flex-1 overflow-y-auto p-4">
          <div className="flex flex-col gap-3">
            {/* Warning Alert */}
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
                <div className="font-semibold">Tokens will be returned</div>
                <div className="text-sm">
                  <span className="font-bold text-warning-content">{formattedTokenAmount}</span> tokens will be
                  transferred back to your wallet.
                </div>
              </div>
            </div>

            {/* Confirmation Text */}
            <p className="text-sm opacity-70">
              Are you sure you want to cancel this listing? You can create a new listing at any time with different
              terms.
            </p>
          </div>
        </div>

        {/* Sticky Footer */}
        <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
          <div className="flex gap-3 justify-end">
            <button className="btn btn-ghost" onClick={onClose} disabled={isPending}>
              Keep Listing
            </button>
            <button className="btn btn-error" onClick={handleConfirm} disabled={isPending}>
              {isPending ? (
                <>
                  <span className="loading loading-spinner loading-sm"></span>
                  Cancelling...
                </>
              ) : (
                "End Listing"
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
