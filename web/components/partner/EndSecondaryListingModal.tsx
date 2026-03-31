"use client";

import { useEffect, useState } from "react";
import { XMarkIcon } from "@heroicons/react/24/outline";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { getParsedError } from "~~/utils/scaffold-eth";

interface EndSecondaryListingModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: () => void;
  listingId: string;
  tokenAmount: string;
}

export const EndSecondaryListingModal = ({
  isOpen,
  onClose,
  onSuccess,
  listingId,
  tokenAmount,
}: EndSecondaryListingModalProps) => {
  const [isEnding, setIsEnding] = useState(false);
  const { writeContractAsync: writeMarketplace, isPending } = useScaffoldWriteContract({ contractName: "Marketplace" });
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const isBusy = isEnding || isPending;

  const formattedTokenAmount = Number(tokenAmount).toLocaleString();

  useEffect(() => {
    if (!isOpen) setErrorMessage(null);
  }, [isOpen]);

  const handleConfirm = async () => {
    if (isBusy) return;

    try {
      setErrorMessage(null);
      setIsEnding(true);
      const txHash = await writeMarketplace({
        functionName: "endListing",
        args: [BigInt(listingId)],
      });
      if (!txHash) {
        setIsEnding(false);
        setErrorMessage("Transaction was not submitted. Please try again.");
        return;
      }

      onSuccess?.();
      onClose();
    } catch (e) {
      setErrorMessage(getParsedError(e));
    } finally {
      setIsEnding(false);
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
        {/* Close Button */}
        <button
          className="btn btn-sm btn-circle btn-ghost absolute right-4 top-4 z-10"
          onClick={onClose}
          disabled={isBusy}
        >
          <XMarkIcon className="h-5 w-5" />
        </button>

        {/* Header */}
        <div className="p-4 border-b border-base-200 shrink-0">
          <h3 className="font-bold text-xl">End Listing</h3>
          <p className="text-sm opacity-60 mt-1">
            End your active marketplace listing and unlock any unsold claim units.
          </p>
        </div>

        {/* Scrollable Content */}
        <div className="flex-1 overflow-y-auto p-4">
          <div className="flex flex-col gap-3">
            {errorMessage && (
              <div className="alert alert-error text-sm">
                <span>{errorMessage}</span>
              </div>
            )}
            {/* Confirmation Text */}
            <p className="text-sm opacity-70">
              Are you sure you want to end this listing? Existing purchases stay settled and any unsold claim units are
              unlocked based on the listing state below.
            </p>

            {/* Unsold claim units note */}
            {Number(tokenAmount) > 0 && (
              <div className="bg-base-200 rounded-xl p-4">
                <div className="font-semibold text-sm">Unsold claim units</div>
                <div className="text-sm opacity-80 mt-1">
                  <span className="font-bold">{formattedTokenAmount}</span> unsold claim units will be unlocked in your
                  wallet.
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Sticky Footer */}
        <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
          <div className="flex gap-3 justify-end">
            <button className="btn btn-ghost" onClick={onClose} disabled={isBusy}>
              Keep Listing
            </button>
            <button className="btn btn-primary" onClick={handleConfirm} disabled={isBusy}>
              {isBusy ? (
                <>
                  <span className="loading loading-spinner loading-sm"></span>
                  Ending...
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
