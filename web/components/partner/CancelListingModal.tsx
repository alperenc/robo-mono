"use client";

import { useEffect, useState } from "react";
import { XMarkIcon } from "@heroicons/react/24/outline";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

interface CancelListingModalProps {
  isOpen: boolean;
  onClose: () => void;
  listingId: string;
}

export const CancelListingModal = ({ isOpen, onClose, listingId }: CancelListingModalProps) => {
  const { writeContractAsync: writeMarketplace, isPending } = useScaffoldWriteContract({ contractName: "Marketplace" });
  const [confirmationText, setConfirmationText] = useState("");

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

  // Reset state on close
  useEffect(() => {
    if (!isOpen) {
      setConfirmationText("");
    }
  }, [isOpen]);

  if (!isOpen) return null;

  const isConfirmed = confirmationText.toLowerCase() === "cancel";

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
          <h3 className="font-bold text-xl text-error">Cancel Listing</h3>
          <p className="text-sm opacity-60 mt-1">Abort the sale and refund buyers</p>
        </div>

        {/* Scrollable Content */}
        <div className="flex-1 overflow-y-auto p-4">
          <div className="flex flex-col gap-4">
            {/* Warning Alert */}
            <div className="alert alert-error bg-error/10 border-error/20 text-error-content">
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
                <div className="font-semibold">Full Refund Initiated</div>
                <div className="text-sm">
                  All buyers will be refunded. All tokens (sold + unsold) will be returned to you.
                </div>
              </div>
            </div>

            {/* Confirmation Text */}
            <p className="text-sm opacity-70">
              Are you sure you want to cancel this listing? This action cannot be undone. All trades will be voided.
            </p>

            {/* Safety Input */}
            <div className="form-control">
              <label className="label">
                <span className="label-text text-xs font-bold uppercase opacity-60">
                  Type <span className="text-error">cancel</span> to confirm
                </span>
              </label>
              <input
                type="text"
                className="input input-bordered w-full input-sm"
                placeholder="Type 'cancel' here"
                value={confirmationText}
                onChange={e => setConfirmationText(e.target.value)}
                disabled={isPending}
              />
            </div>
          </div>
        </div>

        {/* Sticky Footer */}
        <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
          <div className="flex gap-3 justify-end">
            <button className="btn btn-ghost" onClick={onClose} disabled={isPending}>
              Back
            </button>
            <button className="btn btn-error" onClick={handleConfirm} disabled={isPending || !isConfirmed}>
              {isPending ? (
                <>
                  <span className="loading loading-spinner loading-sm"></span>
                  Cancelling...
                </>
              ) : (
                "Confirm Cancellation"
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
