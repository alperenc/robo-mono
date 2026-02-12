"use client";

import { useMemo } from "react";
import Image from "next/image";
import { formatUnits } from "viem";
import { useAccount } from "wagmi";
import { ASSET_REGISTRIES, AssetType } from "~~/config/assetTypes";
import { useScaffoldReadContract } from "~~/hooks/scaffold-eth";

// Protocol constants (matching Libraries.sol)
const BENCHMARK_EARNINGS_BP = 1000n; // 10% annually
const BP_PRECISION = 10000n;

interface MarketAssetCardProps {
  listing: {
    id: string;
    tokenId: string;
    assetId: string;
    pricePerToken: string;
    amount: string;
    amountSold?: string;
    expiresAt: string;
    seller: string;
    status?: string;
    isCancelled?: boolean;
    isEnded?: boolean;
  };
  vehicle?: {
    id: string;
    make?: string;
    model?: string;
    year?: string;
    vin?: string;
    metadataURI?: string;
  };
  token?: {
    price: string;
    supply: string;
    maturityDate: string;
    targetYieldBP?: string;
    soldSupply?: string;
  };
  earnings?: {
    totalEarnings: string;
    totalRevenue: string;
    distributionCount: string;
    firstDistributionAt: string;
    lastDistributionAt: string;
  };
  partner?: {
    name: string;
    address: string;
  };
  imageUrl?: string;
  networkName?: string;
  assetType?: AssetType;
  priority?: boolean;
  hasSellerListingForTokenId?: boolean;
  onBuyClick?: () => void;
  onClaimTokensClick?: () => void;
  onClaimRefundClick?: () => void;
  onClaimEarningsClick?: () => void;
  onClaimSettlementClick?: () => void;
  onListTokensClick?: (amount: string) => void;
  onFinalizeListingClick?: () => void;
  onEndListingClick?: () => void;
  onCancelListingClick?: () => void;
}

export function MarketAssetCard({
  listing,
  vehicle,
  token,
  earnings,
  partner,
  imageUrl,
  networkName = "Localhost",
  assetType = AssetType.VEHICLE,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  priority: _priority,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  hasSellerListingForTokenId: _hasSellerListingForTokenId,
  onBuyClick,
  onClaimTokensClick,
  onClaimRefundClick,
  onClaimEarningsClick,
  onClaimSettlementClick,
  onListTokensClick,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  onFinalizeListingClick: _onFinalizeListingClick,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  onEndListingClick: _onEndListingClick,
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  onCancelListingClick: _onCancelListingClick,
}: MarketAssetCardProps) {
  const { address } = useAccount();

  // Read user's escrowed token balance (marketplace)
  const { data: escrowedTokens } = useScaffoldReadContract({
    contractName: "Marketplace",
    functionName: "buyerTokens",
    args: [BigInt(listing.id), address],
  });

  // Read user's pending refund (marketplace)
  const { data: pendingRefund } = useScaffoldReadContract({
    contractName: "Marketplace",
    functionName: "buyerPayments",
    args: [BigInt(listing.id), address],
  });

  const { data: walletTokenBalance } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "balanceOf",
    args: [address, BigInt(listing.tokenId)],
  });

  const canClaimTokens = (escrowedTokens || 0n) > 0n && listing.isEnded && !listing.isCancelled;
  const canClaimRefund = (pendingRefund || 0n) > 0n && listing.isCancelled;
  const hasEarnings = Boolean(earnings && (earnings.distributionCount !== "0" || earnings.totalEarnings !== "0"));
  const hasHoldings = (walletTokenBalance || 0n) > 0n || (escrowedTokens || 0n) > 0n;
  const canClaimEarnings = hasEarnings && hasHoldings;
  const holdingsAmount = (walletTokenBalance || 0n) + (escrowedTokens || 0n);
  const canListTokens = holdingsAmount > 0n;
  const maturityMs = token ? Number(token.maturityDate) * 1000 : 0;
  const canClaimSettlement =
    hasHoldings && listing.isEnded && !listing.isCancelled && maturityMs > 0 && Date.now() >= maturityMs;

  // Calculate display values
  const displayName = useMemo(() => {
    if (vehicle?.make && vehicle?.model && vehicle?.year) {
      return `${vehicle.year} ${vehicle.make} ${vehicle.model}`;
    }
    if (vehicle?.vin) return vehicle.vin;
    return `Asset #${listing.assetId}`;
  }, [vehicle, listing.assetId]);

  // Calculate APY - use realized if available, otherwise target yield
  const apyDisplay = useMemo(() => {
    if (!token) return "10.00%"; // Default benchmark

    const tokenPrice = BigInt(token.price);
    const soldSupply =
      token.soldSupply && token.soldSupply !== "0"
        ? BigInt(token.soldSupply)
        : listing.amountSold
          ? BigInt(listing.amountSold)
          : 0n;
    const tokenSupply = BigInt(token.supply);
    const totalValue = soldSupply > 0n ? tokenPrice * soldSupply : tokenPrice * tokenSupply;

    if (earnings && earnings.firstDistributionAt !== "0") {
      // Calculate realized APY from actual earnings
      const totalEarnings = BigInt(earnings.totalEarnings);
      const firstDistAt = BigInt(earnings.firstDistributionAt);
      const lastDistAt = BigInt(earnings.lastDistributionAt);
      const duration = lastDistAt - firstDistAt;

      if (duration > 0n && totalValue > 0n) {
        // Annualize: (earnings / value) * (seconds_per_year / duration)
        const secondsPerYear = 365n * 24n * 60n * 60n;
        const annualizedEarnings = (totalEarnings * secondsPerYear) / duration;
        const aprBps = (annualizedEarnings * BP_PRECISION) / totalValue;
        const aprPercent = Number(aprBps) / 100;
        return `${aprPercent.toFixed(2)}%`;
      }
    }

    // Fallback to target yield APY (or benchmark if unavailable)
    const targetYieldBps = token.targetYieldBP ? Number(token.targetYieldBP) : Number(BENCHMARK_EARNINGS_BP);
    const targetYieldPercent = targetYieldBps / 100;
    return `${targetYieldPercent.toFixed(2)}%`;
  }, [token, earnings, listing.amountSold]);

  // Format total earnings
  const totalEarningsDisplay = useMemo(() => {
    if (!earnings || earnings.totalEarnings === "0") return "$0.00";
    // Assuming USDC with 6 decimals
    const amount = formatUnits(BigInt(earnings.totalEarnings), 6);
    return `$${Number(amount).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  }, [earnings]);

  // Format price per token
  const priceDisplay = useMemo(() => {
    const amount = formatUnits(BigInt(listing.pricePerToken), 6);
    return `$${Number(amount).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  }, [listing.pricePerToken]);

  // Format number compactly (e.g., 64000 -> "64K")
  const formatCompact = (num: number): string => {
    if (num >= 1000000) {
      return `${(num / 1000000).toFixed(num % 1000000 === 0 ? 0 : 1)}M`;
    }
    if (num >= 1000) {
      return `${(num / 1000).toFixed(num % 1000 === 0 ? 0 : 1)}K`;
    }
    return num.toLocaleString();
  };

  // Format available tokens (available/total)
  const availableTokensDisplay = useMemo(() => {
    const availableNum = Number(listing.amount);
    // Use explicit amountSold if available, otherwise assume remaining vs supply (which might be inaccurate if burn happened)
    // Actually, listing.amountSold is from subgraph which is accurate.
    const soldNum = listing.amountSold ? Number(listing.amountSold) : token ? Number(token.supply) - availableNum : 0;
    const totalNum = availableNum + soldNum;

    const soldPercentage = totalNum > 0 ? Math.round((soldNum / totalNum) * 100) : 0;
    return {
      available: formatCompact(availableNum),
      total: formatCompact(totalNum),
      soldPercentage,
    };
  }, [listing.amount, listing.amountSold, token]);

  // Check statuses
  const isExpired = useMemo(() => {
    return Number(listing.expiresAt) * 1000 < Date.now();
  }, [listing.expiresAt]);

  const isCancelled = listing.isCancelled;
  const isEnded = listing.isEnded;
  const isInactive = isCancelled || isEnded || isExpired;
  const isNewlyListed = !earnings || earnings.distributionCount === "0";

  const registry = ASSET_REGISTRIES[assetType];

  return (
    <div className="card bg-base-100 shadow-lg hover:shadow-xl transition-all duration-300 overflow-hidden group">
      {isNewlyListed && (
        <div className="absolute top-0 left-0 right-0 z-20 bg-success py-2 text-center text-sm font-bold tracking-wide text-success-content rounded-t-2xl">
          ✨ Newly Listed
        </div>
      )}

      {/* Image Section */}
      <figure className="relative h-48 bg-gradient-to-br from-base-200 to-base-300 overflow-hidden">
        {imageUrl ? (
          <Image
            src={imageUrl}
            alt={displayName}
            fill
            className="object-cover group-hover:scale-105 transition-transform duration-500"
            unoptimized
          />
        ) : (
          <div className="w-full h-full flex items-center justify-center">
            <span className="text-6xl opacity-30">{registry.icon}</span>
          </div>
        )}

        {/* Badges - stacked to prevent overlap */}
        <div className="absolute bottom-3 left-3 right-3 flex justify-between items-end gap-2 flex-wrap">
          <span className="badge badge-sm bg-base-100/90 backdrop-blur-sm border-0 shadow-md truncate max-w-[45%]">
            🔗 {networkName}
          </span>
          <div className="flex flex-col items-end gap-1">
            <span className="badge badge-success font-bold shadow-md text-xs">{apyDisplay} APY</span>
            {(escrowedTokens || 0n) > 0n && (
              <span className="badge badge-primary font-bold shadow-md text-[10px] animate-pulse">INVESTED</span>
            )}
          </div>
        </div>

        {/* Status Overlays */}
        {isCancelled && (
          <div className="absolute inset-0 bg-error/80 flex items-center justify-center z-10">
            <span className="badge badge-error badge-lg font-bold shadow-lg">CANCELLED</span>
          </div>
        )}
        {isEnded && !isCancelled && (
          <div className="absolute inset-0 bg-base-300/80 flex items-center justify-center z-10">
            <span className="badge badge-neutral badge-lg font-bold shadow-lg">SALE ENDED</span>
          </div>
        )}
        {isExpired && !isEnded && !isCancelled && (
          <div className="absolute inset-0 bg-warning/80 flex items-center justify-center z-10">
            <span className="badge badge-warning badge-lg font-bold shadow-lg">EXPIRED</span>
          </div>
        )}
      </figure>

      {/* Content Section */}
      <div className="card-body p-4 gap-2">
        {/* Asset Type */}
        <span className="text-xs font-semibold uppercase tracking-wider opacity-50">{assetType}</span>

        {/* Asset Name */}
        <h3 className="card-title text-lg font-bold truncate" title={displayName}>
          {displayName}
        </h3>

        {/* Partner Name */}
        {partner && <span className="text-xs text-primary -mt-1">by {partner.name}</span>}

        {/* Stats Grid */}
        <div className="grid grid-cols-2 gap-3 py-2">
          <div className="flex flex-col">
            <span className="text-xs opacity-50 uppercase tracking-wide">Price/Token</span>
            <span className="font-bold text-lg">{priceDisplay}</span>
          </div>
          <div className="flex flex-col">
            <span className="text-xs opacity-50 uppercase tracking-wide">Available</span>
            <span className="font-bold text-lg">
              {availableTokensDisplay.available}
              <span className="text-sm font-normal opacity-50"> / {availableTokensDisplay.total}</span>
            </span>
          </div>
        </div>

        {/* Sold Progress Bar */}
        <div className="w-full">
          <div className="flex justify-between text-xs mb-1">
            <span className="opacity-50">Sold</span>
            <span className="font-semibold">{availableTokensDisplay.soldPercentage}%</span>
          </div>
          <progress
            className={`progress w-full h-2 ${isCancelled ? "progress-error" : "progress-primary"}`}
            value={availableTokensDisplay.soldPercentage}
            max="100"
          ></progress>
        </div>

        {/* Earnings Row */}
        {earnings && earnings.distributionCount !== "0" && (
          <div className="grid grid-cols-2 gap-3 py-2">
            <div className="flex flex-col">
              <span className="text-xs opacity-50 uppercase tracking-wide">Total Earns</span>
              <span className="font-semibold text-success">{totalEarningsDisplay}</span>
            </div>
            <div className="flex flex-col">
              <span className="text-xs opacity-50 uppercase tracking-wide">Distributions</span>
              <span className="font-semibold">{earnings.distributionCount}</span>
            </div>
          </div>
        )}

        {/* Action Button */}
        <div className="card-actions mt-2">
          {(() => {
            let primaryLabel = "Buy Tokens";
            let primaryClass = "btn-primary";
            let primaryDisabled = isInactive;
            let primaryOnClick = onBuyClick;
            const secondaryActions: { label: string; onClick?: () => void; className?: string }[] = [];

            if (canClaimRefund) {
              primaryLabel = "Claim Refund";
              primaryClass = "btn-error";
              primaryDisabled = false;
              primaryOnClick = onClaimRefundClick;
            } else if (canClaimEarnings) {
              primaryLabel = "Claim Earnings";
              primaryClass = "btn-success";
              primaryDisabled = false;
              primaryOnClick = onClaimEarningsClick;
              if (canClaimSettlement) {
                secondaryActions.push({ label: "Claim Settlement", onClick: onClaimSettlementClick });
              }
              if (canListTokens) {
                secondaryActions.push({
                  label: "List Tokens",
                  onClick: () => onListTokensClick?.(holdingsAmount.toString()),
                });
              }
            } else if (canClaimTokens) {
              primaryLabel = "Claim Tokens";
              primaryClass = "btn-success";
              primaryDisabled = false;
              primaryOnClick = onClaimTokensClick;
            } else if (canListTokens && listing.isEnded) {
              primaryLabel = "List Tokens";
              primaryClass = "btn-primary";
              primaryDisabled = false;
              primaryOnClick = () => onListTokensClick?.(holdingsAmount.toString());
            } else {
              primaryLabel = isCancelled ? "Cancelled" : isEnded ? "Ended" : isExpired ? "Expired" : "Buy Tokens";
            }

            if (secondaryActions.length > 0) {
              return (
                <div className="dropdown dropdown-end w-full">
                  <div className="flex w-full">
                    <button
                      className={`btn ${primaryClass} rounded-r-none flex-1`}
                      onClick={primaryOnClick}
                      disabled={primaryDisabled}
                    >
                      {primaryLabel}
                    </button>
                    <div tabIndex={0} role="button" className={`btn ${primaryClass} rounded-l-none px-3`}>
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        fill="none"
                        viewBox="0 0 24 24"
                        strokeWidth="1.5"
                        stroke="currentColor"
                        aria-hidden="true"
                        data-slot="icon"
                        className="h-5 w-5"
                      >
                        <path strokeLinecap="round" strokeLinejoin="round" d="m19.5 8.25-7.5 7.5-7.5-7.5" />
                      </svg>
                    </div>
                  </div>
                  <ul
                    tabIndex={0}
                    className="dropdown-content z-[60] menu p-2 shadow bg-base-100 rounded-box w-full mt-2"
                  >
                    {secondaryActions.map(action => (
                      <li key={action.label}>
                        <button onClick={action.onClick} className="w-full text-left">
                          {action.label}
                        </button>
                      </li>
                    ))}
                  </ul>
                </div>
              );
            }

            return (
              <button className={`btn ${primaryClass} btn-block`} onClick={primaryOnClick} disabled={primaryDisabled}>
                {primaryLabel}
              </button>
            );
          })()}
        </div>
      </div>
    </div>
  );
}
