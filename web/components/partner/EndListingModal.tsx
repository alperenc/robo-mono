"use client";

import { useEffect, useState } from "react";
import { erc20Abi } from "viem";
import { useAccount, useReadContract, useWriteContract } from "wagmi";
import { XMarkIcon } from "@heroicons/react/24/outline";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";
import { usePaymentToken } from "~~/hooks/usePaymentToken";
import { formatTokenAmount } from "~~/utils/formatters";
import { getParsedError } from "~~/utils/scaffold-eth";

interface EndListingModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: () => void;
  listingId: string;
  tokenAmount: string;
  tokenId?: string;
  amountSold?: string;
  pricePerToken?: string;
  isPrimary?: boolean;
}

export const EndListingModal = ({
  isOpen,
  onClose,
  onSuccess,
  listingId,
  tokenAmount,
  tokenId,
  amountSold,
  pricePerToken,
  isPrimary,
}: EndListingModalProps) => {
  const { address } = useAccount();
  const { writeContractAsync: writeMarketplace, isPending } = useScaffoldWriteContract({ contractName: "Marketplace" });
  const {
    address: paymentTokenAddress,
    symbol: paymentTokenSymbol,
    decimals: paymentTokenDecimals,
  } = usePaymentToken();
  const { writeContractAsync: writeToken, isPending: isApproving } = useWriteContract();
  const treasuryAddress = deployedContracts[31337]?.Treasury?.address;
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const formattedTokenAmount = Number(tokenAmount).toLocaleString();

  const listingIdBigInt = listingId ? BigInt(listingId) : 0n;
  const providedTokenId = tokenId ? BigInt(tokenId) : undefined;
  const providedPricePerToken = pricePerToken ? BigInt(pricePerToken) : undefined;
  const providedAmountSold = amountSold ? BigInt(amountSold) : undefined;

  // Use scaffold-eth typed hooks — always provide args as a tuple, control with query.enabled
  const { data: listingData } = useScaffoldReadContract({
    contractName: "Marketplace",
    functionName: "getListing",
    args: [listingIdBigInt],
    query: { enabled: isOpen && !!listingId && !providedTokenId },
  });

  // Extract listing fields with proper types via `as any` to handle both struct and tuple returns
  const listingTokenId = providedTokenId ?? (listingData as any)?.tokenId ?? (listingData as any)?.[1];
  const listingSeller: string | undefined = (listingData as any)?.seller ?? (listingData as any)?.[5];
  const listingSoldAmount: bigint =
    providedAmountSold ?? (listingData as any)?.soldAmount ?? (listingData as any)?.[3] ?? 0n;
  const listingTotalAmount: bigint = (listingData as any)?.amount ?? (listingData as any)?.[2] ?? 0n;
  const listingPricePerToken: bigint =
    providedPricePerToken ?? (listingData as any)?.pricePerToken ?? (listingData as any)?.[4] ?? 0n;

  const resolvedTokenId = listingTokenId ? BigInt(listingTokenId) : 0n;

  const { data: tokenPrice } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "getTokenPrice",
    args: [resolvedTokenId],
    query: { enabled: isOpen && resolvedTokenId > 0n },
  });

  const { data: targetYieldBP } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "getTargetYieldBP",
    args: [resolvedTokenId],
    query: { enabled: isOpen && resolvedTokenId > 0n },
  });

  const { data: assetId } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "getAssetIdFromTokenId",
    args: [resolvedTokenId],
    query: { enabled: isOpen && resolvedTokenId > 0n },
  });

  const { data: sellerAssetBalance } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "balanceOf",
    args: [listingSeller ?? "0x0000000000000000000000000000000000000000", assetId ?? 0n],
    query: { enabled: isOpen && !!listingSeller && assetId !== undefined },
  });

  const listingIsPrimary = (listingData as any)?.isPrimary ?? (listingData as any)?.[12];

  const isPrimaryListing =
    typeof isPrimary === "boolean"
      ? isPrimary
      : typeof listingIsPrimary === "boolean"
        ? listingIsPrimary
        : sellerAssetBalance !== undefined
          ? (sellerAssetBalance as bigint) > 0n
          : true;

  let unsoldAmount = 0n;
  try {
    unsoldAmount = BigInt(tokenAmount.replace(/,/g, ""));
  } catch {
    unsoldAmount = 0n;
  }
  const derivedSoldAmount = listingTotalAmount > unsoldAmount ? listingTotalAmount - unsoldAmount : listingSoldAmount;
  const effectivePrice = listingPricePerToken > 0n ? listingPricePerToken : (tokenPrice as bigint) || 0n;
  const baseAmount = derivedSoldAmount * effectivePrice;

  const { data: totalBufferRequirement } = useScaffoldReadContract({
    contractName: "Treasury",
    functionName: "getTotalBufferRequirement",
    args: [baseAmount, (targetYieldBP as bigint) ?? 0n],
    query: { enabled: isOpen && isPrimaryListing && baseAmount > 0n && targetYieldBP !== undefined },
  });

  const bufferRequirement = isPrimaryListing ? ((totalBufferRequirement as bigint | undefined) ?? 0n) : 0n;
  const formattedBufferRequirement = formatTokenAmount(bufferRequirement, paymentTokenDecimals);
  const formattedBaseAmount = formatTokenAmount(baseAmount, paymentTokenDecimals);

  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: paymentTokenAddress,
    abi: erc20Abi,
    functionName: "allowance",
    args: address && treasuryAddress ? [address, treasuryAddress] : undefined,
    query: { enabled: !!address && !!treasuryAddress && !!paymentTokenAddress && isOpen },
  });

  const needsApproval =
    isPrimaryListing && bufferRequirement > 0n && allowance !== undefined ? allowance < bufferRequirement : false;

  useEffect(() => {
    if (!isOpen) setErrorMessage(null);
  }, [isOpen]);

  const handleConfirm = async () => {
    try {
      setErrorMessage(null);
      if (needsApproval && paymentTokenAddress && treasuryAddress) {
        await writeToken({
          address: paymentTokenAddress,
          abi: erc20Abi,
          functionName: "approve",
          args: [treasuryAddress, bufferRequirement],
        });
        await refetchAllowance?.();
      }

      const txHash = await writeMarketplace({
        functionName: "endListing",
        args: [BigInt(listingId)],
      });
      if (!txHash) {
        setErrorMessage("Transaction was not submitted. Please try again.");
        return;
      }

      onSuccess?.();
      onClose();
    } catch (e) {
      setErrorMessage(getParsedError(e));
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal modal-open">
      <div className="modal-backdrop bg-black/50 backdrop-blur-sm hidden sm:block" onClick={onClose} />
      <div className="modal-box relative w-full h-full max-h-full sm:h-auto sm:max-h-[90vh] sm:max-w-xl sm:rounded-2xl rounded-none flex flex-col p-0">
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
          <h3 className="font-bold text-xl">End Listing</h3>
          <p className="text-sm opacity-60 mt-1">Successfully end your active marketplace listing</p>
        </div>

        {/* Scrollable Content */}
        <div className="flex-1 overflow-y-auto p-4">
          <div className="flex flex-col gap-3">
            {errorMessage && (
              <div className="alert alert-error text-sm">
                <span>{errorMessage}</span>
              </div>
            )}
            {/* Confirmation Text */}
            <p className="text-sm opacity-70">
              {isPrimaryListing === false
                ? "Are you sure you want to end this listing? Proceeds will be settled to the Treasury for withdrawal. Use \u201cFinalize Listing\u201d to withdraw immediately."
                : "Are you sure you want to end this listing? Proceeds will be held in escrow and released over time with earnings distributions."}
            </p>

            {/* Unsold tokens note */}
            {Number(tokenAmount) > 0 && (
              <div className="bg-base-200 rounded-xl p-4">
                <div className="font-semibold text-sm">Unsold tokens</div>
                <div className="text-sm opacity-80 mt-1">
                  {isPrimaryListing === false ? (
                    <>
                      <span className="font-bold">{formattedTokenAmount}</span> unsold tokens will be returned to your
                      wallet.
                    </>
                  ) : (
                    <>
                      <span className="font-bold">{formattedTokenAmount}</span> unsold tokens will remain in marketplace
                      escrow.
                    </>
                  )}
                </div>
              </div>
            )}

            {/* Buffer payment */}
            {isPrimaryListing !== false && bufferRequirement > 0n && (
              <div className="bg-base-200 rounded-xl p-4 space-y-2">
                <div className="text-sm font-semibold">Buffers required to end listing</div>
                <div className="flex justify-between text-sm opacity-80">
                  <span>Sold amount (base)</span>
                  <span>
                    {formattedBaseAmount} {paymentTokenSymbol}
                  </span>
                </div>
                <div className="flex justify-between text-sm opacity-80">
                  <span>Buffers due now</span>
                  <span>
                    {formattedBufferRequirement} {paymentTokenSymbol}
                  </span>
                </div>
                <div className="divider my-1"></div>
                <div className="flex justify-between font-bold">
                  <span>Total payment</span>
                  <span>
                    {formattedBufferRequirement} {paymentTokenSymbol}
                  </span>
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Sticky Footer */}
        <div className="shrink-0 border-t border-base-200 bg-base-100 p-4">
          <div className="flex gap-3 justify-end">
            <button className="btn btn-ghost" onClick={onClose} disabled={isPending}>
              Keep Listing
            </button>
            <button className="btn btn-primary" onClick={handleConfirm} disabled={isPending || isApproving}>
              {isPending ? (
                <>
                  <span className="loading loading-spinner loading-sm"></span>
                  Ending...
                </>
              ) : isApproving ? (
                <>
                  <span className="loading loading-spinner loading-sm"></span>
                  Approving...
                </>
              ) : (
                "End Listing"
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
