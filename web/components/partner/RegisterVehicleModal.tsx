"use client";

import { useState } from "react";
import { encodeAbiParameters, parseAbiParameters, parseUnits } from "viem";
import { useAccount } from "wagmi";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { formatUsdc } from "~~/utils/formatters";

type RegisterMode = "REGISTER_ONLY" | "REGISTER_AND_MINT";

interface RegisterVehicleModalProps {
  isOpen: boolean;
  onClose: () => void;
  initialMode: RegisterMode;
}

export const RegisterVehicleModal = ({ isOpen, onClose, initialMode }: RegisterVehicleModalProps) => {
  const { address: connectedAddress } = useAccount();

  const [formData, setFormData] = useState({
    vin: "",
    make: "",
    model: "",
    year: new Date().getFullYear().toString(),
    manufacturerId: "1",
    optionCodes: "",
    dynamicMetadataURI: "",
    maturityMonths: "36",
    tokenPrice: "",
    tokenSupply: "",
  });

  const { writeContractAsync: writeVehicleRegistry } = useScaffoldWriteContract({ contractName: "VehicleRegistry" });
  const { writeContractAsync: writeMockUSDC } = useScaffoldWriteContract({ contractName: "MockUSDC" });

  const treasuryAddress = deployedContracts[31337]?.Treasury?.address;

  // Use parseUnits to handle USDC decimals (6)
  const tokenPriceBigInt = formData.tokenPrice ? parseUnits(formData.tokenPrice, 6) : 0n;
  const tokenSupplyBigInt = formData.tokenSupply ? BigInt(formData.tokenSupply) : 0n;

  // Read required collateral (only needed if minting)
  const { data: requiredCollateral } = useScaffoldReadContract({
    contractName: "Treasury",
    functionName: "getTotalCollateralRequirement",
    args: [tokenPriceBigInt, tokenSupplyBigInt],
    watch: true,
    query: {
      enabled: initialMode === "REGISTER_AND_MINT",
    },
  });

  // Read allowance
  const { data: allowance } = useScaffoldReadContract({
    contractName: "MockUSDC",
    functionName: "allowance",
    args: [connectedAddress, treasuryAddress],
    watch: true,
    query: {
      enabled: initialMode === "REGISTER_AND_MINT",
    },
  });

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();

    try {
      const currentTimestamp = BigInt(Math.floor(Date.now() / 1000));
      const monthsInSeconds = BigInt(parseInt(formData.maturityMonths) * 30 * 24 * 60 * 60);
      const maturityTimestamp = currentTimestamp + monthsInSeconds;

      const encodedData = encodeAbiParameters(
        parseAbiParameters("string, string, string, uint256, uint256, string, string, uint256"),
        [
          formData.vin,
          formData.make,
          formData.model,
          BigInt(formData.year),
          BigInt(formData.manufacturerId),
          formData.optionCodes,
          formData.dynamicMetadataURI,
          maturityTimestamp,
        ],
      );

      if (initialMode === "REGISTER_AND_MINT") {
        if (!treasuryAddress) return alert("Treasury not found");

        // Check Approval
        if (requiredCollateral && (!allowance || allowance < requiredCollateral)) {
          await writeMockUSDC({
            functionName: "approve",
            args: [treasuryAddress, requiredCollateral],
          });
        }

        await writeVehicleRegistry({
          functionName: "registerAssetAndMintTokens",
          args: [encodedData, tokenPriceBigInt, tokenSupplyBigInt],
        });
      } else {
        // Register Only
        await writeVehicleRegistry({
          functionName: "registerAsset",
          args: [encodedData],
        });
      }

      onClose();
      // Optional: Trigger a refresh or toast
    } catch (e) {
      console.error("Error:", e);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-box max-w-2xl">
        <h3 className="font-bold text-lg mb-4">Register New Vehicle</h3>

        {/* Mode Display - now driven by initialMode prop */}
        <div className="alert alert-info mb-4">
          You are in <strong>{initialMode === "REGISTER_AND_MINT" ? "Register & Mint" : "Register Only"}</strong> mode.
        </div>

        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="form-control">
              <label className="label">
                <span className="label-text">VIN</span>
              </label>
              <input
                type="text"
                name="vin"
                className="input input-bordered"
                value={formData.vin}
                onChange={handleInputChange}
                required
              />
            </div>
            <div className="form-control">
              <label className="label">
                <span className="label-text">Year</span>
              </label>
              <input
                type="number"
                name="year"
                className="input input-bordered"
                value={formData.year}
                onChange={handleInputChange}
                required
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="form-control">
              <label className="label">
                <span className="label-text">Make</span>
              </label>
              <input
                type="text"
                name="make"
                className="input input-bordered"
                value={formData.make}
                onChange={handleInputChange}
                required
              />
            </div>
            <div className="form-control">
              <label className="label">
                <span className="label-text">Model</span>
              </label>
              <input
                type="text"
                name="model"
                className="input input-bordered"
                value={formData.model}
                onChange={handleInputChange}
                required
              />
            </div>
          </div>

          <div className="form-control">
            <label className="label">
              <span className="label-text">Metadata URI</span>
            </label>
            <input
              type="text"
              name="dynamicMetadataURI"
              placeholder="ipfs://..."
              className="input input-bordered"
              value={formData.dynamicMetadataURI}
              onChange={handleInputChange}
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="form-control">
              <label className="label">
                <span className="label-text">Maturity</span>
              </label>
              <select
                name="maturityMonths"
                className="select select-bordered"
                value={formData.maturityMonths}
                onChange={handleInputChange}
              >
                <option value="36">36 Months</option>
                <option value="48">48 Months</option>
                <option value="60">60 Months</option>
              </select>
            </div>
            <div className="form-control">
              <label className="label">
                <span className="label-text">Manufacturer ID</span>
              </label>
              <input
                type="number"
                name="manufacturerId"
                className="input input-bordered"
                value={formData.manufacturerId}
                onChange={handleInputChange}
                required
              />
            </div>
          </div>

          {initialMode === "REGISTER_AND_MINT" && (
            <>
              <div className="divider">Tokenization</div>
              <div className="grid grid-cols-2 gap-4">
                <div className="form-control">
                  <label className="label">
                    <span className="label-text">Price (USDC)</span>
                  </label>
                  <label className="input-group">
                    <span>$</span>
                    <input
                      type="number"
                      step="0.000001"
                      name="tokenPrice"
                      className="input input-bordered w-full"
                      value={formData.tokenPrice}
                      onChange={handleInputChange}
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
                    name="tokenSupply"
                    className="input input-bordered"
                    value={formData.tokenSupply}
                    onChange={handleInputChange}
                    required
                  />
                </div>
              </div>
              <div className="alert alert-info shadow-sm text-xs">
                Required Collateral: {formatUsdc(requiredCollateral)} USDC
              </div>
            </>
          )}

          <div className="modal-action">
            <button type="button" className="btn" onClick={onClose}>
              Cancel
            </button>
            <button type="submit" className="btn btn-primary">
              {initialMode === "REGISTER_AND_MINT" &&
              requiredCollateral &&
              (!allowance || allowance < requiredCollateral)
                ? "Approve & Mint"
                : "Submit"}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
