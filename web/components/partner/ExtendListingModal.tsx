"use client";

import { useState } from "react";
import { XMarkIcon } from "@heroicons/react/24/outline";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

interface ExtendListingModalProps {
  isOpen: boolean;
  onClose: () => void;
  listingId: string;
  currentExpiresAt: bigint;
}

export const ExtendListingModal = ({ isOpen, onClose, listingId, currentExpiresAt }: ExtendListingModalProps) => {
  const [durationDays, setDurationDays] = useState("7");

  const { writeContractAsync: writeMarketplace, isPending } = useScaffoldWriteContract({ contractName: "Marketplace" });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    try {
      const additionalDuration = BigInt(parseInt(durationDays) * 24 * 60 * 60);

      await writeMarketplace({
        functionName: "extendListing",
        args: [BigInt(listingId), additionalDuration],
      });

      onClose();
    } catch (e) {
      console.error("Error extending listing:", e);
    }
  };

  const currentExpiryDate = new Date(Number(currentExpiresAt) * 1000);
  const newExpiryDate = new Date(Number(currentExpiresAt) * 1000 + parseInt(durationDays || "0") * 24 * 60 * 60 * 1000);

  const formatDate = (date: Date) => {
    return date.toLocaleDateString("en-US", {
      weekday: "short",
      year: "numeric",
      month: "short",
      day: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  // Calculate days remaining
  const daysRemaining = Math.max(0, Math.floor((currentExpiryDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24)));
  const isExpired = daysRemaining === 0;

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-backdrop bg-black/50 backdrop-blur-sm hidden sm:block" onClick={onClose} />
      <div className="modal-box relative w-full h-full max-h-full sm:h-auto sm:max-h-[90vh] sm:max-w-lg sm:rounded-2xl rounded-none flex flex-col p-0">
        <form onSubmit={handleSubmit} className="flex flex-col h-full w-full">
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
            <h3 className="font-bold text-xl">Extend Listing Duration</h3>
            <p className="text-sm opacity-60 mt-1">Add more time to keep your listing active on the marketplace.</p>
          </div>

          {/* Scrollable Content */}
          <div className="flex-1 overflow-y-auto p-4">
            <div className="flex flex-col gap-3">
              {/* Current Status */}
              <div className={`p-4 rounded-lg ${isExpired ? "bg-error/10 border border-error/30" : "bg-base-200"}`}>
                <div className="flex justify-between items-center">
                  <div>
                    <div className="text-xs uppercase opacity-50 font-bold mb-1">Current Expiry</div>
                    <div className="font-semibold">{formatDate(currentExpiryDate)}</div>
                  </div>
                  <div className={`badge ${isExpired ? "badge-error" : "badge-warning"} badge-lg`}>
                    {isExpired ? "Expired" : `${daysRemaining} days left`}
                  </div>
                </div>
              </div>

              {/* Duration Selection */}
              <div className="form-control">
                <label className="label py-0">
                  <span className="label-text text-xs font-bold uppercase opacity-60">Extend Duration</span>
                </label>
                <div className="grid grid-cols-5 gap-2 mt-2">
                  {["7", "14", "30", "60", "90"].map(days => (
                    <button
                      key={days}
                      type="button"
                      className={`btn btn-sm ${durationDays === days ? "btn-primary" : "btn-ghost bg-base-200"}`}
                      onClick={() => setDurationDays(days)}
                    >
                      {days}d
                    </button>
                  ))}
                </div>
              </div>

              {/* New Expiry Preview */}
              <div className="bg-success/10 p-4 rounded-lg border border-success/30">
                <div className="flex justify-between items-center">
                  <div>
                    <div className="text-xs uppercase opacity-50 font-bold mb-1">New Expiry</div>
                    <div className="font-semibold text-success">{formatDate(newExpiryDate)}</div>
                  </div>
                  <div className="text-right">
                    <div className="text-xs uppercase opacity-50 font-bold mb-1">Extension</div>
                    <div className="font-bold text-success">+{durationDays} days</div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Sticky Footer */}
          <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
            <div className="flex gap-3 justify-end">
              <button type="button" className="btn btn-ghost" onClick={onClose} disabled={isPending}>
                Cancel
              </button>
              <button type="submit" className="btn btn-success" disabled={isPending}>
                {isPending ? (
                  <>
                    <span className="loading loading-spinner loading-sm"></span>
                    Extending...
                  </>
                ) : (
                  "Extend Listing"
                )}
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
  );
};
