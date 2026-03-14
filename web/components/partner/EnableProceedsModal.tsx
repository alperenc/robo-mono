"use client";

import { useEffect, useMemo, useState } from "react";
import { useEscClose } from "./useEscClose";
import { useAccount } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { usePaymentToken } from "~~/hooks/usePaymentToken";
import { formatTokenAmount } from "~~/utils/formatters";

interface EnableProceedsModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: () => void;
  assetId: string;
  assetName: string;
  immediateProceeds: boolean;
  protectionEnabled: boolean;
}

export const EnableProceedsModal = ({
  isOpen,
  onClose,
  onSuccess,
  assetId,
  assetName,
  immediateProceeds,
  protectionEnabled,
}: EnableProceedsModalProps) => {
  const { address: connectedAddress } = useAccount();
  const { symbol, decimals } = usePaymentToken();
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEscClose(isOpen, onClose);

  const { writeContractAsync: writeTreasury } = useScaffoldWriteContract({ contractName: "Treasury" });
  const { writeContractAsync: writePaymentToken } = useScaffoldWriteContract({ contractName: "MockUSDC" });

  const treasuryAddress = deployedContracts[31337]?.Treasury?.address;
  const assetIdBigInt = BigInt(assetId);
  const tokenId = assetIdBigInt + 1n;

  const { data: baseLiquidity } = useScaffoldReadContract({
    contractName: "Treasury",
    functionName: "getPrimaryInvestorLiquidity",
    args: [assetIdBigInt],
    query: { enabled: isOpen },
  });

  const { data: collateralInfo } = useScaffoldReadContract({
    contractName: "Treasury",
    functionName: "assetCollateral",
    args: [assetIdBigInt],
    query: { enabled: isOpen },
  });

  const { data: bufferPreview } = useScaffoldReadContract({
    contractName: "Marketplace",
    functionName: "previewPrimaryPoolBufferRequirements",
    args: [tokenId, (baseLiquidity as bigint | undefined) ?? 0n],
    query: { enabled: isOpen && ((baseLiquidity as bigint | undefined) ?? 0n) > 0n },
  });

  const { data: allowance } = useScaffoldReadContract({
    contractName: "MockUSDC",
    functionName: "allowance",
    args: [connectedAddress, treasuryAddress],
    watch: true,
    query: { enabled: isOpen && !!connectedAddress && !!treasuryAddress },
  });

  const fundingBreakdown = useMemo(() => {
    const currentBaseLiquidity = (baseLiquidity as bigint | undefined) ?? 0n;
    const currentCollateral = collateralInfo as
      | {
          earningsBuffer?: bigint;
          protocolBuffer?: bigint;
          coveredBaseCollateral?: bigint;
        }
      | readonly unknown[]
      | undefined;
    const preview = bufferPreview as readonly unknown[] | undefined;

    if (!preview) {
      return {
        protocolDue: 0n,
        protectionDue: 0n,
        totalDue: 0n,
        baseLiquidity: currentBaseLiquidity,
      };
    }

    const requiredProtocol = (preview[0] as bigint | undefined) ?? 0n;
    const requiredProtection = (preview[1] as bigint | undefined) ?? 0n;
    const currentCollateralObject =
      currentCollateral && !Array.isArray(currentCollateral)
        ? (currentCollateral as { earningsBuffer?: bigint; protocolBuffer?: bigint })
        : undefined;
    const currentCollateralArray = Array.isArray(currentCollateral)
      ? (currentCollateral as readonly unknown[])
      : undefined;
    const currentProtocolFromArray = (currentCollateralArray?.[3] as bigint | undefined) ?? 0n;
    const currentProtectionFromArray = (currentCollateralArray?.[2] as bigint | undefined) ?? 0n;
    const currentProtocol = currentCollateralObject?.protocolBuffer ?? currentProtocolFromArray;
    const currentProtection = currentCollateralObject?.earningsBuffer ?? currentProtectionFromArray;

    const protocolDue = requiredProtocol > currentProtocol ? requiredProtocol - currentProtocol : 0n;
    const protectionDue = requiredProtection > currentProtection ? requiredProtection - currentProtection : 0n;

    return {
      protocolDue,
      protectionDue,
      totalDue: protocolDue + protectionDue,
      baseLiquidity: currentBaseLiquidity,
    };
  }, [baseLiquidity, bufferPreview, collateralInfo]);

  useEffect(() => {
    if (!isOpen) {
      setIsSubmitting(false);
    }
  }, [isOpen]);

  const requiresApproval =
    !!treasuryAddress &&
    fundingBreakdown.totalDue > 0n &&
    ((allowance as bigint | undefined) ?? 0n) < fundingBreakdown.totalDue;
  const canSubmit =
    !!treasuryAddress && (fundingBreakdown.totalDue > 0n || (immediateProceeds && fundingBreakdown.baseLiquidity > 0n));

  const proceedsProfileLabel = immediateProceeds ? "Earlier Proceeds Access" : "Gradual Proceeds Access";
  const proceedsAmountLabel = immediateProceeds ? "Available After Unlock" : "Available Over Time";
  const proceedsAmount = fundingBreakdown.baseLiquidity;
  const proceedsOutcomeCopy = immediateProceeds
    ? `Paying this amount enables release against up to ${formatTokenAmount(fundingBreakdown.baseLiquidity, decimals)} ${symbol} of proceeds on the current pool balance.`
    : `Paying this amount enables proceeds against up to ${formatTokenAmount(fundingBreakdown.baseLiquidity, decimals)} ${symbol} of current pool balance as earnings are distributed.`;

  const handleSubmit = async () => {
    if (!canSubmit) return;

    setIsSubmitting(true);
    try {
      if (requiresApproval) {
        await writePaymentToken({
          functionName: "approve",
          args: [treasuryAddress, fundingBreakdown.totalDue],
        });
      }

      await writeTreasury({
        functionName: "enableProceeds",
        args: [assetIdBigInt],
      });

      onSuccess?.();
      onClose();
    } catch (error) {
      console.error("Error enabling proceeds:", error);
    } finally {
      setIsSubmitting(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-backdrop bg-black/50 backdrop-blur-sm hidden sm:block" onClick={onClose} />
      <div className="modal-box relative w-full h-full max-h-full sm:h-auto sm:max-h-[90vh] sm:max-w-xl sm:rounded-2xl rounded-none flex flex-col p-0">
        <button
          type="button"
          className="btn btn-sm btn-circle btn-ghost absolute right-4 top-4 z-10"
          onClick={onClose}
          disabled={isSubmitting}
        >
          <XMarkIcon className="h-5 w-5" />
        </button>

        <div className="p-4 border-b border-base-200 shrink-0">
          <h3 className="font-bold text-xl">Unlock Proceeds</h3>
          <p className="text-sm opacity-60 mt-1">
            Pay the required amount for <span className="font-semibold">{assetName}</span> to unlock proceeds.
          </p>
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          <div className="flex flex-col gap-3">
            <div className="bg-base-200 p-4 rounded-lg border border-base-300">
              <div className="text-xs uppercase opacity-50 font-bold mb-3">What You Pay</div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 text-sm">
                <div>
                  <div className="opacity-60">Required Payment</div>
                  <div className="font-semibold">
                    {formatTokenAmount(fundingBreakdown.totalDue, decimals)} {symbol}
                  </div>
                </div>
                <div>
                  <div className="opacity-60">Access Timing</div>
                  <div className="font-semibold">{proceedsProfileLabel}</div>
                </div>
                <div>
                  <div className="opacity-60">Required Reserve Funding</div>
                  <div className="font-semibold">
                    {formatTokenAmount(fundingBreakdown.protocolDue, decimals)} {symbol}
                  </div>
                </div>
                <div>
                  <div className="opacity-60">{protectionEnabled ? "Optional Protection Funding" : "Protection"}</div>
                  <div className="font-semibold">
                    {protectionEnabled
                      ? `${formatTokenAmount(fundingBreakdown.protectionDue, decimals)} ${symbol}`
                      : "Not enabled"}
                  </div>
                </div>
                <div>
                  <div className="opacity-60">{proceedsAmountLabel}</div>
                  <div className="font-semibold">
                    {formatTokenAmount(proceedsAmount, decimals)} {symbol}
                  </div>
                </div>
              </div>
            </div>

            <div className="rounded-2xl border border-primary/20 bg-primary/10 px-4 py-4 text-sm text-base-content">
              <div className="font-semibold">What This Does</div>
              <div className="mt-2 space-y-1 opacity-80">
                <p>{proceedsOutcomeCopy}</p>
                <p>
                  {immediateProceeds
                    ? "Once unlocked, proceeds can be withdrawn right away."
                    : "Once unlocked, proceeds can be withdrawn over time through payout distributions."}
                </p>
              </div>
            </div>
          </div>
        </div>

        <div className="p-4 border-t border-base-200 shrink-0">
          <div className="flex gap-3">
            <button type="button" className="btn btn-ghost flex-1" onClick={onClose} disabled={isSubmitting}>
              Cancel
            </button>
            <button
              type="button"
              className="btn btn-primary flex-1"
              onClick={handleSubmit}
              disabled={isSubmitting || !canSubmit}
            >
              {requiresApproval ? "Approve & Unlock" : "Unlock Proceeds"}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
