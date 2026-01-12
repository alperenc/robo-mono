"use client";

import { useState } from "react";
import { encodeAbiParameters, parseAbiParameters, parseUnits } from "viem";
import { useAccount } from "wagmi";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { formatUsdc } from "~~/utils/formatters";
import { uploadToIpfs } from "~~/utils/ipfs";
import { notification } from "~~/utils/scaffold-eth";

// maxStep determines how far the user can go:
// 1 = Register only, 2 = Register & Mint, 3 = List Vehicle
interface RegisterVehicleFormProps {
  onClose: () => void;
  maxStep: 1 | 2 | 3;
  onBack: () => void;
}

const STEP_TITLES = {
  1: "Vehicle Details",
  2: "Financial Terms",
  3: "Marketplace Listing",
};

export const RegisterVehicleForm = ({ onClose, maxStep, onBack }: RegisterVehicleFormProps) => {
  const { address: connectedAddress } = useAccount();
  const [currentStep, setCurrentStep] = useState(1);
  const [isProcessing, setIsProcessing] = useState(false);
  const [processedData, setProcessedData] = useState<{ encodedVehicleData: `0x${string}` } | null>(null);

  const [formData, setFormData] = useState({
    // Step 1: Vehicle Details
    vin: "",
    make: "",
    model: "",
    year: new Date().getFullYear().toString(),
    manufacturerId: "1",
    optionCodes: "",
    odometer: "",
    odometerUnit: "mi",
    // Step 2: Financial Terms
    maturityMonths: "36",
    tokenPrice: "",
    tokenSupply: "",
    // Step 3: Listing
    listingDurationDays: "30",
    buyerPaysFee: false,
  });

  const [imageFile, setImageFile] = useState<File | null>(null);

  const { writeContractAsync: writeVehicleRegistry } = useScaffoldWriteContract({ contractName: "VehicleRegistry" });
  const { writeContractAsync: writeMockUSDC } = useScaffoldWriteContract({ contractName: "MockUSDC" });
  const { writeContractAsync: writeRoboshareTokens } = useScaffoldWriteContract({ contractName: "RoboshareTokens" });

  const treasuryAddress = deployedContracts[31337]?.Treasury?.address;
  const marketplaceAddress = deployedContracts[31337]?.Marketplace?.address;

  const tokenPriceBigInt = formData.tokenPrice ? parseUnits(formData.tokenPrice, 6) : 0n;
  const tokenSupplyBigInt = formData.tokenSupply ? BigInt(formData.tokenSupply) : 0n;

  const { data: requiredCollateral } = useScaffoldReadContract({
    contractName: "Treasury",
    functionName: "getTotalCollateralRequirement",
    args: [tokenPriceBigInt, tokenSupplyBigInt],
    watch: true,
    query: { enabled: currentStep >= 2 },
  });

  const { data: isApproved } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "isApprovedForAll",
    args: [connectedAddress, marketplaceAddress],
    watch: true,
    query: { enabled: currentStep >= 3 },
  });

  const { data: allowance } = useScaffoldReadContract({
    contractName: "MockUSDC",
    functionName: "allowance",
    args: [connectedAddress, treasuryAddress],
    watch: true,
    query: { enabled: currentStep >= 2 },
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

  // Process IPFS upload and encode vehicle data (done when moving past Step 1)
  const processVehicleData = async () => {
    setIsProcessing(true);
    try {
      let imageUri = "";
      if (imageFile) {
        imageUri = await uploadToIpfs(imageFile);
      }

      const metadata = {
        vin: formData.vin,
        make: formData.make,
        model: formData.model,
        year: parseInt(formData.year),
        image: imageUri,
        optionCodes: formData.optionCodes
          .split(",")
          .map(s => s.trim())
          .filter(Boolean),
        odometer: formData.odometer ? parseInt(formData.odometer) : 0,
        odometerUnit: formData.odometerUnit,
      };

      // Upload metadata JSON to IPFS (uploadToIpfs handles object->blob conversion)
      const metadataUri = await uploadToIpfs(metadata);

      // Encode all 7 fields as expected by the contract:
      // (string vin, string make, string model, uint256 year, uint256 manufacturerId, string optionCodes, string dynamicMetadataURI)
      const encodedVehicleData = encodeAbiParameters(
        parseAbiParameters(
          "string vin, string make, string model, uint256 year, uint256 manufacturerId, string optionCodes, string dynamicMetadataURI",
        ),
        [
          formData.vin,
          formData.make,
          formData.model,
          BigInt(formData.year),
          BigInt(formData.manufacturerId),
          formData.optionCodes,
          metadataUri,
        ],
      );

      setProcessedData({ encodedVehicleData });
      return encodedVehicleData;
    } catch (e) {
      console.error("Error processing vehicle data:", e);
      notification.error(`IPFS upload failed: ${e instanceof Error ? e.message : "Unknown error"}`);
      throw e;
    } finally {
      setIsProcessing(false);
    }
  };

  // Step 1 action: Register only
  const handleRegisterOnly = async () => {
    setIsProcessing(true);
    try {
      const encodedData = processedData?.encodedVehicleData ?? (await processVehicleData());
      if (!encodedData) throw new Error("Failed to encode vehicle data");

      await writeVehicleRegistry({
        functionName: "registerAsset",
        args: [encodedData],
      });
      onClose();
    } catch (e) {
      console.error("Error:", e);
      notification.error(`Registration failed: ${e instanceof Error ? e.message : "Unknown error"}`);
    } finally {
      setIsProcessing(false);
    }
  };

  // Step 2 action: Register & Mint
  const handleRegisterAndMint = async () => {
    setIsProcessing(true);
    try {
      const encodedData = processedData?.encodedVehicleData ?? (await processVehicleData());
      if (!encodedData) throw new Error("Failed to encode vehicle data");

      const maturityTimestamp = BigInt(
        Math.floor(Date.now() / 1000) + parseInt(formData.maturityMonths) * 30 * 24 * 60 * 60,
      );

      // Approve USDC if needed (wait for confirmation)
      if (requiredCollateral && (!allowance || allowance < requiredCollateral)) {
        await writeMockUSDC(
          {
            functionName: "approve",
            args: [treasuryAddress, requiredCollateral],
          },
          { blockConfirmations: 1 },
        );
      }

      await writeVehicleRegistry({
        functionName: "registerAssetAndMintTokens",
        args: [encodedData, tokenPriceBigInt, tokenSupplyBigInt, maturityTimestamp],
      });
      onClose();
    } catch (e) {
      console.error("Error:", e);
      notification.error(`Registration failed: ${e instanceof Error ? e.message : "Unknown error"}`);
    } finally {
      setIsProcessing(false);
    }
  };

  // Step 3 action: Register, Mint & List
  const handleRegisterMintAndList = async () => {
    setIsProcessing(true);
    try {
      const encodedData = processedData?.encodedVehicleData ?? (await processVehicleData());
      if (!encodedData) throw new Error("Failed to encode vehicle data");

      const maturityTimestamp = BigInt(
        Math.floor(Date.now() / 1000) + parseInt(formData.maturityMonths) * 30 * 24 * 60 * 60,
      );
      const listingDurationSeconds = BigInt(parseInt(formData.listingDurationDays) * 24 * 60 * 60);

      // Step 1: Approve USDC for collateral if needed (wait for confirmation)
      if (requiredCollateral && (!allowance || allowance < requiredCollateral)) {
        await writeMockUSDC(
          {
            functionName: "approve",
            args: [treasuryAddress, requiredCollateral],
          },
          { blockConfirmations: 1 },
        );
      }

      // Step 2: Approve marketplace for tokens if needed (wait for confirmation)
      if (!isApproved) {
        await writeRoboshareTokens(
          {
            functionName: "setApprovalForAll",
            args: [marketplaceAddress, true],
          },
          { blockConfirmations: 1 },
        );
      }

      // Step 3: Execute the main transaction

      await writeVehicleRegistry({
        functionName: "registerAssetMintAndList",
        args: [
          encodedData,
          tokenPriceBigInt,
          tokenSupplyBigInt,
          maturityTimestamp,
          listingDurationSeconds,
          formData.buyerPaysFee,
        ],
      });
      onClose();
    } catch (e) {
      console.error("Error:", e);
      notification.error(`Transaction failed: ${e instanceof Error ? e.message : "Unknown error"}`);
    } finally {
      setIsProcessing(false);
    }
  };

  const handleNext = async () => {
    if (currentStep === 1 && !processedData) {
      try {
        await processVehicleData();
      } catch (e) {
        console.error("Failed to process vehicle data:", e);
        return; // Don't proceed if IPFS upload failed
      }
    }
    setCurrentStep(prev => Math.min(prev + 1, 3));
  };

  const handleBack = () => {
    if (currentStep === 1) {
      onBack();
    } else {
      setCurrentStep(prev => prev - 1);
    }
  };

  // Step action labels and handlers
  const stepActions = {
    1: { label: "Register", action: handleRegisterOnly },
    2: { label: "Register & Mint", action: handleRegisterAndMint },
    3: { label: "List Vehicle", action: handleRegisterMintAndList },
  };

  // Hint text for continue button
  const continueHints = {
    1: "Continue to tokenize",
    2: "Continue to list",
  };

  // Determine primary and secondary actions based on maxStep and currentStep
  const getActions = () => {
    const currentStepAction = stepActions[currentStep as keyof typeof stepActions];
    const continueHint = continueHints[currentStep as keyof typeof continueHints];
    const canContinue = currentStep < 3;

    if (currentStep < maxStep) {
      return {
        primary: { label: `${continueHint} →`, action: handleNext },
        secondary: canContinue ? { label: currentStepAction.label, action: currentStepAction.action } : null,
      };
    } else if (currentStep === maxStep) {
      return {
        primary: { label: currentStepAction.label, action: currentStepAction.action },
        secondary: canContinue ? { label: `${continueHint} →`, action: handleNext } : null,
      };
    } else {
      return {
        primary: canContinue
          ? { label: `${continueHint} →`, action: handleNext }
          : { label: currentStepAction.label, action: currentStepAction.action },
        secondary: canContinue ? { label: currentStepAction.label, action: currentStepAction.action } : null,
      };
    }
  };

  const { primary, secondary } = getActions();

  return (
    <div className="flex flex-col h-full">
      {/* Header */}
      <div className="flex items-center px-4 py-3 border-b border-base-200 shrink-0">
        <h3 className="font-bold text-lg flex items-center gap-2">
          <button type="button" className="btn btn-xs btn-ghost btn-circle" onClick={handleBack}>
            ←
          </button>
          {STEP_TITLES[currentStep as keyof typeof STEP_TITLES]}
        </h3>
      </div>

      {/* Step indicator */}
      <div className="flex justify-center items-center gap-2 py-2 border-b border-base-200 shrink-0">
        {[1, 2, 3].map(step => (
          <div key={step} className="flex items-center gap-2">
            <div
              className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold ${
                step <= currentStep ? "bg-primary text-primary-content" : "bg-base-300 text-base-content/50"
              }`}
            >
              {step}
            </div>
            {step < 3 && <div className={`w-8 h-0.5 ${step < currentStep ? "bg-primary" : "bg-base-300"}`} />}
          </div>
        ))}
      </div>

      {/* Scrollable content */}
      <div className="flex-1 overflow-y-auto p-5">
        {/* Step 1: Vehicle Details */}
        {currentStep === 1 && (
          <div className="flex flex-col justify-between h-full gap-6">
            {/* Image Upload Section */}
            <div className="bg-base-200 rounded-xl p-4">
              <label className="block text-sm font-medium mb-2">Vehicle Image</label>
              <input
                type="file"
                className="file-input file-input-bordered w-full"
                onChange={handleFileChange}
                accept="image/*"
              />
              <p className="text-xs opacity-60 mt-2">Upload a photo of your vehicle (optional)</p>
            </div>

            {/* Vehicle Identification */}
            <div className="bg-base-200 rounded-xl p-4 space-y-4">
              <h4 className="font-semibold text-sm uppercase tracking-wide opacity-70">Vehicle Identification</h4>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="form-control">
                  <label className="label pb-1">
                    <span className="label-text font-medium">VIN</span>
                  </label>
                  <input
                    type="text"
                    name="vin"
                    className="input input-bordered w-full"
                    value={formData.vin}
                    onChange={handleInputChange}
                    placeholder="Enter 17-character VIN"
                    required
                  />
                </div>
                <div className="form-control">
                  <label className="label pb-1">
                    <span className="label-text font-medium">Manufacturer ID</span>
                  </label>
                  <input
                    type="number"
                    name="manufacturerId"
                    className="input input-bordered w-full"
                    value={formData.manufacturerId}
                    onChange={handleInputChange}
                    required
                  />
                </div>
              </div>
            </div>

            {/* Vehicle Details */}
            <div className="bg-base-200 rounded-xl p-4 space-y-4">
              <h4 className="font-semibold text-sm uppercase tracking-wide opacity-70">Vehicle Details</h4>
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
                <div className="form-control">
                  <label className="label pb-1">
                    <span className="label-text font-medium">Make</span>
                  </label>
                  <input
                    type="text"
                    name="make"
                    className="input input-bordered w-full"
                    value={formData.make}
                    onChange={handleInputChange}
                    placeholder="e.g. Tesla"
                    required
                  />
                </div>
                <div className="form-control">
                  <label className="label pb-1">
                    <span className="label-text font-medium">Model</span>
                  </label>
                  <input
                    type="text"
                    name="model"
                    className="input input-bordered w-full"
                    value={formData.model}
                    onChange={handleInputChange}
                    placeholder="e.g. Model 3"
                    required
                  />
                </div>
                <div className="form-control col-span-2 sm:col-span-1">
                  <label className="label pb-1">
                    <span className="label-text font-medium">Year</span>
                  </label>
                  <input
                    type="number"
                    name="year"
                    className="input input-bordered w-full"
                    value={formData.year}
                    onChange={handleInputChange}
                    required
                  />
                </div>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="form-control">
                  <label className="label pb-1">
                    <span className="label-text font-medium">Option Codes</span>
                    <span className="label-text-alt opacity-50">Optional</span>
                  </label>
                  <input
                    type="text"
                    name="optionCodes"
                    className="input input-bordered w-full"
                    value={formData.optionCodes}
                    onChange={handleInputChange}
                    placeholder="e.g. AD15,PMNG"
                  />
                </div>
                <div className="form-control">
                  <label className="label pb-1">
                    <span className="label-text font-medium">Odometer</span>
                    <span className="label-text-alt opacity-50">Optional</span>
                  </label>
                  <div className="join w-full">
                    <input
                      type="number"
                      name="odometer"
                      className="input input-bordered join-item w-full"
                      value={formData.odometer}
                      onChange={handleInputChange}
                      placeholder="Current mileage"
                    />
                    <select
                      name="odometerUnit"
                      className="select select-bordered join-item"
                      value={formData.odometerUnit}
                      onChange={handleInputChange}
                    >
                      <option value="mi">mi</option>
                      <option value="km">km</option>
                    </select>
                  </div>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Step 2: Financial Terms */}
        {currentStep === 2 && (
          <div className="flex flex-col justify-between h-full gap-6">
            {/* Token Configuration */}
            <div className="bg-base-200 rounded-xl p-4 space-y-4">
              <h4 className="font-semibold text-sm uppercase tracking-wide opacity-70">Token Configuration</h4>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="form-control">
                  <label className="label pb-1">
                    <span className="label-text font-medium">Token Price (USDC)</span>
                  </label>
                  <div className="join w-full">
                    <span className="join-item flex items-center px-4 bg-base-300 font-medium">$</span>
                    <input
                      type="number"
                      name="tokenPrice"
                      className="input input-bordered join-item w-full"
                      value={formData.tokenPrice}
                      onChange={handleInputChange}
                      placeholder="e.g. 100"
                      step="0.01"
                      required
                    />
                  </div>
                </div>
                <div className="form-control">
                  <label className="label pb-1">
                    <span className="label-text font-medium">Total Supply</span>
                  </label>
                  <input
                    type="number"
                    name="tokenSupply"
                    className="input input-bordered w-full"
                    value={formData.tokenSupply}
                    onChange={handleInputChange}
                    placeholder="e.g. 10000"
                    required
                  />
                </div>
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 items-end">
                <div className="form-control">
                  <label className="label pb-1">
                    <span className="label-text font-medium">Maturity Duration</span>
                  </label>
                  <select
                    name="maturityMonths"
                    className="select select-bordered w-full"
                    value={formData.maturityMonths}
                    onChange={handleInputChange}
                  >
                    <option value="36">36 Months (3 years)</option>
                    <option value="48">48 Months (4 years)</option>
                    <option value="60">60 Months (5 years)</option>
                  </select>
                </div>
                <div className="bg-primary/10 rounded-lg p-3 text-center">
                  <span className="text-xs uppercase opacity-60 font-bold block">Required Collateral</span>
                  <span className="text-xl font-bold text-primary">{formatUsdc(requiredCollateral)} USDC</span>
                </div>
              </div>
            </div>

            {/* Info Notice */}
            <div className="bg-info/10 border border-info/20 rounded-xl p-4">
              <p className="text-sm">
                💰 You will need to deposit <span className="font-bold">{formatUsdc(requiredCollateral)} USDC</span> as
                collateral. This is released proportionally as you distribute revenues to token holders.
              </p>
            </div>
          </div>
        )}

        {/* Step 3: Marketplace Listing */}
        {currentStep === 3 && (
          <div className="flex flex-col justify-between h-full gap-6">
            {/* Listing Summary */}
            <div className="bg-gradient-to-br from-primary/10 to-primary/5 rounded-xl p-4 border border-primary/20">
              <h4 className="font-semibold text-sm uppercase tracking-wide opacity-70 mb-4">Listing Summary</h4>
              <div className="space-y-3">
                <div className="flex justify-between items-center">
                  <span className="opacity-70">Tokens to List</span>
                  <span className="font-bold text-lg">
                    {formData.tokenSupply ? Number(formData.tokenSupply).toLocaleString() : "—"}
                  </span>
                </div>
                <div className="flex justify-between items-center">
                  <span className="opacity-70">Price per Token</span>
                  <span className="font-bold text-lg">
                    {formData.tokenPrice ? `$${Number(formData.tokenPrice).toLocaleString()}` : "—"}
                  </span>
                </div>
                <div className="divider my-1"></div>
                <div className="flex justify-between items-center">
                  <span className="font-medium">Total Listing Value</span>
                  <span className="font-bold text-primary text-2xl">
                    {formData.tokenSupply && formData.tokenPrice
                      ? `$${(parseFloat(formData.tokenSupply) * parseFloat(formData.tokenPrice)).toLocaleString()}`
                      : "—"}
                  </span>
                </div>
              </div>
            </div>

            {/* Listing Configuration */}
            <div className="bg-base-200 rounded-xl p-4 space-y-4">
              <h4 className="font-semibold text-sm uppercase tracking-wide opacity-70">Listing Options</h4>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="form-control">
                  <label className="label pb-1">
                    <span className="label-text font-medium">Listing Duration</span>
                  </label>
                  <select
                    name="listingDurationDays"
                    className="select select-bordered w-full"
                    value={formData.listingDurationDays}
                    onChange={handleInputChange}
                  >
                    <option value="7">7 Days</option>
                    <option value="14">14 Days</option>
                    <option value="30">30 Days</option>
                    <option value="60">60 Days</option>
                    <option value="90">90 Days</option>
                  </select>
                </div>
                <div className="form-control">
                  <label className="label pb-1">
                    <span className="label-text font-medium">Protocol Fee</span>
                  </label>
                  <select
                    name="buyerPaysFee"
                    className="select select-bordered w-full"
                    value={formData.buyerPaysFee ? "buyer" : "seller"}
                    onChange={e => setFormData(prev => ({ ...prev, buyerPaysFee: e.target.value === "buyer" }))}
                  >
                    <option value="seller">Seller Pays (2.5%)</option>
                    <option value="buyer">Buyer Pays (2.5%)</option>
                  </select>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Sticky Footer */}
      <div className="shrink-0 border-t border-base-200 bg-base-100 p-4 space-y-2">
        <button type="button" className="btn btn-primary w-full" onClick={primary.action} disabled={isProcessing}>
          {isProcessing ? <span className="loading loading-spinner loading-xs"></span> : null}
          {isProcessing ? "Processing..." : primary.label}
        </button>
        {secondary && (
          <button
            type="button"
            className="btn btn-ghost btn-sm w-full"
            onClick={secondary.action}
            disabled={isProcessing}
          >
            {secondary.label}
          </button>
        )}
      </div>
    </div>
  );
};
