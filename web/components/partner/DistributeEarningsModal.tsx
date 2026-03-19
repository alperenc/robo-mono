"use client";

import { useEffect, useMemo, useState } from "react";
import { useEscClose } from "./useEscClose";
import { parseUnits } from "viem";
import { useAccount, useChainId } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { usePaymentToken } from "~~/hooks/usePaymentToken";
import { getDeployedContract } from "~~/utils/contracts";
import { formatTokenAmount } from "~~/utils/formatters";

const BP_PRECISION = 10000n;
const PROTOCOL_FEE_BP = 250n;
const MIN_PROTOCOL_FEE = 1_000_000n;

interface DistributeEarningsModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: () => void;
  assetId: string;
  assetName: string;
  maxSupply: bigint;
  immediateProceeds: boolean;
}

export const DistributeEarningsModal = ({
  isOpen,
  onClose,
  onSuccess,
  assetId,
  assetName,
  maxSupply,
  immediateProceeds,
}: DistributeEarningsModalProps) => {
  const { address: connectedAddress } = useAccount();
  const chainId = useChainId();
  const { symbol, decimals } = usePaymentToken();
  const [totalRevenue, setTotalRevenue] = useState(""); // Total revenue earned
  const [isSubmitting, setIsSubmitting] = useState(false);
  const supportsAutoRelease = !immediateProceeds;
  const [autoRelease, setAutoRelease] = useState(supportsAutoRelease);

  useEffect(() => {
    setAutoRelease(supportsAutoRelease);
  }, [supportsAutoRelease]);

  useEscClose(isOpen, onClose);

  const { writeContractAsync: writeTreasury } = useScaffoldWriteContract({ contractName: "Treasury" });
  const { writeContractAsync: writePaymentToken } = useScaffoldWriteContract({ contractName: "MockUSDC" });

  const treasuryAddress = getDeployedContract(chainId, "Treasury")?.address;
  const marketplaceAddress = getDeployedContract(chainId, "Marketplace")?.address;

  // Get revenue token ID (assetId + 1)
  const revenueTokenId = BigInt(assetId) + 1n;

  // Get circulating supply of revenue tokens
  const { data: circulatingSupply } = useScaffoldReadContract({
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

  // Get escrowed revenue tokens held by Marketplace
  const { data: escrowedTokens } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "balanceOf",
    args: [marketplaceAddress, revenueTokenId],
    watch: true,
  });

  // Check payment token allowance
  const { data: paymentTokenAllowance, refetch: refetchPaymentTokenAllowance } = useScaffoldReadContract({
    contractName: "MockUSDC",
    functionName: "allowance",
    args: [connectedAddress, treasuryAddress],
    watch: true,
  });

  const { data: revenueShareBP } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "getRevenueShareBP",
    args: [revenueTokenId],
    watch: true,
  });

  const { data: previewRelease } = useScaffoldReadContract({
    contractName: "Treasury",
    functionName: "previewCollateralRelease",
    args: [BigInt(assetId), true],
    query: { enabled: supportsAutoRelease && autoRelease },
  });

  // Calculate token ownership breakdown (independent of revenue)
  const tokenOwnership = useMemo(() => {
    const currentCirculatingSupply = (circulatingSupply as bigint | undefined) ?? 0n;

    if (currentCirculatingSupply === 0n || maxSupply === 0n) {
      return null;
    }

    const partnerTokens = (partnerBalance as bigint | undefined) ?? 0n;
    const escrowTokens = (escrowedTokens as bigint | undefined) ?? 0n;
    const investorTokens = currentCirculatingSupply > partnerTokens ? currentCirculatingSupply - partnerTokens : 0n;
    const investorPercentage = Number((investorTokens * 10000n) / maxSupply) / 100;
    const partnerPercentage = Number((partnerTokens * 10000n) / maxSupply) / 100;
    const escrowPercentage = Number((escrowTokens * 10000n) / maxSupply) / 100;
    const circulatingPercentage = Number((currentCirculatingSupply * 10000n) / maxSupply) / 100;

    return {
      maxSupply,
      circulatingSupply: currentCirculatingSupply,
      partnerTokens,
      investorTokens,
      escrowTokens,
      partnerPercentage,
      investorPercentage,
      escrowPercentage,
      circulatingPercentage,
    };
  }, [circulatingSupply, maxSupply, partnerBalance, escrowedTokens]);

  // Calculate revenue distribution breakdown (only when revenue is entered)
  const revenueBreakdown = useMemo(() => {
    if (!tokenOwnership || !totalRevenue) {
      return null;
    }

    // Parse total revenue
    const totalRevenueWei = parseUnits(totalRevenue || "0", decimals);

    // Calculate investor portion (what partner should distribute)
    const revenueShareCap = (totalRevenueWei * (revenueShareBP ?? BP_PRECISION)) / BP_PRECISION;
    const soldShare = (totalRevenueWei * tokenOwnership.investorTokens) / tokenOwnership.maxSupply;
    const investorPortion = revenueShareCap < soldShare ? revenueShareCap : soldShare;
    const partnerPortion = totalRevenueWei - investorPortion;

    // Calculate protocol fee with minimum enforcement
    const calculatedFee = (investorPortion * PROTOCOL_FEE_BP) / BP_PRECISION;
    const protocolFee = calculatedFee > MIN_PROTOCOL_FEE ? calculatedFee : MIN_PROTOCOL_FEE;
    const netToInvestors = investorPortion - protocolFee;

    return {
      totalRevenue: totalRevenueWei,
      investorPortion,
      partnerPortion,
      protocolFee,
      netToInvestors,
    };
  }, [tokenOwnership, totalRevenue, revenueShareBP, decimals]);

  const estimatedRelease = useMemo(() => {
    if (!autoRelease) return 0n;
    return (previewRelease as bigint | undefined) ?? 0n;
  }, [autoRelease, previewRelease]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!treasuryAddress || !revenueBreakdown) return;

    setIsSubmitting(true);
    try {
      // Approval safety: approve up to total revenue so tx won't fail if on-chain rounding/denominator differs.
      const amountToApprove = revenueBreakdown.totalRevenue;

      // Approve if needed
      if (!paymentTokenAllowance || paymentTokenAllowance < amountToApprove) {
        await writePaymentToken({
          functionName: "approve",
          args: [treasuryAddress, amountToApprove],
        });
        await refetchPaymentTokenAllowance();
      }

      // Distribute earnings (totalRevenue only; investor amount is computed on-chain)
      await writeTreasury({
        functionName: "distributeEarnings",
        args: [BigInt(assetId), revenueBreakdown.totalRevenue, supportsAutoRelease && autoRelease],
      });

      setTotalRevenue("");
      onSuccess?.();
      onClose();
    } catch (e) {
      console.error("Error distributing earnings:", e);
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!isOpen) return null;

  const hasExternalHolders = tokenOwnership && tokenOwnership.investorTokens > 0n;
  const hasEscrowedInvestorTokens = tokenOwnership && tokenOwnership.escrowTokens > 0n;

  return (
    <div className="modal modal-open">
      <div className="modal-backdrop bg-black/50 backdrop-blur-sm hidden sm:block" onClick={onClose} />
      <div className="modal-box relative w-full h-full max-h-full sm:h-auto sm:max-h-[90vh] sm:max-w-xl sm:rounded-2xl rounded-none flex flex-col p-0">
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
            <h3 className="font-bold text-xl">Send Payout</h3>
            <p className="text-sm opacity-60 mt-1">
              Send payouts from <span className="font-bold">{assetName}</span> to current holders.
            </p>
          </div>

          {/* Scrollable Content */}
          <div className="flex-1 overflow-y-auto p-4">
            <div className="flex flex-col gap-3">
              {/* Token Ownership Breakdown */}
              <div className="bg-base-200 p-4 rounded-lg">
                <div className="text-xs uppercase opacity-50 font-bold mb-3">Holder Breakdown</div>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <div className="text-xs opacity-50">Your Claim Units</div>
                    <div className="font-bold">
                      {partnerBalance?.toLocaleString() || "0"}
                      <span className="text-xs opacity-50 ml-1">
                        ({tokenOwnership?.partnerPercentage.toFixed(1) || 0}%)
                      </span>
                    </div>
                  </div>
                  <div>
                    <div className="text-xs opacity-50">Unclaimed Claim Units</div>
                    <div className="font-bold">
                      {tokenOwnership?.escrowTokens.toLocaleString() || "0"}
                      <span className="text-xs opacity-50 ml-1">
                        ({tokenOwnership?.escrowPercentage.toFixed(1) || 0}%)
                      </span>
                    </div>
                  </div>
                  <div>
                    <div className="text-xs opacity-50">Holder Claim Units</div>
                    <div className="font-bold">
                      {tokenOwnership?.investorTokens.toLocaleString() || "0"}
                      <span className="text-xs opacity-50 ml-1">
                        ({tokenOwnership?.investorPercentage.toFixed(1) || 0}%)
                      </span>
                    </div>
                  </div>
                  <div>
                    <div className="text-xs opacity-50">Total Claim Units</div>
                    <div className="font-bold">{tokenOwnership?.maxSupply.toLocaleString() || "0"}</div>
                    <div className="text-[11px] opacity-50 mt-0.5">
                      Issued: {tokenOwnership?.circulatingSupply.toLocaleString() || "0"} (
                      {tokenOwnership?.circulatingPercentage.toFixed(1) || 0}%)
                    </div>
                  </div>
                </div>
              </div>

              {!hasExternalHolders && circulatingSupply && circulatingSupply > 0n && (
                <div className="bg-warning/10 p-3 rounded-lg text-xs">
                  <p className="text-warning font-bold">No external token holders</p>
                  <p className="opacity-80 mt-1">
                    You currently hold all claim units. There are no outside holders to send payouts to.
                  </p>
                </div>
              )}

              {hasEscrowedInvestorTokens && (
                <div className="bg-warning/10 border border-warning/20 p-3 rounded-lg text-xs">
                  <p className="text-warning font-bold">Warning: Unclaimed Holder Units Detected</p>
                  <p className="opacity-80 mt-1">
                    Some claim units are still unclaimed in marketplace escrow. Sending payouts now may lead to
                    confusing claim behavior until those units are claimed.
                  </p>
                </div>
              )}

              {/* Revenue Input */}
              <div className="divider text-xs opacity-50 my-0">Payout Details</div>

              <div className="form-control">
                <label className="label py-0">
                  <span className="label-text text-xs font-bold uppercase opacity-60">
                    Total Amount to Distribute ({symbol})
                  </span>
                </label>
                <div className="join w-full">
                  <input
                    type="number"
                    step="0.000001"
                    min="0"
                    className="input input-bordered input-sm join-item w-full"
                    value={totalRevenue}
                    onChange={e => setTotalRevenue(e.target.value)}
                    placeholder="e.g. 1000.00"
                    required
                    disabled={!hasExternalHolders}
                  />
                  <span className="join-item flex items-center px-3 bg-base-300 text-xs font-medium">{symbol}</span>
                </div>
                <p className="text-xs opacity-50 mt-1">
                  Enter the total amount to distribute. Payouts are split based on current holdings.
                </p>
              </div>

              {/* Distribution Breakdown */}
              {revenueBreakdown && hasExternalHolders && totalRevenue && (
                <div className="bg-success/10 p-4 rounded-lg border border-success/30">
                  <div className="text-xs uppercase opacity-50 font-bold mb-3">Distribution Breakdown</div>

                  <div className="space-y-2 text-sm">
                    <div className="flex justify-between">
                      <span className="opacity-70">Your share (kept)</span>
                      <span className="font-semibold">
                        {formatTokenAmount(revenueBreakdown.partnerPortion, decimals)} {symbol}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="opacity-70">Investor share</span>
                      <span className="font-semibold">
                        {formatTokenAmount(revenueBreakdown.investorPortion, decimals)} {symbol}
                      </span>
                    </div>
                    <div className="border-t border-success/30 pt-2 mt-2">
                      <div className="flex justify-between text-xs">
                        <span className="opacity-50">Protocol fee (2.5%)</span>
                        <span className="opacity-50">
                          -{formatTokenAmount(revenueBreakdown.protocolFee, decimals)} {symbol}
                        </span>
                      </div>
                      <div className="flex justify-between font-bold text-success mt-1">
                        <span>Net to investors</span>
                        <span>
                          {formatTokenAmount(revenueBreakdown.netToInvestors, decimals)} {symbol}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              )}

              {/* Auto-release Proceeds Toggle (gradual release only) */}
              {supportsAutoRelease && revenueBreakdown && hasExternalHolders && totalRevenue && (
                <div className="form-control w-full">
                  <label className="label cursor-pointer flex justify-between w-full py-2">
                    <div>
                      <span className="label-text font-medium">Automatically unlock proceeds</span>
                      <p className="text-xs opacity-50 mt-0.5">
                        Unlock available proceeds proportionally as you send payouts
                      </p>
                      {autoRelease && (
                        <p className="text-xs mt-1 font-medium text-success">
                          Estimated release: {formatTokenAmount(estimatedRelease, decimals)} {symbol}
                        </p>
                      )}
                    </div>
                    <input
                      type="checkbox"
                      className="toggle toggle-success"
                      checked={autoRelease}
                      onChange={e => setAutoRelease(e.target.checked)}
                    />
                  </label>
                </div>
              )}

              {/* Info Box */}
              <div className="bg-info/10 p-3 rounded-lg text-xs">
                <p className="opacity-80">
                  You deposit only the investor portion (capped by the revenue share setting). Your share stays with
                  you. Minimum protocol fee is 1 {symbol}.
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
                  `Distribute ${revenueBreakdown ? formatTokenAmount(revenueBreakdown.investorPortion, decimals) : "0"} ${symbol}`
                )}
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
  );
};
