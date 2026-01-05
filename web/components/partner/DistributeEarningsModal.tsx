"use client";

import { useMemo, useState } from "react";
import { parseUnits } from "viem";
import { useAccount } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { formatUsdc } from "~~/utils/formatters";

interface DistributeEarningsModalProps {
  isOpen: boolean;
  onClose: () => void;
  assetId: string;
  assetName: string;
}

const PROTOCOL_FEE_BPS = 250; // 2.5% - matches ProtocolLib.PROTOCOL_FEE_BP

export const DistributeEarningsModal = ({ isOpen, onClose, assetId, assetName }: DistributeEarningsModalProps) => {
  const { address: connectedAddress } = useAccount();
  const [totalRevenue, setTotalRevenue] = useState(""); // Total revenue earned
  const [isSubmitting, setIsSubmitting] = useState(false);

  const { writeContractAsync: writeTreasury } = useScaffoldWriteContract({ contractName: "Treasury" });
  const { writeContractAsync: writeUsdc } = useScaffoldWriteContract({ contractName: "MockUSDC" });

  const treasuryAddress = deployedContracts[31337]?.Treasury?.address;

  // Get revenue token ID (assetId + 1)
  const revenueTokenId = BigInt(assetId) + 1n;

  // Get total supply of revenue tokens
  const { data: totalSupply } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "getRevenueTokenSupply",
    args: [revenueTokenId],
    watch: true,
  });

  // Get partner's balance of revenue tokens
  const { data: partnerBalance } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "balanceOf",
    args: [connectedAddress, revenueTokenId],
    watch: true,
  });

  // Check USDC allowance
  const { data: allowance } = useScaffoldReadContract({
    contractName: "MockUSDC",
    functionName: "allowance",
    args: [connectedAddress, treasuryAddress],
    watch: true,
  });

  // Get minimum protocol fee from contract
  const { data: minProtocolFee } = useScaffoldReadContract({
    contractName: "Treasury",
    functionName: "getMinProtocolFee",
  });

  // Calculate token ownership breakdown (independent of revenue)
  const tokenOwnership = useMemo(() => {
    if (!totalSupply || totalSupply === 0n) {
      return null;
    }

    const partnerTokens = partnerBalance || 0n;
    const externalTokens = totalSupply - partnerTokens;
    const externalPercentage = Number((externalTokens * 10000n) / totalSupply) / 100;
    const partnerPercentage = Number((partnerTokens * 10000n) / totalSupply) / 100;

    return {
      totalSupply,
      partnerTokens,
      externalTokens,
      partnerPercentage,
      externalPercentage,
    };
  }, [totalSupply, partnerBalance]);

  // Calculate revenue distribution breakdown (only when revenue is entered)
  const revenueBreakdown = useMemo(() => {
    if (!tokenOwnership || !totalRevenue) {
      return null;
    }

    // Parse total revenue
    const totalRevenueWei = parseUnits(totalRevenue || "0", 6);

    // Calculate investor portion (what partner should distribute)
    const investorPortion = (totalRevenueWei * tokenOwnership.externalTokens) / tokenOwnership.totalSupply;
    const partnerPortion = totalRevenueWei - investorPortion;

    // Calculate protocol fee with minimum enforcement
    const calculatedFee = (investorPortion * BigInt(PROTOCOL_FEE_BPS)) / 10000n;
    const minFee = minProtocolFee ?? 1_000_000n; // Fallback to 1 USDC if not loaded
    const protocolFee = calculatedFee > minFee ? calculatedFee : minFee;
    const netToInvestors = investorPortion - protocolFee;

    return {
      totalRevenue: totalRevenueWei,
      investorPortion,
      partnerPortion,
      protocolFee,
      netToInvestors,
    };
  }, [tokenOwnership, totalRevenue, minProtocolFee]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!treasuryAddress || !revenueBreakdown) return;

    setIsSubmitting(true);
    try {
      // Partner deposits only the investor portion - contract tracks total revenue for metrics
      const amountToDistribute = revenueBreakdown.investorPortion;

      // Approve if needed
      if (!allowance || allowance < amountToDistribute) {
        await writeUsdc({
          functionName: "approve",
          args: [treasuryAddress, amountToDistribute],
        });
      }

      // Distribute earnings (totalRevenue for tracking, investorAmount for deposit)
      await writeTreasury({
        functionName: "distributeEarnings",
        args: [BigInt(assetId), revenueBreakdown.totalRevenue, amountToDistribute],
      });

      setTotalRevenue("");
      onClose();
    } catch (e) {
      console.error("Error distributing earnings:", e);
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!isOpen) return null;

  const hasExternalHolders = tokenOwnership && tokenOwnership.externalTokens > 0n;

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
          <h3 className="font-bold text-xl">Distribute Earnings</h3>
          <p className="text-sm opacity-60 mt-1">
            Distribute earnings from <span className="font-bold">{assetName}</span> to revenue token holders.
          </p>
        </div>

        <form onSubmit={handleSubmit} className="flex flex-col gap-4">
          {/* Token Ownership Breakdown */}
          <div className="bg-base-200 p-4 rounded-lg">
            <div className="text-xs uppercase opacity-50 font-bold mb-3">Token Ownership</div>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <div className="text-xs opacity-50">Your Tokens</div>
                <div className="font-bold">
                  {partnerBalance?.toLocaleString() || "0"}
                  <span className="text-xs opacity-50 ml-1">
                    ({tokenOwnership?.partnerPercentage.toFixed(1) || 0}%)
                  </span>
                </div>
              </div>
              <div>
                <div className="text-xs opacity-50">Investor Tokens</div>
                <div className="font-bold">
                  {tokenOwnership?.externalTokens.toLocaleString() || "0"}
                  <span className="text-xs opacity-50 ml-1">
                    ({tokenOwnership?.externalPercentage.toFixed(1) || 0}%)
                  </span>
                </div>
              </div>
            </div>
          </div>

          {!hasExternalHolders && totalSupply && totalSupply > 0n && (
            <div className="bg-warning/10 p-3 rounded-lg text-xs">
              <p className="text-warning font-bold">No external token holders</p>
              <p className="opacity-80 mt-1">
                You currently hold all revenue tokens. There are no investors to distribute earnings to.
              </p>
            </div>
          )}

          {/* Revenue Input */}
          <div className="divider text-xs opacity-50 my-0">Revenue Details</div>

          <div className="form-control">
            <label className="label py-0">
              <span className="label-text text-xs font-bold uppercase opacity-60">Total Revenue Earned (USDC)</span>
            </label>
            <div className="relative">
              <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm opacity-50">$</span>
              <input
                type="number"
                step="0.000001"
                min="0"
                className="input input-bordered input-sm w-full pl-7"
                value={totalRevenue}
                onChange={e => setTotalRevenue(e.target.value)}
                placeholder="e.g. 1000.00"
                required
                disabled={!hasExternalHolders}
              />
            </div>
            <p className="text-xs opacity-50 mt-1">
              Enter the total revenue generated. We&apos;ll calculate the investor portion automatically.
            </p>
          </div>

          {/* Distribution Breakdown */}
          {revenueBreakdown && hasExternalHolders && totalRevenue && (
            <div className="bg-success/10 p-4 rounded-lg border border-success/30">
              <div className="text-xs uppercase opacity-50 font-bold mb-3">Distribution Breakdown</div>

              <div className="space-y-2 text-sm">
                <div className="flex justify-between">
                  <span className="opacity-70">Your share (kept)</span>
                  <span className="font-semibold">{formatUsdc(revenueBreakdown.partnerPortion)} USDC</span>
                </div>
                <div className="flex justify-between">
                  <span className="opacity-70">Investor share</span>
                  <span className="font-semibold">{formatUsdc(revenueBreakdown.investorPortion)} USDC</span>
                </div>
                <div className="border-t border-success/30 pt-2 mt-2">
                  <div className="flex justify-between text-xs">
                    <span className="opacity-50">Protocol fee (2.5%)</span>
                    <span className="opacity-50">-{formatUsdc(revenueBreakdown.protocolFee)} USDC</span>
                  </div>
                  <div className="flex justify-between font-bold text-success mt-1">
                    <span>Net to investors</span>
                    <span>{formatUsdc(revenueBreakdown.netToInvestors)} USDC</span>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Info Box */}
          <div className="bg-info/10 p-3 rounded-lg text-xs">
            <p className="opacity-80">
              You deposit only the investor portion ({tokenOwnership?.externalPercentage.toFixed(1) || 0}%). Your share
              stays with you. Minimum protocol fee is 1 USDC.
            </p>
          </div>

          {/* Actions */}
          <div className="modal-action mt-2">
            <button type="button" className="btn btn-ghost" onClick={onClose} disabled={isSubmitting}>
              Cancel
            </button>
            <button
              type="submit"
              className="btn btn-success"
              disabled={isSubmitting || !totalRevenue || !hasExternalHolders}
            >
              {isSubmitting ? (
                <>
                  <span className="loading loading-spinner loading-sm"></span>
                  Distributing...
                </>
              ) : (
                `Distribute ${revenueBreakdown ? formatUsdc(revenueBreakdown.investorPortion) : "0"} USDC`
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
