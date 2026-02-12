"use client";

import { useEffect, useState } from "react";
import { useEscClose } from "./useEscClose";
import { formatUnits, parseUnits } from "viem";
import { useAccount } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { usePaymentToken } from "~~/hooks/usePaymentToken";
import { formatTokenAmount } from "~~/utils/formatters";

interface ListVehicleModalProps {
  isOpen: boolean;
  onClose: () => void;
  vehicleId: string;
  vin: string;
  assetName?: string;
  prefillAmount?: string;
  isPrimaryListing?: boolean;
}

export const ListVehicleModal = ({
  isOpen,
  onClose,
  vehicleId,
  vin,
  assetName,
  prefillAmount,
  isPrimaryListing = false,
}: ListVehicleModalProps) => {
  const { address: connectedAddress } = useAccount();
  const { symbol, decimals } = usePaymentToken();
  const [formData, setFormData] = useState({
    amount: "",
    pricePerToken: "",
    durationDays: "30",
    buyerPaysFee: "buyer",
  });
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEscClose(isOpen, onClose);

  const { writeContractAsync: writeMarketplace } = useScaffoldWriteContract({ contractName: "Marketplace" });
  const { writeContractAsync: writeRoboshareTokens } = useScaffoldWriteContract({ contractName: "RoboshareTokens" });

  const marketplaceAddress = deployedContracts[31337]?.Marketplace?.address;

  const { data: isApproved } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "isApprovedForAll",
    args: [connectedAddress, marketplaceAddress],
    watch: true,
  });

  const revenueTokenId = BigInt(vehicleId) + 1n;
  const { data: baseTokenPrice } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "getTokenPrice",
    args: [revenueTokenId],
  });

  const { data: walletBalance } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "balanceOf",
    args: [connectedAddress, revenueTokenId],
  });

  useEffect(() => {
    if (!prefillAmount) return;
    setFormData(prev => (prev.amount ? prev : { ...prev, amount: prefillAmount }));
  }, [prefillAmount]);

  useEffect(() => {
    if (prefillAmount) return;
    if (walletBalance && walletBalance > 0n) {
      setFormData(prev => (prev.amount ? prev : { ...prev, amount: walletBalance.toString() }));
    }
  }, [prefillAmount, walletBalance]);

  useEffect(() => {
    if (!baseTokenPrice) return;
    setFormData(prev =>
      prev.pricePerToken
        ? prev
        : {
            ...prev,
            pricePerToken: formatUnits(baseTokenPrice, 6)
              .replace(/\.0+$/, "")
              .replace(/(\.\d*[1-9])0+$/, "$1"),
          },
    );
  }, [baseTokenPrice]);

  const setPriceFromDelta = (deltaBp: number) => {
    if (!baseTokenPrice) return;
    const multiplier = 10000n + BigInt(deltaBp);
    const nextPrice = (baseTokenPrice * multiplier) / 10000n;
    const formatted = formatUnits(nextPrice, 6);
    const trimmed = formatted.replace(/\.0+$/, "").replace(/(\.\d*[1-9])0+$/, "$1");
    setFormData(prev => ({ ...prev, pricePerToken: trimmed }));
  };

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
      const buyerPaysFee = isPrimaryListing ? true : formData.buyerPaysFee === "buyer";

      await writeMarketplace({
        functionName: "createListing",
        args: [tokenId, BigInt(formData.amount), priceBigInt, durationSeconds, buyerPaysFee],
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
            <h3 className="font-bold text-xl">List Tokens for Sale</h3>
            <p className="text-sm opacity-60 mt-1 mb-1">
              List revenue tokens for <span className="font-semibold">{assetName || "this asset"}</span> (VIN{" "}
              <span className="font-mono font-bold">{vin}</span>) on the marketplace.
            </p>
          </div>

          {/* Scrollable Content */}
          <div className="flex-1 overflow-y-auto p-4">
            <div className="flex flex-col gap-3">
              <div className="divider text-xs opacity-50 my-0">Listing Details</div>

              <div className="bg-base-200 p-4 rounded-lg border border-primary/20">
                {/* Row 1: Amount and Price */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 mb-4">
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
                    <div className="mt-2 flex flex-wrap gap-2">
                      {[25, 50, 75, 100].map(pct => (
                        <button
                          key={pct}
                          type="button"
                          className="btn btn-xs btn-outline"
                          onClick={() => {
                            const base = prefillAmount ? BigInt(prefillAmount) : (walletBalance ?? 0n);
                            if (base === 0n) return;
                            const nextAmount = (base * BigInt(pct)) / 100n;
                            setFormData(prev => ({ ...prev, amount: nextAmount.toString() }));
                          }}
                        >
                          {pct}%
                        </button>
                      ))}
                    </div>
                  </div>
                  <div className="form-control">
                    <label className="label py-0">
                      <span className="label-text text-xs font-bold uppercase opacity-60">
                        Price per Token ({symbol})
                      </span>
                    </label>
                    <div className="join w-full">
                      <input
                        type="number"
                        step="0.000001"
                        name="pricePerToken"
                        className="input input-bordered input-sm join-item w-full"
                        value={formData.pricePerToken}
                        onChange={handleInputChange}
                        placeholder="e.g. 1.00"
                        required
                      />
                      <span className="join-item flex items-center px-3 bg-base-300 text-xs font-medium">{symbol}</span>
                    </div>
                    <div className="mt-2 flex flex-wrap gap-2">
                      {[
                        { label: "-10%", bp: -1000 },
                        { label: "-5%", bp: -500 },
                        { label: "0%", bp: 0 },
                        { label: "+5%", bp: 500 },
                      ].map(option => (
                        <button
                          key={option.label}
                          type="button"
                          className="btn btn-xs btn-outline"
                          onClick={() => setPriceFromDelta(option.bp)}
                          disabled={!baseTokenPrice}
                        >
                          {option.label}
                        </button>
                      ))}
                    </div>
                  </div>
                </div>

                {/* Row 2: Fees + Duration */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 items-start">
                  {isPrimaryListing ? (
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
                  ) : (
                    <div className="form-control">
                      <label className="label py-0">
                        <span className="label-text text-xs font-bold uppercase opacity-60">Fees</span>
                      </label>
                      <select
                        name="buyerPaysFee"
                        className="select select-bordered select-sm w-full"
                        value={formData.buyerPaysFee}
                        onChange={handleInputChange}
                      >
                        <option value="buyer">Buyer Pays</option>
                        <option value="seller">Seller Pays</option>
                      </select>
                    </div>
                  )}
                  {isPrimaryListing ? (
                    <div className="flex flex-col items-end pb-1">
                      <span className="text-[10px] uppercase opacity-50 font-bold">Expires On</span>
                      <span className="text-sm font-bold text-base-content">{formatDate(expiryDate)}</span>
                    </div>
                  ) : (
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
                      <div className="flex flex-col items-end pt-2 text-right">
                        <span className="text-[10px] uppercase opacity-50 font-bold">Expires On</span>
                        <span className="text-sm font-bold text-base-content">{formatDate(expiryDate)}</span>
                      </div>
                    </div>
                  )}
                </div>
              </div>

              {/* Summary Box */}
              <div className="bg-success/10 p-3 rounded-lg text-xs">
                <div className="flex justify-between items-center">
                  <span className="opacity-80">Total Listing Value:</span>
                  <span className="font-bold text-success text-sm">
                    {formatTokenAmount(totalValue, decimals)} {symbol}
                  </span>
                </div>
              </div>

              {/* Info Box */}
              <div className="bg-info/10 p-3 rounded-lg text-xs">
                <p className="opacity-80 mt-1 mb-1">
                  {isPrimaryListing
                    ? "Your tokens are already held in marketplace escrow. This listing will make them available for buyers to purchase in partial amounts. Unsold tokens remain in escrow after the listing ends."
                    : "Your tokens will be transferred to marketplace escrow for sale. Buyers can purchase partial amounts. Unsold tokens will be returned to you when the listing ends."}
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
                ) : !isApproved ? (
                  "Approve & List"
                ) : (
                  "List for Sale"
                )}
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
  );
};
