"use client";

import { useState } from "react";
import { encodeAbiParameters, parseAbiParameters, parseUnits } from "viem";
import { useAccount } from "wagmi";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { formatUsdc } from "~~/utils/formatters";
import { uploadToIpfs } from "~~/utils/ipfs";

export type RegisterMode = "REGISTER_ONLY" | "REGISTER_AND_MINT";

interface RegisterVehicleFormProps {
  onClose: () => void;
  initialMode: RegisterMode;
  onBack: () => void;
}

export const RegisterVehicleForm = ({ onClose, initialMode, onBack }: RegisterVehicleFormProps) => {
  const { address: connectedAddress } = useAccount();

  const [formData, setFormData] = useState({
    vin: "",
    make: "",
    model: "",
    year: new Date().getFullYear().toString(),
    manufacturerId: "1",
    optionCodes: "",
    odometer: "",
    odometerUnit: "mi",
    maturityMonths: "36",
    tokenPrice: "",
    tokenSupply: "",
  });

  const [imageFile, setImageFile] = useState<File | null>(null);
  const [isUploading, setIsUploading] = useState(false);

  const { writeContractAsync: writeVehicleRegistry } = useScaffoldWriteContract({ contractName: "VehicleRegistry" });
  const { writeContractAsync: writeMockUSDC } = useScaffoldWriteContract({ contractName: "MockUSDC" });

  const treasuryAddress = deployedContracts[31337]?.Treasury?.address;

  const tokenPriceBigInt = formData.tokenPrice ? parseUnits(formData.tokenPrice, 6) : 0n;
  const tokenSupplyBigInt = formData.tokenSupply ? BigInt(formData.tokenSupply) : 0n;

  const { data: requiredCollateral } = useScaffoldReadContract({
    contractName: "Treasury",
    functionName: "getTotalCollateralRequirement",
    args: [tokenPriceBigInt, tokenSupplyBigInt],
    watch: true,
    query: {
      enabled: initialMode === "REGISTER_AND_MINT",
    },
  });

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

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      setImageFile(e.target.files[0]);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsUploading(true);
    try {
      let imageURI = "";
      if (imageFile) imageURI = await uploadToIpfs(imageFile);

      const metadata = {
        name: `${formData.year} ${formData.make} ${formData.model}`,
        description: `Vehicle registered with VIN ${formData.vin}`,
        image: imageURI,
        properties: {
          make: formData.make,
          model: formData.model,
          year: parseInt(formData.year),
          vin: formData.vin,
          manufacturerId: formData.manufacturerId,
          optionCodes: formData.optionCodes,
          odometer: parseInt(formData.odometer || "0"),
          odometerUnit: formData.odometerUnit,
        },
      };

      const metadataURI = await uploadToIpfs(metadata);

      const encodedVehicleData = encodeAbiParameters(
        parseAbiParameters("string, string, string, uint256, uint256, string, string"),
        [
          formData.vin,
          formData.make,
          formData.model,
          BigInt(formData.year),
          BigInt(formData.manufacturerId),
          formData.optionCodes,
          metadataURI,
        ],
      );

      if (initialMode === "REGISTER_AND_MINT") {
        if (!treasuryAddress) return;
        const monthsInSeconds = BigInt(parseInt(formData.maturityMonths) * 30 * 24 * 60 * 60);
        const maturityTimestamp = BigInt(Math.floor(Date.now() / 1000)) + monthsInSeconds;

        if (requiredCollateral && (!allowance || allowance < requiredCollateral)) {
          await writeMockUSDC({ functionName: "approve", args: [treasuryAddress, requiredCollateral] });
        }
        await writeVehicleRegistry({
          functionName: "registerAssetAndMintTokens",
          args: [encodedVehicleData, tokenPriceBigInt, tokenSupplyBigInt, maturityTimestamp],
        });
      } else {
        await writeVehicleRegistry({ functionName: "registerAsset", args: [encodedVehicleData] });
      }
      onClose();
    } catch (e) {
      console.error("Error:", e);
    } finally {
      setIsUploading(false);
    }
  };

  const formTitle = initialMode === "REGISTER_AND_MINT" ? "Register & Mint Vehicle" : "Register Vehicle";

  return (
    <div className="flex flex-col gap-2 max-h-[85vh] overflow-y-auto px-1">
      <div className="flex justify-between items-center mb-1">
        <h3 className="font-bold text-lg flex items-center gap-2">
          <button type="button" className="btn btn-xs btn-ghost btn-circle" onClick={onBack}>
            ←
          </button>
          {formTitle}
        </h3>
      </div>

      <form onSubmit={handleSubmit} className="flex flex-col gap-3">
        {/* 1. Image */}
        <div className="form-control">
          <label className="label py-0">
            <span className="label-text text-xs">Vehicle Image</span>
          </label>
          <input
            type="file"
            className="file-input file-input-bordered file-input-sm w-full"
            onChange={handleFileChange}
            accept="image/*"
          />
        </div>

        {/* 2. Identifiers */}
        <div className="grid grid-cols-2 gap-2">
          <div className="form-control">
            <label className="label py-0">
              <span className="label-text text-xs">VIN</span>
            </label>
            <input
              type="text"
              name="vin"
              className="input input-bordered input-sm"
              value={formData.vin}
              onChange={handleInputChange}
              required
            />
          </div>
          <div className="form-control">
            <label className="label py-0">
              <span className="label-text text-xs">Manufacturer ID</span>
            </label>
            <input
              type="number"
              name="manufacturerId"
              className="input input-bordered input-sm"
              value={formData.manufacturerId}
              onChange={handleInputChange}
              required
            />
          </div>
        </div>

        {/* 3. Specs */}
        <div className="grid grid-cols-3 gap-2">
          <div className="form-control">
            <label className="label py-0">
              <span className="label-text text-xs">Make</span>
            </label>
            <input
              type="text"
              name="make"
              className="input input-bordered input-sm"
              value={formData.make}
              onChange={handleInputChange}
              required
            />
          </div>
          <div className="form-control">
            <label className="label py-0">
              <span className="label-text text-xs">Model</span>
            </label>
            <input
              type="text"
              name="model"
              className="input input-bordered input-sm"
              value={formData.model}
              onChange={handleInputChange}
              required
            />
          </div>
          <div className="form-control">
            <label className="label py-0">
              <span className="label-text text-xs">Year</span>
            </label>
            <input
              type="number"
              name="year"
              className="input input-bordered input-sm"
              value={formData.year}
              onChange={handleInputChange}
              required
            />
          </div>
        </div>

        {/* 4. Details */}
        <div className="grid grid-cols-2 gap-2">
          <div className="form-control">
            <label className="label py-0">
              <span className="label-text text-xs">Options</span>
            </label>
            <input
              type="text"
              name="optionCodes"
              placeholder="LE, NAV..."
              className="input input-bordered input-sm"
              value={formData.optionCodes}
              onChange={handleInputChange}
            />
          </div>
          <div className="form-control">
            <label className="label py-0">
              <span className="label-text text-xs">Odometer</span>
            </label>
            <div className="join w-full">
              <input
                type="number"
                name="odometer"
                className="input input-bordered input-sm join-item w-full"
                value={formData.odometer}
                onChange={handleInputChange}
              />
              <select
                name="odometerUnit"
                className="select select-bordered select-sm join-item w-fit min-w-[60px]"
                value={formData.odometerUnit}
                onChange={handleInputChange}
              >
                <option value="mi">mi</option>
                <option value="km">km</option>
              </select>
            </div>
          </div>
        </div>

        {initialMode === "REGISTER_AND_MINT" && (
          <>
            <div className="divider text-xs opacity-50 my-1">Financial Terms</div>
            <div className="bg-base-200 p-3 rounded-lg border border-primary/20">
              {/* Row 1: Price and Supply */}
              <div className="grid grid-cols-2 gap-3 mb-3">
                <div className="form-control">
                  <label className="label py-0">
                    <span className="label-text text-xs font-bold">Price (USDC)</span>
                  </label>
                  <div className="relative">
                    <span className="absolute left-3 top-1/2 -translate-y-1/2 text-xs opacity-50">$</span>
                    <input
                      type="number"
                      step="0.000001"
                      name="tokenPrice"
                      className="input input-bordered input-sm w-full pl-6"
                      value={formData.tokenPrice}
                      onChange={handleInputChange}
                      placeholder="e.g. 1.00"
                      required
                    />
                  </div>
                </div>
                <div className="form-control">
                  <label className="label py-0">
                    <span className="label-text text-xs font-bold">Total Supply</span>
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
              <div className="grid grid-cols-2 gap-3 items-end">
                <div className="form-control">
                  <label className="label py-0">
                    <span className="label-text text-xs font-bold">Maturity Duration</span>
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
            <div className="bg-info/10 p-3 rounded-lg text-xs mt-3">
              <p className="opacity-80">
                You will need to deposit <span className="font-bold">{formatUsdc(requiredCollateral)} USDC</span> as
                collateral. This amount will be locked in the Treasury until the asset matures or is settled.
              </p>
            </div>
          </>
        )}

        <div className="flex gap-2 mt-2">
          <button type="button" className="btn btn-sm flex-1" onClick={onClose} disabled={isUploading}>
            Cancel
          </button>
          <button type="submit" className="btn btn-sm btn-primary flex-[2]" disabled={isUploading}>
            {isUploading ? <span className="loading loading-spinner loading-xs"></span> : null}
            {isUploading
              ? "Processing IPFS..."
              : initialMode === "REGISTER_AND_MINT" &&
                  requiredCollateral &&
                  (!allowance || allowance < requiredCollateral)
                ? "Approve & Mint"
                : "Submit"}
          </button>
        </div>
      </form>
    </div>
  );
};
