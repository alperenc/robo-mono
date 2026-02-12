"use client";

import { useState } from "react";
import { useEscClose } from "./useEscClose";
import { parseUnits } from "viem";
import { useAccount } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { usePaymentToken } from "~~/hooks/usePaymentToken";
import { formatTokenAmount } from "~~/utils/formatters";
import { notification } from "~~/utils/scaffold-eth";

interface MintAndListModalProps {
  isOpen: boolean;
  onClose: () => void;
  vehicleId: string;
  assetValue: string;
  isPrimaryListing?: boolean;
}

export const MintAndListModal = ({
  isOpen,
  onClose,
  vehicleId,
  assetValue,
  isPrimaryListing = true,
}: MintAndListModalProps) => {
  const { address: connectedAddress } = useAccount();
  const { symbol, decimals } = usePaymentToken();
  const [currentStep, setCurrentStep] = useState(1);
  const [isProcessing, setIsProcessing] = useState(false);
  const [touchedFields, setTouchedFields] = useState<Record<string, boolean>>({});
  const [showValidation, setShowValidation] = useState(false);
  const [formData, setFormData] = useState({
    maturityMonths: "36",
    tokenPrice: "",
    revenueShareBP: "",
    targetYieldBP: "",
    listingDurationDays: "30",
  });

  const assetValueBigInt = assetValue ? BigInt(assetValue) : 0n;
  const tokenPriceBigInt = formData.tokenPrice ? parseUnits(formData.tokenPrice, 6) : 0n;
  const toBasisPoints = (value: string) => {
    const numeric = parseFloat(value);
    if (!Number.isFinite(numeric)) return 0n;
    return BigInt(Math.round(numeric * 100));
  };
  const revenueShareBP = toBasisPoints(formData.revenueShareBP);
  const targetYieldBP = toBasisPoints(formData.targetYieldBP);

  const { writeContractAsync: writeVehicleRegistry } = useScaffoldWriteContract({ contractName: "VehicleRegistry" });
  const { writeContractAsync: writeRoboshareTokens } = useScaffoldWriteContract({ contractName: "RoboshareTokens" });

  const marketplaceAddress = deployedContracts[31337]?.Marketplace?.address;

  const { data: requiredCollateral } = useScaffoldReadContract({
    contractName: "Treasury",
    functionName: "getTotalBufferRequirement",
    args: [assetValueBigInt, targetYieldBP],
    watch: true,
    query: { enabled: currentStep >= 1 },
  });

  const { data: isApproved } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "isApprovedForAll",
    args: [connectedAddress, marketplaceAddress],
    watch: true,
    query: { enabled: currentStep >= 2 },
  });

  useEscClose(isOpen, onClose);

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleFieldBlur = (e: React.FocusEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name } = e.target;
    setTouchedFields(prev => ({ ...prev, [name]: true }));
  };

  const isStepValid = (() => {
    if (currentStep === 1) {
      return (
        formData.tokenPrice.trim() &&
        formData.revenueShareBP.trim() &&
        formData.targetYieldBP.trim() &&
        formData.maturityMonths.trim()
      );
    }
    if (currentStep === 2) {
      return formData.listingDurationDays.trim();
    }
    return true;
  })();

  const isMissing = (field: keyof typeof formData) =>
    (showValidation || touchedFields[field as string]) && !formData[field]?.trim();
  const inputClass = (base: string, field: keyof typeof formData) => `${base} ${isMissing(field) ? "input-error" : ""}`;
  const markRequiredForStep = () => {
    const requiredFields =
      currentStep === 1 ? ["tokenPrice", "revenueShareBP", "targetYieldBP", "maturityMonths"] : ["listingDurationDays"];
    const nextTouched: Record<string, boolean> = {};
    requiredFields.forEach(field => {
      nextTouched[field] = true;
    });
    setTouchedFields(prev => ({ ...prev, ...nextTouched }));
    setShowValidation(true);
  };

  const handleNext = () => {
    if (!isStepValid) {
      markRequiredForStep();
      notification.error("Please complete the required fields before continuing.");
      return;
    }
    setCurrentStep(prev => Math.min(prev + 1, 2));
  };

  const handleBack = () => {
    if (currentStep === 1) {
      onClose();
    } else {
      setCurrentStep(prev => prev - 1);
    }
  };

  const handleMintAndList = async () => {
    if (!marketplaceAddress) return;

    setIsProcessing(true);
    try {
      const maturityTimestamp = BigInt(
        Math.floor(Date.now() / 1000) + parseInt(formData.maturityMonths) * 30 * 24 * 60 * 60,
      );
      const listingDurationSeconds = BigInt(parseInt(formData.listingDurationDays) * 24 * 60 * 60);

      if (!isApproved) {
        await writeRoboshareTokens(
          {
            functionName: "setApprovalForAll",
            args: [marketplaceAddress, true],
          },
          { blockConfirmations: 1 },
        );
      }

      await writeVehicleRegistry({
        functionName: "mintRevenueTokensAndList",
        args: [
          BigInt(vehicleId),
          tokenPriceBigInt,
          maturityTimestamp,
          revenueShareBP,
          targetYieldBP,
          listingDurationSeconds,
          true,
        ],
      });
      onClose();
    } catch (e) {
      console.error("Error:", e);
      notification.error(`Mint & List failed: ${e instanceof Error ? e.message : "Unknown error"}`);
    } finally {
      setIsProcessing(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-backdrop bg-black/50 backdrop-blur-sm hidden sm:block" onClick={onClose} />
      <div className="modal-box relative w-full h-full max-h-full sm:max-h-[90vh] sm:max-w-2xl sm:rounded-2xl rounded-none flex flex-col p-0">
        <button className="btn btn-sm btn-circle btn-ghost absolute right-3 top-3 z-10" onClick={onClose}>
          <XMarkIcon className="h-5 w-5" />
        </button>

        <div className="flex items-center px-4 py-3 border-b border-base-200 shrink-0">
          <h3 className="font-bold text-lg flex items-center gap-2">
            <button type="button" className="btn btn-xs btn-ghost btn-circle" onClick={handleBack}>
              ←
            </button>
            {currentStep === 1 ? "Financial Terms" : "Marketplace Listing"}
          </h3>
        </div>

        <div className="flex justify-center items-center gap-2 py-2 border-b border-base-200 shrink-0">
          {[1, 2].map(step => (
            <div key={step} className="flex items-center gap-2">
              <div
                className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold ${
                  step <= currentStep ? "bg-primary text-primary-content" : "bg-base-300 text-base-content/50"
                }`}
              >
                {step}
              </div>
              {step < 2 && <div className={`w-8 h-0.5 ${step < currentStep ? "bg-primary" : "bg-base-300"}`} />}
            </div>
          ))}
        </div>

        <div className="flex-1 overflow-y-auto p-5">
          {currentStep === 1 && (
            <div className="flex flex-col justify-between h-full gap-6">
              <div className="bg-base-200 rounded-xl p-4 space-y-4">
                <h4 className="font-semibold text-sm uppercase tracking-wide opacity-70">Token Configuration</h4>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="form-control">
                    <label className="label pb-1">
                      <span className="label-text font-medium">Token Price ({symbol})</span>
                      {isMissing("tokenPrice") && <span className="label-text-alt text-error">Required</span>}
                    </label>
                    <div className="join w-full">
                      <input
                        type="number"
                        name="tokenPrice"
                        className={inputClass("input input-bordered join-item w-full", "tokenPrice")}
                        value={formData.tokenPrice}
                        onChange={handleInputChange}
                        onBlur={handleFieldBlur}
                        placeholder="e.g. 100"
                        step="0.01"
                        required
                      />
                      <span className="join-item flex items-center px-3 bg-base-300 font-medium">{symbol}</span>
                    </div>
                  </div>
                  <div className="form-control">
                    <label className="label pb-1">
                      <span className="label-text font-medium">Revenue Share Cap (%)</span>
                      {isMissing("revenueShareBP") && <span className="label-text-alt text-error">Required</span>}
                    </label>
                    <input
                      type="number"
                      name="revenueShareBP"
                      className={inputClass("input input-bordered w-full", "revenueShareBP")}
                      value={formData.revenueShareBP}
                      onChange={handleInputChange}
                      onBlur={handleFieldBlur}
                      placeholder="e.g. 50"
                      required
                    />
                  </div>
                  <div className="form-control">
                    <label className="label pb-1">
                      <span className="label-text font-medium">Target Yield (%)</span>
                      {isMissing("targetYieldBP") && <span className="label-text-alt text-error">Required</span>}
                    </label>
                    <input
                      type="number"
                      name="targetYieldBP"
                      className={inputClass("input input-bordered w-full", "targetYieldBP")}
                      value={formData.targetYieldBP}
                      onChange={handleInputChange}
                      onBlur={handleFieldBlur}
                      placeholder="e.g. 10"
                      required
                    />
                  </div>
                  <div className="form-control">
                    <label className="label pb-1">
                      <span className="label-text font-medium">Maturity Duration</span>
                      {isMissing("maturityMonths") && <span className="label-text-alt text-error">Required</span>}
                    </label>
                    <select
                      name="maturityMonths"
                      className={`select select-bordered w-full ${isMissing("maturityMonths") ? "select-error" : ""}`}
                      value={formData.maturityMonths}
                      onChange={handleInputChange}
                      onBlur={handleFieldBlur}
                    >
                      <option value="36">36 Months (3 years)</option>
                      <option value="48">48 Months (4 years)</option>
                      <option value="60">60 Months (5 years)</option>
                    </select>
                  </div>
                  <div className="bg-primary/10 dark:bg-white/10 rounded-lg p-2 text-center w-full">
                    <span className="text-[10px] uppercase opacity-60 font-bold block">Projected Supply</span>
                    <span className="text-md font-bold text-base-content dark:text-white">
                      {tokenPriceBigInt > 0n ? (assetValueBigInt / tokenPriceBigInt).toLocaleString() : "0"} Tokens
                    </span>
                  </div>
                  <div className="bg-primary/10 dark:bg-white/10 rounded-lg p-2 text-center w-full">
                    <span className="text-[10px] uppercase opacity-60 font-bold block">Estimated Buffer</span>
                    <span className="text-md font-bold text-base-content dark:text-white">
                      {formatTokenAmount(requiredCollateral ?? 0n, decimals)} {symbol}
                    </span>
                  </div>
                </div>
              </div>

              <div className="bg-info/10 border border-info/20 rounded-xl p-4">
                <p className="text-sm">
                  💰 Estimated buffer if the listing fully sells:{" "}
                  <span className="font-bold">
                    {formatTokenAmount(requiredCollateral ?? 0n, decimals)} {symbol}
                  </span>
                  . The actual buffer is funded when the listing ends, based on tokens sold.
                </p>
              </div>
            </div>
          )}

          {currentStep === 2 && (
            <div className="flex flex-col justify-between h-full gap-6">
              <div className="bg-gradient-to-br from-primary/10 to-primary/5 dark:from-white/10 dark:to-white/5 rounded-xl p-4 border border-primary/20 dark:border-white/15">
                <h4 className="font-semibold text-sm uppercase tracking-wide opacity-70 dark:text-white/70 mb-4">
                  Listing Summary
                </h4>
                <div className="space-y-3">
                  <div className="flex justify-between items-center">
                    <span className="opacity-70 dark:text-white/70">Total Supply</span>
                    <span className="font-bold text-lg text-base-content dark:text-white">
                      {tokenPriceBigInt > 0n ? (assetValueBigInt / tokenPriceBigInt).toLocaleString() : "—"} Tokens
                    </span>
                  </div>
                  <div className="flex justify-between items-center">
                    <span className="opacity-70 dark:text-white/70">Price per Token</span>
                    <span className="font-bold text-lg text-base-content dark:text-white">
                      {formData.tokenPrice ? `${Number(formData.tokenPrice).toLocaleString()} ${symbol}` : "—"}
                    </span>
                  </div>
                  <div className="divider my-1 opacity-20"></div>
                  <div className="flex justify-between items-center">
                    <span className="font-medium dark:text-white/80">Total Valuation</span>
                    <span className="font-bold text-primary text-2xl dark:text-white">
                      {assetValue ? `${formatTokenAmount(assetValueBigInt, decimals)} ${symbol}` : "—"}
                    </span>
                  </div>
                </div>
              </div>

              <div className="bg-base-200 rounded-xl p-2.5 sm:p-4 space-y-2.5 sm:space-y-4">
                <h4 className="font-semibold text-sm uppercase tracking-wide opacity-70">Listing Options</h4>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 sm:gap-4">
                  <div className="form-control">
                    <label className="label pb-0">
                      <span className="label-text font-medium">Listing Duration</span>
                      {isMissing("listingDurationDays") && <span className="label-text-alt text-error">Required</span>}
                    </label>
                    <select
                      name="listingDurationDays"
                      className={`select select-bordered w-full ${
                        isMissing("listingDurationDays") ? "select-error" : ""
                      }`}
                      value={formData.listingDurationDays}
                      onChange={handleInputChange}
                      onBlur={handleFieldBlur}
                    >
                      <option value="7">7 Days</option>
                      <option value="14">14 Days</option>
                      <option value="30">30 Days</option>
                      <option value="60">60 Days</option>
                      <option value="90">90 Days</option>
                    </select>
                  </div>
                  <div className="form-control">
                    <label className="label pb-0">
                      <span className="label-text font-medium">Fees</span>
                    </label>
                    <select className="select select-bordered w-full" disabled={isPrimaryListing}>
                      <option>Buyers pay fees</option>
                    </select>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>

        <div className="shrink-0 border-t border-base-200 bg-base-100 p-4 space-y-2">
          <div
            onClick={() => {
              if (!isStepValid && !isProcessing) {
                markRequiredForStep();
                notification.error("Please complete the required fields before continuing.");
              }
            }}
          >
            <button
              type="button"
              className="btn btn-primary w-full"
              onClick={currentStep === 2 ? handleMintAndList : handleNext}
              disabled={isProcessing || !isStepValid}
            >
              {isProcessing ? <span className="loading loading-spinner loading-xs"></span> : null}
              {isProcessing ? "Processing..." : currentStep === 2 ? "Go Live" : "Continue →"}
            </button>
          </div>
          {!isStepValid && (
            <button type="button" className="btn btn-link btn-xs w-full" onClick={markRequiredForStep}>
              Review required fields
            </button>
          )}
        </div>
      </div>
    </div>
  );
};
