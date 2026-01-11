"use client";

import { useState } from "react";
import { parseUnits } from "viem";
import { useAccount } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

interface SettleAssetModalProps {
  isOpen: boolean;
  onClose: () => void;
  assetId: string;
  assetName: string;
}

export const SettleAssetModal = ({ isOpen, onClose, assetId, assetName }: SettleAssetModalProps) => {
  const { address: connectedAddress } = useAccount();
  const [topUpAmount, setTopUpAmount] = useState("");
  const [isConfirmed, setIsConfirmed] = useState(false);

  const { writeContractAsync: writeVehicleRegistry, isPending } = useScaffoldWriteContract({
    contractName: "VehicleRegistry",
  });

  const treasuryAddress = deployedContracts[31337]?.Treasury?.address;

  // Check USDC allowance
  const { data: allowance } = useScaffoldReadContract({
    contractName: "MockUSDC",
    functionName: "allowance",
    args: [connectedAddress, treasuryAddress],
    watch: true,
  });

  const { writeContractAsync: writeUsdc } = useScaffoldWriteContract({ contractName: "MockUSDC" });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!treasuryAddress) return;

    try {
      const topUpBigInt = topUpAmount ? parseUnits(topUpAmount, 6) : 0n;

      // Approve if needed and top-up amount is provided
      if (topUpBigInt > 0n && (!allowance || allowance < topUpBigInt)) {
        await writeUsdc({
          functionName: "approve",
          args: [treasuryAddress, topUpBigInt],
        });
      }

      // Settle the asset via VehicleRegistry
      await writeVehicleRegistry({
        functionName: "settleAsset",
        args: [BigInt(assetId), topUpBigInt],
      });

      setTopUpAmount("");
      setIsConfirmed(false);
      onClose();
    } catch (e) {
      console.error("Error settling asset:", e);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-backdrop bg-black/50 backdrop-blur-sm hidden sm:block" onClick={onClose} />
      <div className="modal-box relative w-full h-full max-h-full sm:h-auto sm:max-h-[90vh] sm:max-w-md sm:rounded-2xl rounded-none flex flex-col p-0">
        <form onSubmit={handleSubmit} className="flex flex-col h-full w-full">
          {/* Close Button */}
          <button
            type="button"
            className="btn btn-sm btn-circle btn-ghost absolute right-4 top-4 z-10"
            onClick={onClose}
            disabled={isPending}
          >
            <XMarkIcon className="h-5 w-5" />
          </button>

          {/* Header */}
          <div className="p-4 border-b border-base-200 shrink-0">
            <h3 className="font-bold text-xl">Settle Asset</h3>
            <p className="text-sm opacity-60 mt-1">End revenue distribution and trigger investor settlement</p>
          </div>

          {/* Scrollable Content */}
          <div className="flex-1 overflow-y-auto p-4">
            <div className="flex flex-col gap-3">
              {/* Warning Alert */}
              <div className="alert alert-warning">
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  className="stroke-current shrink-0 h-6 w-6"
                  fill="none"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth="2"
                    d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                  />
                </svg>
                <div>
                  <div className="font-semibold">This action is irreversible</div>
                  <div className="text-sm">
                    Settling <strong>{assetName}</strong> will end revenue distribution and allow token holders to claim their
                    settlement amount.
                  </div>
                </div>
              </div>

              {/* Top-Up Amount */}
              <div className="form-control">
                <label className="label py-1">
                  <span className="label-text text-xs font-bold uppercase opacity-60">Top-Up Amount (Optional)</span>
                </label>
                <div className="join w-full">
                  <input
                    type="number"
                    step="0.000001"
                    min="0"
                    className="input input-bordered join-item w-full"
                    value={topUpAmount}
                    onChange={e => setTopUpAmount(e.target.value)}
                    placeholder="0.00"
                  />
                  <span className="join-item btn btn-disabled bg-base-200 px-3">USDC</span>
                </div>
                <label className="label py-1">
                  <span className="label-text-alt text-xs opacity-60">
                    Add additional USDC to increase the settlement pool for token holders
                  </span>
                </label>
              </div>

              {/* Confirmation Checkbox */}
              <div className="form-control bg-base-200 p-4 rounded-lg">
                <label className="label cursor-pointer justify-start gap-3 p-0">
                  <input
                    type="checkbox"
                    checked={isConfirmed}
                    onChange={e => setIsConfirmed(e.target.checked)}
                    className="checkbox checkbox-error"
                  />
                  <span className="label-text">I understand this action cannot be undone</span>
                </label>
              </div>
            </div>
          </div>

          {/* Sticky Footer */}
          <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
            <div className="flex gap-3 justify-end">
              <button type="button" className="btn btn-ghost" onClick={onClose} disabled={isPending}>
                Cancel
              </button>
              <button type="submit" className="btn btn-error" disabled={isPending || !isConfirmed}>
                {isPending ? (
                  <>
                    <span className="loading loading-spinner loading-sm"></span>
                    Settling...
                  </>
                ) : (
                  "Settle Asset"
                )}
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
  );
};
