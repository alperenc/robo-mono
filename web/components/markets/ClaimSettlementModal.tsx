"use client";

import { useMemo } from "react";
import { formatUnits } from "viem";
import { useAccount, useReadContract } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { usePaymentToken } from "~~/hooks/usePaymentToken";

interface ClaimSettlementModalProps {
  isOpen: boolean;
  onClose: () => void;
  assetId: string;
  vehicleName: string;
}

export const ClaimSettlementModal = ({ isOpen, onClose, assetId, vehicleName }: ClaimSettlementModalProps) => {
  const { address } = useAccount();
  const { symbol: paymentSymbol, decimals: paymentDecimals } = usePaymentToken();
  const { writeContractAsync: writeRouter, isPending } = useScaffoldWriteContract({
    contractName: "RegistryRouter",
  });
  const { data: previewSettlementAmount } = useReadContract({
    address: deployedContracts[31337]?.Treasury?.address,
    abi: [
      {
        type: "function",
        name: "previewSettlementClaim",
        stateMutability: "view",
        inputs: [
          { name: "assetId", type: "uint256" },
          { name: "holder", type: "address" },
        ],
        outputs: [{ name: "", type: "uint256" }],
      },
    ] as const,
    functionName: "previewSettlementClaim",
    args: address ? [BigInt(assetId), address] : undefined,
    query: { enabled: isOpen && !!address },
  });
  const claimableAmount = previewSettlementAmount || 0n;
  const claimableDisplay = useMemo(() => {
    const formatted = formatUnits(claimableAmount, paymentDecimals);
    return Number(formatted).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }, [claimableAmount, paymentDecimals]);

  const handleClaim = async () => {
    if (claimableAmount === 0n || !address) return;
    try {
      await writeRouter({
        functionName: "claimSettlementFor",
        args: [address, BigInt(assetId), false],
      });
      onClose();
    } catch (e) {
      console.error("Error claiming settlement:", e);
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
          <h3 className="font-bold text-xl text-primary">Claim Settlement</h3>
          <p className="text-sm opacity-60 mt-1">{vehicleName}</p>
        </div>

        <div className="flex-1 overflow-y-auto p-4">
          <div className="bg-base-200 rounded-xl p-4">
            <p className="text-sm opacity-70 mb-2">Claimable Settlement</p>
            <p className="text-2xl font-bold text-primary">
              {claimableDisplay} <span className="text-base font-semibold opacity-80">{paymentSymbol}</span>
            </p>
            <p className="text-sm opacity-70 mt-3">
              Claim your settlement payout. This will burn your revenue tokens for this asset.
            </p>
          </div>
        </div>

        <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
          <button
            className="btn btn-primary btn-block"
            onClick={handleClaim}
            disabled={isPending || claimableAmount === 0n}
          >
            {isPending ? <span className="loading loading-spinner loading-sm" /> : "Claim Settlement"}
          </button>
        </div>
      </div>
    </div>
  );
};
