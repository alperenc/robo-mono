"use client";

import { type KeyboardEvent, type MouseEvent, useEffect, useMemo, useRef, useState } from "react";
import Image from "next/image";
import { formatUnits } from "viem";
import { useAccount } from "wagmi";
import { ASSET_REGISTRIES, AssetType } from "~~/config/assetTypes";
import { useScaffoldReadContract } from "~~/hooks/scaffold-eth";
import { usePaymentToken } from "~~/hooks/usePaymentToken";

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
    isPrimary?: boolean;
    isCancelled?: boolean;
    isEnded?: boolean;
    createdAt?: string;
    soldOutAt?: string;
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
  hasUserListingForTokenId?: boolean;
  hasUserActiveListingForTokenId?: boolean;
  hasUserBoughtListing?: boolean;
  tokenTotalSoldAmount?: string;
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
  priority,
  hasUserListingForTokenId = false,
  hasUserActiveListingForTokenId = false,
  hasUserBoughtListing = false,
  tokenTotalSoldAmount,
  onBuyClick,
  onClaimTokensClick,
  onClaimRefundClick,
  onClaimEarningsClick,
  onClaimSettlementClick,
  onListTokensClick,
  onFinalizeListingClick,
  onEndListingClick,
  onCancelListingClick,
}: MarketAssetCardProps) {
  const { address } = useAccount();
  const { symbol: paymentSymbol, decimals: paymentDecimals } = usePaymentToken();
  const actionDropdownRef = useRef<HTMLDivElement>(null);
  const [isActionMenuOpen, setIsActionMenuOpen] = useState(false);

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
  const { data: protocolConfig } = useScaffoldReadContract({
    contractName: "Treasury",
    functionName: "getProtocolConfig",
  });
  const { data: previewClaimAmount } = useScaffoldReadContract({
    contractName: "Treasury",
    functionName: "previewClaimEarnings",
    args: [BigInt(listing.assetId), address],
    query: { enabled: !!address },
  });
  const { data: assetStatus } = useScaffoldReadContract({
    contractName: "RegistryRouter",
    functionName: "getAssetStatus",
    args: [BigInt(listing.assetId)],
  });
  const bpPrecision = protocolConfig?.[0];
  const benchmarkYieldBP = protocolConfig?.[1];
  const depreciationRateBP = protocolConfig?.[4];

  const canClaimTokens = (escrowedTokens || 0n) > 0n && listing.isEnded && !listing.isCancelled;
  const canClaimRefund = (pendingRefund || 0n) > 0n && listing.isCancelled;
  const hasAvailableTokens = BigInt(listing.amount) > 0n;
  const hasEarnings = Boolean(earnings && (earnings.distributionCount !== "0" || earnings.totalEarnings !== "0"));
  const canClaimEarnings = (previewClaimAmount || 0n) > 0n;
  const canClaimEarningsOnThisListing = canClaimEarnings && hasUserBoughtListing;
  const hasHoldings = (walletTokenBalance || 0n) > 0n || (escrowedTokens || 0n) > 0n;
  const isAssetSettled = Number(assetStatus ?? -1) === 3 || Number(assetStatus ?? -1) === 4;
  const canClaimSettlement = hasHoldings && isAssetSettled;
  const listingSoldAmount = useMemo(() => {
    if (listing.amountSold && listing.amountSold !== "0") return BigInt(listing.amountSold);
    if (token?.supply) {
      const derived = BigInt(token.supply) - BigInt(listing.amount);
      return derived > 0n ? derived : 0n;
    }
    return 0n;
  }, [listing.amount, listing.amountSold, token?.supply]);

  const soldSupplyForAllocation = useMemo(() => {
    if (tokenTotalSoldAmount && tokenTotalSoldAmount !== "0") return BigInt(tokenTotalSoldAmount);
    if (token?.soldSupply && token.soldSupply !== "0") return BigInt(token.soldSupply);
    return listingSoldAmount;
  }, [tokenTotalSoldAmount, token?.soldSupply, listingSoldAmount]);

  const listingActualEarnings = useMemo(() => {
    if (listing.isCancelled) return 0n;
    if (!earnings || earnings.totalEarnings === "0") return 0n;
    if (listingSoldAmount <= 0n || soldSupplyForAllocation <= 0n) return 0n;
    return (BigInt(earnings.totalEarnings) * listingSoldAmount) / soldSupplyForAllocation;
  }, [earnings, listing.isCancelled, listingSoldAmount, soldSupplyForAllocation]);

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
    if (!token) {
      if (benchmarkYieldBP === undefined) return "—";
      return `${(Number(benchmarkYieldBP) / 100).toFixed(2)}%`;
    }
    if (bpPrecision === undefined) return "—";

    const tokenPrice = BigInt(token.price);
    const principalAmount = listingSoldAmount > 0n ? listingSoldAmount : BigInt(listing.amount);
    const totalValue = tokenPrice * principalAmount;

    if (earnings && listingActualEarnings > 0n && totalValue > 0n) {
      // Prefer annualized realized APY when full timing exists; otherwise use realized return to-date.
      const firstDistAt = BigInt(earnings.firstDistributionAt || "0");
      const lastDistAt = BigInt(earnings.lastDistributionAt || "0");
      const duration = lastDistAt - firstDistAt;
      let aprBps: bigint;

      if (duration > 0n && firstDistAt > 0n) {
        const secondsPerYear = 365n * 24n * 60n * 60n;
        const annualizedEarnings = (listingActualEarnings * secondsPerYear) / duration;
        aprBps = (annualizedEarnings * bpPrecision) / totalValue;
      } else {
        aprBps = (listingActualEarnings * bpPrecision) / totalValue;
      }

      const aprPercent = Number(aprBps) / 100;
      return `${aprPercent.toFixed(2)}%`;
    }

    // Fallback to target yield APY (or benchmark if unavailable)
    const targetYieldBps = token.targetYieldBP
      ? Number(token.targetYieldBP)
      : benchmarkYieldBP !== undefined
        ? Number(benchmarkYieldBP)
        : 0;
    const targetYieldPercent = targetYieldBps / 100;
    return `${targetYieldPercent.toFixed(2)}%`;
  }, [token, benchmarkYieldBP, bpPrecision, earnings, listing.amount, listingActualEarnings, listingSoldAmount]);

  // Format listing-scoped actual earnings (numeric value only — symbol rendered separately)
  const actualEarningsDisplay = useMemo(() => {
    if (listingActualEarnings === 0n) return "0.00";
    const amount = formatUnits(listingActualEarnings, paymentDecimals);
    return Number(amount).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }, [listingActualEarnings, paymentDecimals]);

  // Calculate projected earnings (per year and at maturity)
  const projectedEarnings = useMemo(() => {
    if (!token) return { perYear: "—", atMaturity: "—" };
    if (bpPrecision === undefined || benchmarkYieldBP === undefined || depreciationRateBP === undefined) {
      return { perYear: "—", atMaturity: "—" };
    }
    if (listing.isCancelled) {
      return { perYear: "0.00", atMaturity: "0.00" };
    }

    const tokenPrice = BigInt(token.price);
    const listingAmountForProjection = listing.isCancelled
      ? 0n
      : listing.isEnded || !hasAvailableTokens
        ? listingSoldAmount
        : BigInt(listing.amount);
    const totalValue = tokenPrice * listingAmountForProjection; // listing-specific value basis for projections
    if (totalValue === 0n) {
      return { perYear: "0.00", atMaturity: "0.00" };
    }
    const targetYieldBps = token.targetYieldBP ? BigInt(token.targetYieldBP) : benchmarkYieldBP;

    // earnings per year = totalValue * targetYieldBP / 10000
    const earningsPerYear = (totalValue * targetYieldBps) / bpPrecision;
    const perYearFormatted = Number(formatUnits(earningsPerYear, paymentDecimals)).toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });

    // earnings at maturity = earningsPerYear * yearsToMaturity
    const maturitySec = Number(token.maturityDate);
    const nowSec = Math.floor(Date.now() / 1000);
    const secondsPerYear = 365 * 24 * 60 * 60;
    // Use full term from listing creation (approximate) — or remaining time if already listed
    const remainingSec = maturitySec > nowSec ? maturitySec - nowSec : 0;
    const yearsRemaining = remainingSec / secondsPerYear;

    if (yearsRemaining <= 0) {
      // Already at maturity — base is returned, show base + one year of earnings as minimum
      const atMaturityTotal = totalValue + earningsPerYear;
      const atMaturityFormatted = Number(formatUnits(atMaturityTotal, paymentDecimals)).toLocaleString(undefined, {
        minimumFractionDigits: 2,
        maximumFractionDigits: 2,
      });
      return { perYear: perYearFormatted, atMaturity: atMaturityFormatted };
    }

    // base (principal returned at settlement) + projected earnings over remaining term
    const projectedTotalEarnings = (earningsPerYear * BigInt(Math.round(yearsRemaining * 1000))) / 1000n;

    // Principal depreciates by 12% per year (released to partner)
    // recoverableBase = totalValue - (totalValue * 12% * yearsRemaining)
    const depreciationAmount =
      (totalValue * depreciationRateBP * BigInt(Math.round(yearsRemaining * 1000))) / (bpPrecision * 1000n);
    const recoverableBase = totalValue > depreciationAmount ? totalValue - depreciationAmount : 0n;

    const atMaturityTotal = recoverableBase + projectedTotalEarnings;
    const atMaturityFormatted = Number(formatUnits(atMaturityTotal, paymentDecimals)).toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });

    return { perYear: perYearFormatted, atMaturity: atMaturityFormatted };
  }, [
    token,
    bpPrecision,
    benchmarkYieldBP,
    depreciationRateBP,
    listing.amount,
    listing.isCancelled,
    listing.isEnded,
    hasAvailableTokens,
    listingSoldAmount,
    paymentDecimals,
  ]);

  // Format price per token (numeric value only — symbol rendered separately)
  const priceDisplay = useMemo(() => {
    const amount = formatUnits(BigInt(listing.pricePerToken), paymentDecimals);
    return Number(amount).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }, [listing.pricePerToken, paymentDecimals]);

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

  const formatDuration = (seconds: number): string => {
    if (seconds < 60) return `${seconds}s`;
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60) return `${minutes}m`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h ${minutes % 60}m`;
    const days = Math.floor(hours / 24);
    return `${days}d ${hours % 24}h`;
  };

  // Format available tokens (available/total)
  const availableTokensDisplay = useMemo(() => {
    const availableNum = Number(listing.amount);
    // Use explicit amountSold if available, otherwise assume remaining vs supply (which might be inaccurate if burn happened)
    // Actually, listing.amountSold is from subgraph which is accurate.
    const historicalSoldNum = listing.amountSold
      ? Number(listing.amountSold)
      : token
        ? Number(token.supply) - availableNum
        : 0;

    const displayAvailableNum = listing.isCancelled || listing.isEnded ? 0 : availableNum;
    const soldNum = listing.isCancelled ? 0 : historicalSoldNum;
    const totalNum = listing.isCancelled || listing.isEnded ? availableNum + historicalSoldNum : availableNum + soldNum;
    const soldPercentage = listing.isCancelled ? 0 : totalNum > 0 ? Math.round((soldNum / totalNum) * 100) : 0;
    return {
      available: formatCompact(displayAvailableNum),
      total: formatCompact(totalNum),
      soldPercentage,
    };
  }, [listing.amount, listing.amountSold, listing.isCancelled, listing.isEnded, token]);

  // Check statuses
  const isExpired = useMemo(() => {
    return Number(listing.expiresAt) * 1000 < Date.now();
  }, [listing.expiresAt]);

  const isCancelled = listing.isCancelled;
  const isEnded = listing.isEnded;
  const isInactive = isCancelled || isEnded || isExpired;
  const soldOutDurationLabel = useMemo(() => {
    if (hasAvailableTokens) return null;
    if (!listing.createdAt || !listing.soldOutAt) return "Sold Out";
    const createdAt = Number(listing.createdAt);
    const soldOutAt = Number(listing.soldOutAt);
    if (!Number.isFinite(createdAt) || !Number.isFinite(soldOutAt) || createdAt <= 0 || soldOutAt <= 0) {
      return "Sold Out";
    }
    const durationSec = Math.max(0, Math.floor(soldOutAt - createdAt));
    return `Sold Out In ${formatDuration(durationSec)}`;
  }, [hasAvailableTokens, listing.createdAt, listing.soldOutAt]);
  const isNewlyListed =
    hasAvailableTokens && !isCancelled && !isEnded && (!earnings || earnings.distributionCount === "0");
  const isSellerOfListing = Boolean(address && listing.seller.toLowerCase() === address.toLowerCase());
  const isSecondaryListing = listing.isPrimary === false;
  const showSecondaryListingBadge = isSecondaryListing && !isInactive;
  const primarySellerEscrowAmount = isSellerOfListing && !isSecondaryListing ? BigInt(listing.amount) : 0n;
  const listableTokensAmount =
    isSellerOfListing && !isSecondaryListing
      ? primarySellerEscrowAmount + (walletTokenBalance || 0n)
      : walletTokenBalance || 0n;
  const canListTokens = listableTokensAmount > 0n;

  const registry = ASSET_REGISTRIES[assetType];
  const showInvestedBadge =
    !isCancelled &&
    !isSellerOfListing &&
    ((walletTokenBalance || 0n) > 0n || (escrowedTokens || 0n) > 0n || hasUserListingForTokenId);
  const actionState = useMemo(() => {
    const listTokensLabel = hasUserActiveListingForTokenId || isSellerOfListing ? "List More Tokens" : "List Tokens";
    let primaryLabel = "Buy Tokens";
    let primaryClass = "btn-primary";
    let primaryDisabled = isInactive;
    let primaryOnClick = onBuyClick;
    const secondaryActions: { label: string; onClick?: () => void; className?: string }[] = [];

    // Determine if user has claimed tokens into their wallet
    const hasClaimedTokens = (walletTokenBalance || 0n) > 0n;
    const canManageOwnListing = isSellerOfListing && !isInactive;
    const canRelistInactiveOwnPrimaryListing = isSellerOfListing && !isSecondaryListing && isInactive && canListTokens;
    const sellerManagementActions: { label: string; onClick?: () => void; className?: string }[] = [];

    if (canManageOwnListing) {
      if (isSecondaryListing && onFinalizeListingClick) {
        // Secondary seller: finalize is the primary management action.
        sellerManagementActions.push({ label: "Finalize Listing", onClick: onFinalizeListingClick });
      }
      if (onEndListingClick) sellerManagementActions.push({ label: "End Listing", onClick: onEndListingClick });
      if (onCancelListingClick) {
        sellerManagementActions.push({
          label: "Cancel Listing",
          onClick: onCancelListingClick,
          className: "text-error",
        });
      }
      if (canListTokens) {
        sellerManagementActions.push({
          label: listTokensLabel,
          onClick: () => onListTokensClick?.(listableTokensAmount.toString()),
        });
      }
    }

    if (canClaimRefund) {
      // Top priority: refund on cancelled listings
      primaryLabel = "Claim Refund";
      primaryClass = "btn-error";
      primaryDisabled = false;
      primaryOnClick = onClaimRefundClick;
    } else if (canRelistInactiveOwnPrimaryListing) {
      // Primary seller can relist inventory that remains in escrow after listing becomes inactive.
      primaryLabel = listTokensLabel;
      primaryClass = "btn-primary";
      primaryDisabled = false;
      primaryOnClick = () => onListTokensClick?.(listableTokensAmount.toString());
    } else if (sellerManagementActions.length > 0) {
      // Seller managing their own listing (primary: no finalize, secondary: finalize first)
      primaryLabel = sellerManagementActions[0].label;
      primaryClass = sellerManagementActions[0].label === "Cancel Listing" ? "btn-error" : "btn-primary";
      primaryDisabled = false;
      primaryOnClick = sellerManagementActions[0].onClick;
      secondaryActions.push(...sellerManagementActions.slice(1));
    } else if (canClaimTokens) {
      // Tokens still in escrow — prompt to claim first
      primaryLabel = "Claim Tokens";
      primaryClass = "btn-success";
      primaryDisabled = false;
      primaryOnClick = onClaimTokensClick;
      // If user already has wallet tokens of the same tokenId, allow listing them immediately.
      if (hasClaimedTokens) {
        secondaryActions.push({
          label: listTokensLabel,
          onClick: () => onListTokensClick?.((walletTokenBalance || 0n).toString()),
        });
      }
    } else if (canClaimEarningsOnThisListing) {
      // On-chain preview is the source of truth for claimability.
      primaryLabel = "Claim Earnings";
      primaryClass = "btn-success";
      primaryDisabled = false;
      primaryOnClick = onClaimEarningsClick;
      if (canClaimSettlement) {
        secondaryActions.push({ label: "Claim Settlement", onClick: onClaimSettlementClick });
      } else if (canListTokens) {
        secondaryActions.push({
          label: listTokensLabel,
          onClick: () => onListTokensClick?.(listableTokensAmount.toString()),
        });
      }
    } else if (!isSellerOfListing && !isInactive) {
      // For other users' active listings, prioritize market participation
      primaryLabel = hasAvailableTokens ? "Buy Tokens" : soldOutDurationLabel || "Sold Out";
      primaryClass = "btn-primary";
      primaryDisabled = !hasAvailableTokens;
      primaryOnClick = onBuyClick;
      if (canListTokens) {
        secondaryActions.push({
          label: listTokensLabel,
          onClick: () => onListTokensClick?.(listableTokensAmount.toString()),
        });
      }
    } else if (hasClaimedTokens) {
      // User holds tokens — show holder-specific CTAs
      if (canClaimSettlement) {
        // No earnings but settled: primary = Claim Settlement
        primaryLabel = "Claim Settlement";
        primaryClass = "btn-warning";
        primaryDisabled = false;
        primaryOnClick = onClaimSettlementClick;
      } else {
        // No earnings, not settled: primary = List Tokens
        primaryLabel = listTokensLabel;
        primaryClass = "btn-primary";
        primaryDisabled = false;
        primaryOnClick = () => onListTokensClick?.(listableTokensAmount.toString());
      }
    } else {
      // No holdings — default buy/status label
      primaryLabel = isCancelled ? "Cancelled" : isEnded ? "Ended" : isExpired ? "Expired" : "Buy Tokens";
    }

    return {
      primaryLabel,
      primaryClass,
      primaryDisabled,
      primaryOnClick,
      secondaryActions,
    };
  }, [
    canClaimRefund,
    canClaimTokens,
    canClaimSettlement,
    canClaimEarningsOnThisListing,
    hasAvailableTokens,
    soldOutDurationLabel,
    hasUserActiveListingForTokenId,
    isCancelled,
    isEnded,
    isExpired,
    isInactive,
    isSecondaryListing,
    isSellerOfListing,
    listableTokensAmount,
    canListTokens,
    onBuyClick,
    onCancelListingClick,
    onClaimEarningsClick,
    onClaimRefundClick,
    onClaimSettlementClick,
    onClaimTokensClick,
    onEndListingClick,
    onFinalizeListingClick,
    onListTokensClick,
    walletTokenBalance,
  ]);

  const isCardPressable = Boolean(actionState.primaryOnClick) && !actionState.primaryDisabled;
  const hasAvailableActions = isCardPressable || actionState.secondaryActions.some(action => Boolean(action.onClick));
  const triggerPrimaryAction = () => {
    if (!isCardPressable) return;
    actionState.primaryOnClick?.();
  };
  const handleCardClick = (event: MouseEvent<HTMLDivElement>) => {
    if (!isCardPressable) return;
    const target = event.target as HTMLElement;
    const interactiveAncestor = target.closest("button, a, input, select, textarea, [role='button']");
    if (interactiveAncestor && interactiveAncestor !== event.currentTarget) return;
    triggerPrimaryAction();
  };
  const handleCardKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    if (!isCardPressable) return;
    if (event.key !== "Enter" && event.key !== " ") return;
    event.preventDefault();
    triggerPrimaryAction();
  };

  useEffect(() => {
    if (actionState.secondaryActions.length === 0) {
      setIsActionMenuOpen(false);
    }
  }, [actionState.secondaryActions.length]);

  useEffect(() => {
    if (!isActionMenuOpen) return;

    const closeIfOutside = (event: MouseEvent | globalThis.MouseEvent | TouchEvent) => {
      const target = event.target as Node | null;
      if (!target) return;
      if (actionDropdownRef.current?.contains(target)) return;
      setIsActionMenuOpen(false);
    };

    const closeOnEscape = (event: globalThis.KeyboardEvent) => {
      if (event.key === "Escape") setIsActionMenuOpen(false);
    };

    document.addEventListener("mousedown", closeIfOutside);
    document.addEventListener("touchstart", closeIfOutside);
    document.addEventListener("keydown", closeOnEscape);
    return () => {
      document.removeEventListener("mousedown", closeIfOutside);
      document.removeEventListener("touchstart", closeIfOutside);
      document.removeEventListener("keydown", closeOnEscape);
    };
  }, [isActionMenuOpen]);

  return (
    <div
      className={`card h-full bg-base-100 shadow-lg transition-all duration-300 overflow-hidden group ${
        hasAvailableActions ? "hover:shadow-xl" : "opacity-70 saturate-50"
      } ${isCardPressable ? "cursor-pointer hover:-translate-y-1 active:translate-y-0 active:scale-[0.995]" : ""}`}
      onClick={handleCardClick}
      onKeyDown={handleCardKeyDown}
      role={isCardPressable ? "button" : undefined}
      tabIndex={isCardPressable ? 0 : undefined}
      aria-label={isCardPressable ? actionState.primaryLabel : undefined}
    >
      {showInvestedBadge ? (
        <div className="absolute top-0 left-0 right-0 z-20 bg-primary py-2 text-center text-sm font-bold tracking-wide text-primary-content rounded-t-2xl">
          💼 Invested
        </div>
      ) : isNewlyListed ? (
        <div className="absolute top-0 left-0 right-0 z-20 bg-success py-2 text-center text-sm font-bold tracking-wide text-success-content rounded-t-2xl">
          ✨ Newly Listed
        </div>
      ) : showSecondaryListingBadge ? (
        <div className="absolute top-0 left-0 right-0 z-20 bg-base-100/90 backdrop-blur-sm border-b border-base-300 py-2 text-center text-sm font-semibold tracking-wide text-base-content rounded-t-2xl">
          🔁 Secondary Listing
        </div>
      ) : null}

      {/* Image Section */}
      <figure className="relative h-48 bg-gradient-to-br from-base-200 to-base-300 overflow-hidden">
        {imageUrl ? (
          <Image
            src={imageUrl}
            alt={displayName}
            fill
            priority={priority}
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
          <span className="badge badge-success font-bold shadow-md text-xs">{apyDisplay} APY</span>
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
        <h3 className="card-title text-lg font-bold line-clamp-2 min-h-[3.5rem]" title={displayName}>
          {displayName}
        </h3>

        {/* Partner Name */}
        {partner && <span className="text-xs text-primary -mt-1">by {partner.name}</span>}

        {/* Stats Grid */}
        <div className="grid grid-cols-2 gap-3 py-2">
          <div className="flex flex-col">
            <span className="text-xs opacity-50 uppercase tracking-wide">Price/Token</span>
            <span className="font-bold text-lg">{priceDisplay}</span>
            <span className="text-xs opacity-50 -mt-0.5">{paymentSymbol}</span>
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

        {/* Earnings Row — always visible */}
        <div className="grid grid-cols-2 gap-3 py-2">
          {hasEarnings ? (
            <>
              <div className="flex flex-col">
                <span className="text-xs opacity-50 uppercase tracking-wide">Actual Earnings</span>
                <span className="font-semibold text-success">{actualEarningsDisplay}</span>
                <span className="text-xs opacity-50 -mt-0.5">{paymentSymbol}</span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs opacity-50 uppercase tracking-wide">Est. at Maturity</span>
                <span className="font-semibold text-success/70">{projectedEarnings.atMaturity}</span>
                <span className="text-xs opacity-50 -mt-0.5">{paymentSymbol}</span>
              </div>
            </>
          ) : (
            <>
              <div className="flex flex-col">
                <span className="text-xs opacity-50 uppercase tracking-wide">Est. / Year</span>
                <span className="font-semibold text-success/70">{projectedEarnings.perYear}</span>
                <span className="text-xs opacity-50 -mt-0.5">{paymentSymbol}</span>
              </div>
              <div className="flex flex-col">
                <span className="text-xs opacity-50 uppercase tracking-wide">Est. at Maturity</span>
                <span className="font-semibold text-success/70">{projectedEarnings.atMaturity}</span>
                <span className="text-xs opacity-50 -mt-0.5">{paymentSymbol}</span>
              </div>
            </>
          )}
        </div>

        {/* Action Button */}
        <div className="card-actions mt-2">
          {actionState.secondaryActions.length > 0 ? (
            <div ref={actionDropdownRef} className="relative w-full">
              <div className="flex w-full">
                <button
                  type="button"
                  className={`btn ${actionState.primaryClass} rounded-r-none flex-1`}
                  onClick={() => {
                    setIsActionMenuOpen(false);
                    actionState.primaryOnClick?.();
                  }}
                  disabled={actionState.primaryDisabled}
                >
                  {actionState.primaryLabel}
                </button>
                <button
                  type="button"
                  className={`btn ${actionState.primaryClass} rounded-l-none px-3`}
                  aria-expanded={isActionMenuOpen}
                  aria-haspopup="menu"
                  onClick={() => setIsActionMenuOpen(prev => !prev)}
                >
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
                </button>
              </div>
              {isActionMenuOpen && (
                <ul className="absolute bottom-full right-0 z-[60] menu p-2 shadow bg-base-100 rounded-box w-full mb-2">
                  {actionState.secondaryActions.map(action => (
                    <li key={action.label}>
                      <button
                        type="button"
                        onClick={() => {
                          setIsActionMenuOpen(false);
                          action.onClick?.();
                        }}
                        className={`w-full text-left ${action.className ?? ""}`}
                      >
                        {action.label}
                      </button>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          ) : (
            <button
              className={`btn ${actionState.primaryClass} btn-block`}
              onClick={actionState.primaryOnClick}
              disabled={actionState.primaryDisabled}
            >
              {actionState.primaryLabel}
            </button>
          )}
        </div>
      </div>
    </div>
  );
}
