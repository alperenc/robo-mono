"use client";

import { useState } from "react";
import { parseUnits } from "viem";
import { useAccount } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { formatUsdc } from "~~/utils/formatters";

interface ListVehicleModalProps {
  isOpen: boolean;
  onClose: () => void;
  vehicleId: string;
  vin: string;
}

export const ListVehicleModal = ({ isOpen, onClose, vehicleId, vin }: ListVehicleModalProps) => {
  const { address: connectedAddress } = useAccount();
  const [formData, setFormData] = useState({
    amount: "",
    pricePerToken: "",
    durationDays: "30",
  });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const { writeContractAsync: writeMarketplace } = useScaffoldWriteContract({ contractName: "Marketplace" });
  const { writeContractAsync: writeRoboshareTokens } = useScaffoldWriteContract({ contractName: "RoboshareTokens" });

  const marketplaceAddress = deployedContracts[31337]?.Marketplace?.address;

  const { data: isApproved } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "isApprovedForAll",
    args: [connectedAddress, marketplaceAddress],
    watch: true,
  });

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!marketplaceAddress) return;

    setIsSubmitting(true);
    try {
      const tokenId = BigInt(vehicleId) + 1n; // Revenue Token ID
      const durationSeconds = BigInt(parseInt(formData.durationDays) * 24 * 60 * 60);
      const priceBigInt = parseUnits(formData.pricePerToken, 6);

      // 1. Approve if needed
      if (!isApproved) {
        await writeRoboshareTokens({
          functionName: "setApprovalForAll",
          args: [marketplaceAddress, true],
        });
      }

      // 2. Create Listing
      await writeMarketplace({
        functionName: "createListing",
        args: [
          tokenId,
          BigInt(formData.amount),
          priceBigInt,
          durationSeconds,
          false, // buyerPaysFee
        ],
      });

      onClose();
    } catch (e) {
      console.error("Error listing vehicle:", e);
    } finally {
      setIsSubmitting(false);
    }
  };

  // Calculate total value
  const totalValue =
    formData.amount && formData.pricePerToken ? parseUnits(formData.pricePerToken, 6) * BigInt(formData.amount) : 0n;

  // Calculate expiry date
  const expiryDate = new Date(Date.now() + parseInt(formData.durationDays || "0") * 24 * 60 * 60 * 1000);
  const formatDate = (date: Date) =>
    date.toLocaleDateString("en-US", {
      weekday: "short",
      month: "short",
      day: "numeric",
      year: "numeric",
    });

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-backdrop bg-black/50 backdrop-blur-sm" onClick={onClose} />
      <div className="modal-box relative max-w-lg">
        {/* Close Button */}
        <button
          className="btn btn-sm btn-circle btn-ghost absolute right-3 top-3"
          onClick={onClose}
          disabled={isSubmitting}
        >
          <XMarkIcon className="h-5 w-5" />
        </button>

        {/* Header */}
        <div className="mb-6">
          <h3 className="font-bold text-xl">List Tokens for Sale</h3>
          <p className="text-sm opacity-60 mt-1">
            List revenue tokens for vehicle <span className="font-mono font-bold">{vin}</span> on the marketplace.
          </p>
        </div>

        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <div className="divider text-xs opacity-50 my-0">Listing Details</div>

          <div className="bg-base-200 p-4 rounded-lg border border-primary/20">
            {/* Row 1: Amount and Price */}
            <div className="grid grid-cols-2 gap-4 mb-4">
              <div className="form-control">
                <label className="label py-0">
                  <span className="label-text text-xs font-bold uppercase opacity-60">Tokens to List</span>
                </label>
                <input
                  type="number"
                  name="amount"
                  className="input input-bordered input-sm w-full"
                  value={formData.amount}
                  onChange={handleInputChange}
                  placeholder="e.g. 1000"
                  required
                />
              </div>
              <div className="form-control">
                <label className="label py-0">
                  <span className="label-text text-xs font-bold uppercase opacity-60">Price per Token (USDC)</span>
                </label>
                <div className="relative">
                  <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm opacity-50">$</span>
                  <input
                    type="number"
                    step="0.000001"
                    name="pricePerToken"
                    className="input input-bordered input-sm w-full pl-7"
                    value={formData.pricePerToken}
                    onChange={handleInputChange}
                    placeholder="e.g. 1.00"
                    required
                  />
                </div>
              </div>
            </div>

            {/* Row 2: Duration */}
            <div className="grid grid-cols-2 gap-4 items-end">
              <div className="form-control">
                <label className="label py-0">
                  <span className="label-text text-xs font-bold uppercase opacity-60">Listing Duration</span>
                </label>
                <select
                  name="durationDays"
                  className="select select-bordered select-sm w-full"
                  value={formData.durationDays}
                  onChange={handleInputChange}
                >
                  <option value="7">7 Days</option>
                  <option value="14">14 Days</option>
                  <option value="30">30 Days</option>
                  <option value="60">60 Days</option>
                  <option value="90">90 Days</option>
                </select>
              </div>
              <div className="flex flex-col items-end pb-1">
                <span className="text-[10px] uppercase opacity-50 font-bold">Expires On</span>
                <span className="text-sm font-bold text-primary">{formatDate(expiryDate)}</span>
              </div>
            </div>
          </div>

          {/* Summary Box */}
          <div className="bg-success/10 p-3 rounded-lg text-xs">
            <div className="flex justify-between items-center">
              <span className="opacity-80">Total Listing Value:</span>
              <span className="font-bold text-success text-sm">{formatUsdc(totalValue)} USDC</span>
            </div>
          </div>

          {/* Info Box */}
          <div className="bg-info/10 p-3 rounded-lg text-xs">
            <p className="opacity-80">
              Your tokens will be transferred to the Marketplace contract and listed for sale. Buyers can purchase
              partial amounts. Unsold tokens can be reclaimed by ending the listing.
            </p>
          </div>

          {/* Actions */}
          <div className="modal-action mt-2">
            <button type="button" className="btn btn-ghost" onClick={onClose} disabled={isSubmitting}>
              Cancel
            </button>
            <button type="submit" className="btn btn-primary" disabled={isSubmitting}>
              {isSubmitting ? (
                <>
                  <span className="loading loading-spinner loading-sm"></span>
                  Processing...
                </>
              ) : !isApproved ? (
                "Approve & List"
              ) : (
                "List for Sale"
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
