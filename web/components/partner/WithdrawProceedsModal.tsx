"use client";

import { formatUnits } from "viem";
import { useAccount, useReadContract } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

interface WithdrawProceedsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const WithdrawProceedsModal = ({ isOpen, onClose }: WithdrawProceedsModalProps) => {
  const { address } = useAccount();
  const { writeContractAsync: writeTreasury, isPending } = useScaffoldWriteContract({ contractName: "Treasury" });

  // Fetch pending withdrawal amount
  const { data: pendingAmount, isLoading: isLoadingPending } = useReadContract({
    address: deployedContracts[31337]?.Treasury?.address,
    abi: deployedContracts[31337]?.Treasury?.abi,
    functionName: "getPendingWithdrawal",
    args: address ? [address] : undefined,
    query: { enabled: !!address && isOpen },
  });

  const formattedAmount = pendingAmount ? formatUnits(pendingAmount as bigint, 6) : "0";
  const hasProceeds = pendingAmount && (pendingAmount as bigint) > 0n;

  const handleWithdraw = async () => {
    try {
      await writeTreasury({
        functionName: "processWithdrawal",
      });
      onClose();
    } catch (e) {
      console.error("Error withdrawing proceeds:", e);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-backdrop bg-black/50 backdrop-blur-sm hidden sm:block" onClick={onClose} />
      <div className="modal-box relative w-full h-full max-h-full sm:h-auto sm:max-h-[90vh] sm:max-w-md sm:rounded-2xl rounded-none flex flex-col p-0">
        {/* Close Button */}
        <button
          className="btn btn-sm btn-circle btn-ghost absolute right-4 top-4 z-10"
          onClick={onClose}
          disabled={isPending}
        >
          <XMarkIcon className="h-5 w-5" />
        </button>

        {/* Header */}
        <div className="p-4 border-b border-base-200 shrink-0">
          <h3 className="font-bold text-xl">Withdraw Proceeds</h3>
          <p className="text-sm opacity-60 mt-1">Withdraw your pending sales proceeds</p>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto p-4">
          <div className="flex flex-col gap-4">
            {isLoadingPending ? (
              <div className="flex justify-center py-8">
                <span className="loading loading-spinner loading-lg" />
              </div>
            ) : hasProceeds ? (
              <>
                <div className="stat bg-success/10 rounded-xl">
                  <div className="stat-title">Available to Withdraw</div>
                  <div className="stat-value text-success">{Number(formattedAmount).toLocaleString()} USDC</div>
                  <div className="stat-desc">USDC from marketplace sales</div>
                </div>
                <p className="text-sm opacity-70">
                  Click withdraw to transfer your pending sales proceeds to your wallet.
                </p>
              </>
            ) : (
              <div className="alert alert-info">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  fill="none"
                  viewBox="0 0 24 24"
                  className="stroke-current shrink-0 w-6 h-6"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <span>No pending proceeds to withdraw.</span>
              </div>
            )}
          </div>
        </div>

        {/* Footer */}
        <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
          <div className="flex gap-3 justify-end">
            <button className="btn btn-ghost" onClick={onClose} disabled={isPending}>
              Cancel
            </button>
            <button className="btn btn-success" onClick={handleWithdraw} disabled={isPending || !hasProceeds}>
              {isPending ? (
                <>
                  <span className="loading loading-spinner loading-sm" />
                  Withdrawing...
                </>
              ) : (
                `Withdraw ${Number(formattedAmount).toLocaleString()} USDC`
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
