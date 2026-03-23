"use client";

import { useEffect, useMemo, useState } from "react";
import { formatUnits } from "viem";
import { useAccount } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { usePaymentToken } from "~~/hooks/usePaymentToken";

interface ClaimEarningsModalProps {
  isOpen: boolean;
  onClose: () => void;
  assetId: string;
  vehicleName: string;
}

export const ClaimEarningsModal = ({ isOpen, onClose, assetId, vehicleName }: ClaimEarningsModalProps) => {
  const { address } = useAccount();
  const { symbol: paymentSymbol, decimals: paymentDecimals } = usePaymentToken();
  const { writeContractAsync: writeTreasury, isPending } = useScaffoldWriteContract({ contractName: "Treasury" });
  const { writeContractAsync: writeEarningsManager } = useScaffoldWriteContract({ contractName: "EarningsManager" });
  const [submittedClaimAmount, setSubmittedClaimAmount] = useState<bigint | null>(null);
  const { data: previewClaimAmount } = useScaffoldReadContract({
    contractName: "EarningsManager",
    functionName: "previewClaimEarnings",
    args: [BigInt(assetId), address],
    query: { enabled: isOpen && !!address },
  });
  const claimableAmount = previewClaimAmount || 0n;
  const displayedClaimAmount = submittedClaimAmount ?? claimableAmount;
  const claimableDisplay = useMemo(() => {
    const formatted = formatUnits(displayedClaimAmount, paymentDecimals);
    return Number(formatted).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }, [displayedClaimAmount, paymentDecimals]);

  useEffect(() => {
    if (!isOpen) {
      setSubmittedClaimAmount(null);
    }
  }, [isOpen]);

  const handleClaim = async () => {
    if (claimableAmount === 0n) return;
    try {
      setSubmittedClaimAmount(claimableAmount);
      await writeEarningsManager({
        functionName: "claimEarnings",
        args: [BigInt(assetId)],
      });
      await writeTreasury({
        functionName: "processWithdrawal",
      });
      onClose();
    } catch (e) {
      console.error("Error claiming earnings:", e);
      setSubmittedClaimAmount(null);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-backdrop bg-black/50 backdrop-blur-sm hidden sm:block" onClick={onClose} />
      <div className="modal-box relative w-full h-full max-h-full sm:h-auto sm:max-h-[90vh] sm:max-w-xl sm:rounded-2xl rounded-none flex flex-col p-0">
        <button
          className="btn btn-sm btn-circle btn-ghost absolute right-4 top-4 z-10"
          onClick={onClose}
          disabled={isPending}
        >
          <XMarkIcon className="h-5 w-5" />
        </button>

        <div className="p-4 border-b border-base-200 shrink-0">
          <h3 className="font-bold text-xl">Claim Payout</h3>
          <p className="text-sm opacity-60 mt-1">{vehicleName}</p>
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          <div className="bg-success/10 rounded-xl p-4">
            <p className="text-sm text-base-content/70 mb-2">Claimable Amount</p>
            <p className="text-2xl font-bold text-success">
              {claimableDisplay} <span className="text-base font-semibold opacity-80">{paymentSymbol}</span>
            </p>
            <p className="text-sm text-base-content/70 mt-3">
              Claiming now submits the earnings claim and then processes the withdrawal to your wallet.
            </p>
          </div>
        </div>

        <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
          <button
            className="btn btn-primary btn-block"
            onClick={handleClaim}
            disabled={isPending || displayedClaimAmount === 0n}
          >
            {isPending ? <span className="loading loading-spinner loading-sm" /> : "Claim Payout"}
          </button>
        </div>
      </div>
    </div>
  );
};
