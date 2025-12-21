"use client";

import { useState } from "react";
import { parseUnits } from "viem";
import { useAccount } from "wagmi";
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

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!treasuryAddress) return;

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
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-box">
        <h3 className="font-bold text-lg mb-4 text-center">Mint Revenue Tokens for {vin}</h3>
        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="form-control">
              <label className="label py-0">
                <span className="label-text text-xs font-bold">Maturity Duration</span>
              </label>
              <select
                className="select select-bordered select-sm"
                value={formData.maturityMonths}
                onChange={e => setFormData(prev => ({ ...prev, maturityMonths: e.target.value }))}
              >
                <option value="36">36 Months</option>
                <option value="48">48 Months</option>
                <option value="60">60 Months</option>
              </select>
            </div>
            <div className="form-control">
              <label className="label py-0">
                <span className="label-text text-xs font-bold">Total Supply</span>
              </label>
              <input
                type="number"
                className="input input-bordered input-sm"
                value={formData.tokenSupply}
                onChange={e => setFormData(prev => ({ ...prev, tokenSupply: e.target.value }))}
                required
              />
            </div>
          </div>

          <div className="form-control">
            <label className="label py-0">
              <span className="label-text text-xs font-bold">Price per Share (USDC)</span>
            </label>
            <label className="input-group">
              <span className="bg-base-200 text-xs px-3">$</span>
              <input
                type="number"
                step="0.000001"
                className="input input-bordered input-sm w-full"
                value={formData.tokenPrice}
                onChange={e => setFormData(prev => ({ ...prev, tokenPrice: e.target.value }))}
                required
              />
            </label>
          </div>

          <div className="alert alert-info shadow-sm text-xs py-2">
            <div className="flex justify-between w-full font-bold">
              <span>Required Collateral:</span>
              <span>{formatUsdc(requiredCollateral)} USDC</span>
            </div>
          </div>

          <div className="modal-action">
            <button type="button" className="btn btn-sm" onClick={onClose}>
              Cancel
            </button>
            <button type="submit" className="btn btn-sm btn-primary">
              {requiredCollateral && (!allowance || allowance < requiredCollateral) ? "Approve & Mint" : "Mint Tokens"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
