"use client";

import { useState } from "react";
import { parseUnits } from "viem";
import { useAccount } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { formatUsdc } from "~~/utils/formatters";

interface MintTokensModalProps {
  isOpen: boolean;
  onClose: () => void;
  vehicleId: string;
  vin: string;
}

export const MintTokensModal = ({ isOpen, onClose, vehicleId, vin }: MintTokensModalProps) => {
  const { address: connectedAddress } = useAccount();
  const [formData, setFormData] = useState({
    tokenPrice: "",
    tokenSupply: "",
    maturityMonths: "36",
  });
  const [isSubmitting, setIsSubmitting] = useState(false);

  const { writeContractAsync: writeVehicleRegistry } = useScaffoldWriteContract({ contractName: "VehicleRegistry" });
  const { writeContractAsync: writeMockUSDC } = useScaffoldWriteContract({ contractName: "MockUSDC" });

  const treasuryAddress = deployedContracts[31337]?.Treasury?.address;

  // Use parseUnits for USDC (6 decimals)
  const tokenPriceBigInt = formData.tokenPrice ? parseUnits(formData.tokenPrice, 6) : 0n;
  const tokenSupplyBigInt = formData.tokenSupply ? BigInt(formData.tokenSupply) : 0n;

  const { data: requiredCollateral } = useScaffoldReadContract({
    contractName: "Treasury",
    functionName: "getTotalCollateralRequirement",
    args: [tokenPriceBigInt, tokenSupplyBigInt],
    watch: true,
  });

  const { data: allowance } = useScaffoldReadContract({
    contractName: "MockUSDC",
    functionName: "allowance",
    args: [connectedAddress, treasuryAddress],
    watch: true,
  });

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!treasuryAddress) return;

    setIsSubmitting(true);
    try {
      const monthsInSeconds = BigInt(parseInt(formData.maturityMonths) * 30 * 24 * 60 * 60);
      const maturityTimestamp = BigInt(Math.floor(Date.now() / 1000)) + monthsInSeconds;

      if (requiredCollateral && (!allowance || allowance < requiredCollateral)) {
        await writeMockUSDC({
          functionName: "approve",
          args: [treasuryAddress, requiredCollateral],
        });
      }

      await writeVehicleRegistry({
        functionName: "mintRevenueTokens",
        args: [BigInt(vehicleId), tokenPriceBigInt, tokenSupplyBigInt, maturityTimestamp],
      });

      onClose();
    } catch (e) {
      console.error("Error:", e);
    } finally {
      setIsSubmitting(false);
    }
  };

  const needsApproval = requiredCollateral && (!allowance || allowance < requiredCollateral);

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
            disabled={isSubmitting}
          >
            <XMarkIcon className="h-5 w-5" />
          </button>

          {/* Header */}
          <div className="p-4 border-b border-base-200 shrink-0">
            <h3 className="font-bold text-xl">Mint Revenue Tokens</h3>
            <p className="text-sm opacity-60 mt-1">
              Configure tokenization parameters for vehicle <span className="font-mono font-bold">{vin}</span>
            </p>
          </div>

          {/* Scrollable Content */}
          <div className="flex-1 overflow-y-auto p-4">
            <div className="flex flex-col gap-3">
              <div className="divider text-xs opacity-50 my-0">Financial Terms</div>

              <div className="bg-base-200 p-4 rounded-lg border border-primary/20">
                {/* Row 1: Price and Supply */}
                <div className="grid grid-cols-2 gap-4 mb-4">
                  <div className="form-control">
                    <label className="label py-0">
                      <span className="label-text text-xs font-bold uppercase opacity-60">Price per Share (USDC)</span>
                    </label>
                    <div className="relative">
                      <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm opacity-50">$</span>
                      <input
                        type="number"
                        step="0.000001"
                        name="tokenPrice"
                        className="input input-bordered input-sm w-full pl-7"
                        value={formData.tokenPrice}
                        onChange={handleInputChange}
                        placeholder="e.g. 1.00"
                        required
                      />
                    </div>
                  </div>
                  <div className="form-control">
                    <label className="label py-0">
                      <span className="label-text text-xs font-bold uppercase opacity-60">Total Supply</span>
                    </label>
                    <input
                      type="number"
                      name="tokenSupply"
                      className="input input-bordered input-sm w-full"
                      value={formData.tokenSupply}
                      onChange={handleInputChange}
                      placeholder="e.g. 10000"
                      required
                    />
                  </div>
                </div>

                {/* Row 2: Maturity and Requirement */}
                <div className="grid grid-cols-2 gap-4 items-end">
                  <div className="form-control">
                    <label className="label py-0">
                      <span className="label-text text-xs font-bold uppercase opacity-60">Maturity Duration</span>
                    </label>
                    <select
                      name="maturityMonths"
                      className="select select-bordered select-sm w-full"
                      value={formData.maturityMonths}
                      onChange={handleInputChange}
                    >
                      <option value="36">36 Months</option>
                      <option value="48">48 Months</option>
                      <option value="60">60 Months</option>
                    </select>
                  </div>
                  <div className="flex flex-col items-end pb-1">
                    <span className="text-[10px] uppercase opacity-50 font-bold">Required Collateral</span>
                    <span className="text-sm font-bold text-primary">{formatUsdc(requiredCollateral)} USDC</span>
                  </div>
                </div>
              </div>

              {/* Info Box */}
              <div className="bg-info/10 p-3 rounded-lg text-xs">
                <p className="opacity-80">
                  You will need to deposit <span className="font-bold">{formatUsdc(requiredCollateral)} USDC</span> as
                  collateral. This amount will be locked in the Treasury until the asset matures or is settled.
                </p>
              </div>
            </div>
          </div>

          {/* Sticky Footer */}
          <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
            <div className="flex gap-3 justify-end">
              <button type="button" className="btn btn-ghost" onClick={onClose} disabled={isSubmitting}>
                Cancel
              </button>
              <button type="submit" className="btn btn-primary" disabled={isSubmitting}>
                {isSubmitting ? (
                  <>
                    <span className="loading loading-spinner loading-sm"></span>
                    Processing...
                  </>
                ) : needsApproval ? (
                  "Approve & Mint"
                ) : (
                  "Mint Tokens"
                )}
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
  );
};
