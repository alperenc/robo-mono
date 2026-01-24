"use client";

import { useMemo } from "react";
import Image from "next/image";
import { formatUnits } from "viem";
import { ASSET_REGISTRIES, AssetType } from "~~/config/assetTypes";

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
  onBuyClick?: () => void;
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
  onBuyClick,
}: MarketAssetCardProps) {
  // Calculate display values
  const displayName = useMemo(() => {
    if (vehicle?.make && vehicle?.model && vehicle?.year) {
      return `${vehicle.year} ${vehicle.make} ${vehicle.model}`;
    }
    if (vehicle?.vin) return vehicle.vin;
    return `Asset #${listing.assetId}`;
  }, [vehicle, listing.assetId]);

  // Calculate APR - use realized if available, otherwise benchmark
  const aprDisplay = useMemo(() => {
    if (!token) return "10.00%"; // Default benchmark

    const tokenPrice = BigInt(token.price);
    const tokenSupply = BigInt(token.supply);
    const totalValue = tokenPrice * tokenSupply;

    if (earnings && earnings.firstDistributionAt !== "0") {
      // Calculate realized APR from actual earnings
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

    // Fallback to benchmark APR (10%)
    const benchmarkApr = Number(BENCHMARK_EARNINGS_BP) / 100;
    return `${benchmarkApr.toFixed(2)}%`;
  }, [token, earnings]);

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

  const registry = ASSET_REGISTRIES[assetType];

  return (
    <div className="card bg-base-100 shadow-lg hover:shadow-xl transition-all duration-300 overflow-hidden group">
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
        <div className="absolute top-3 left-3 right-3 flex justify-between items-start">
          <span className="badge badge-sm bg-base-100/90 backdrop-blur-sm border-0 shadow-md truncate max-w-[45%]">
            🔗 {networkName}
          </span>
          <span className="badge badge-success font-bold shadow-md text-xs">{aprDisplay} APR</span>
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
        <div className="grid grid-cols-2 gap-3 py-2">
          {earnings && earnings.distributionCount !== "0" ? (
            <>
              <div className="flex flex-col">
                <span className="text-xs opacity-50 uppercase tracking-wide">Total Earns</span>
                <span className="font-semibold text-success">{totalEarningsDisplay}</span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs opacity-50 uppercase tracking-wide">Distributions</span>
                <span className="font-semibold">{earnings.distributionCount}</span>
              </div>
            </>
          ) : (
            <div className="col-span-2 flex items-center justify-center py-1">
              <span className="badge badge-success text-success-content gap-1">✨ Newly Listed</span>
            </div>
          )}
        </div>

        {/* Action Button */}
        <div className="card-actions mt-2">
          <button className="btn btn-primary btn-block" onClick={onBuyClick} disabled={isInactive}>
            {isCancelled ? "Cancelled" : isEnded ? "Ended" : isExpired ? "Expired" : "Buy Tokens"}
          </button>
        </div>
      </div>
    </div>
  );
}
