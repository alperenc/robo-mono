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
  });

  const { writeContractAsync: writeVehicleRegistry } = useScaffoldWriteContract("VehicleRegistry");
  const { writeContractAsync: writeMockUSDC } = useScaffoldWriteContract("MockUSDC");

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
      if (requiredCollateral && (!allowance || allowance < requiredCollateral)) {
        await writeMockUSDC({
          functionName: "approve",
          args: [treasuryAddress, requiredCollateral],
        });
      }

      await writeVehicleRegistry({
        functionName: "mintRevenueTokens",
        args: [BigInt(vehicleId), tokenPriceBigInt, tokenSupplyBigInt],
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
        <h3 className="font-bold text-lg mb-4">Mint Tokens for {vin}</h3>
        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <div className="form-control">
            <label className="label">
              <span className="label-text">Price (USDC)</span>
            </label>
            <label className="input-group">
              <span>$</span>
              <input
                type="number"
                step="0.000001"
                className="input input-bordered w-full"
                value={formData.tokenPrice}
                onChange={e => setFormData(prev => ({ ...prev, tokenPrice: e.target.value }))}
                required
              />
            </label>
          </div>
          <div className="form-control">
            <label className="label">
              <span className="label-text">Supply</span>
            </label>
            <input
              type="number"
              className="input input-bordered"
              value={formData.tokenSupply}
              onChange={e => setFormData(prev => ({ ...prev, tokenSupply: e.target.value }))}
              required
            />
          </div>

          <div className="alert alert-info shadow-sm text-xs">
            Required Collateral: {formatUsdc(requiredCollateral)} USDC
          </div>
          <div className="modal-action">
            <button type="button" className="btn" onClick={onClose}>
              Cancel
            </button>
            <button type="submit" className="btn btn-primary">
              {requiredCollateral && (!allowance || allowance < requiredCollateral) ? "Approve & Mint" : "Mint"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
