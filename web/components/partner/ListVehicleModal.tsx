"use client";

import { useState } from "react";
import { parseUnits } from "viem";
import { useAccount } from "wagmi";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

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

  const { writeContractAsync: writeMarketplace } = useScaffoldWriteContract({ contractName: "Marketplace" });
  const { writeContractAsync: writeRoboshareTokens } = useScaffoldWriteContract({ contractName: "RoboshareTokens" });

  const marketplaceAddress = deployedContracts[31337]?.Marketplace?.address;

  const { data: isApproved } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "isApprovedForAll",
    args: [connectedAddress, marketplaceAddress],
    watch: true,
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!marketplaceAddress) return;

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
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-box">
        <h3 className="font-bold text-lg mb-4">List Tokens for {vin}</h3>
        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <div className="form-control">
            <label className="label">
              <span className="label-text">Amount to List</span>
            </label>
            <input
              type="number"
              className="input input-bordered"
              value={formData.amount}
              onChange={e => setFormData(prev => ({ ...prev, amount: e.target.value }))}
              required
            />
          </div>
          <div className="form-control">
            <label className="label">
              <span className="label-text">Price per Token (USDC)</span>
            </label>
            <label className="input-group">
              <span>$</span>
              <input
                type="number"
                step="0.000001"
                className="input input-bordered w-full"
                value={formData.pricePerToken}
                onChange={e => setFormData(prev => ({ ...prev, pricePerToken: e.target.value }))}
                required
              />
            </label>
          </div>
          <div className="form-control">
            <label className="label">
              <span className="label-text">Duration (Days)</span>
            </label>
            <input
              type="number"
              className="input input-bordered"
              value={formData.durationDays}
              onChange={e => setFormData(prev => ({ ...prev, durationDays: e.target.value }))}
              required
            />
          </div>

          <div className="modal-action">
            <button type="button" className="btn" onClick={onClose}>
              Cancel
            </button>
            <button type="submit" className="btn btn-primary">
              {!isApproved ? "Approve & List" : "List for Sale"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
