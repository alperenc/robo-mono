"use client";

import { type KeyboardEvent, type MouseEvent, useEffect, useMemo, useRef, useState } from "react";
import Image from "next/image";
import { formatUnits } from "viem";
import { useAccount, useBlock } from "wagmi";
import { ASSET_REGISTRIES, AssetType } from "~~/config/assetTypes";
import { useScaffoldReadContract } from "~~/hooks/scaffold-eth";
import { usePaymentToken } from "~~/hooks/usePaymentToken";

const BP_PRECISION = 10000n;
const BENCHMARK_YIELD_BP = 1000n;
const DEPRECIATION_RATE_BP = 1200n;

interface ListingCardProps {
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
    isEnded?: boolean;
    endedAt?: string | null;
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
  viewMode?: "list" | "grid";
  hasUserListingForTokenId?: boolean;
  hasUserActiveListingForTokenId?: boolean;
  hasUserPrimaryListingForTokenId?: boolean;
  hasUserBoughtListing?: boolean;
  tokenTotalSoldAmount?: string;
  onBuyClick?: () => void;
  onClaimEarningsClick?: () => void;
  onClaimSettlementClick?: () => void;
  onListTokensClick?: (amount: string) => void;
  onEndListingClick?: () => void;
  onDistributeEarningsClick?: () => void;
  onSettleAssetClick?: () => void;
}

export function ListingCard({
  listing,
  vehicle,
  token,
  earnings,
  partner,
  imageUrl,
  networkName = "Localhost",
  assetType = AssetType.VEHICLE,
  priority,
  viewMode = "grid",
  hasUserActiveListingForTokenId = false,
  hasUserPrimaryListingForTokenId = false,
  hasUserBoughtListing = false,
  tokenTotalSoldAmount,
  onBuyClick,
  onClaimEarningsClick,
  onClaimSettlementClick,
  onListTokensClick,
  onEndListingClick,
  onDistributeEarningsClick,
  onSettleAssetClick,
}: ListingCardProps) {
  const { address } = useAccount();
  const { data: latestBlock } = useBlock({ watch: true });
  const { symbol: paymentSymbol, decimals: paymentDecimals } = usePaymentToken();
  const actionDropdownRef = useRef<HTMLDivElement>(null);
  const [isActionMenuOpen, setIsActionMenuOpen] = useState(false);
  const chainNowSec = latestBlock?.timestamp ? Number(latestBlock.timestamp) : Math.floor(Date.now() / 1000);

  const { data: primaryTokenEscrow } = useScaffoldReadContract({
    contractName: "Marketplace",
    functionName: "tokenEscrow",
    args: [BigInt(listing.tokenId)],
  });

  const { data: walletTokenBalance } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "balanceOf",
    args: [address, BigInt(listing.tokenId)],
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
  const hasAvailableTokens = BigInt(listing.amount) > 0n;
  const hasEarnings = Boolean(earnings && (earnings.distributionCount !== "0" || earnings.totalEarnings !== "0"));
  const canClaimEarnings = (previewClaimAmount || 0n) > 0n;
  const canClaimEarningsOnThisListing = canClaimEarnings && hasUserBoughtListing;
  const hasHoldings = (walletTokenBalance || 0n) > 0n;
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
    return listingSoldAmount;
  }, [tokenTotalSoldAmount, listingSoldAmount]);

  const listingActualEarnings = useMemo(() => {
    if (!earnings || earnings.totalEarnings === "0") return 0n;
    if (listingSoldAmount <= 0n || soldSupplyForAllocation <= 0n) return 0n;
    return (BigInt(earnings.totalEarnings) * listingSoldAmount) / soldSupplyForAllocation;
  }, [earnings, listingSoldAmount, soldSupplyForAllocation]);

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
      return `${(Number(BENCHMARK_YIELD_BP) / 100).toFixed(2)}%`;
    }

    const tokenPrice = BigInt(token.price);
    const principalAmount = listingSoldAmount > 0n ? listingSoldAmount : BigInt(listing.amount);
    const totalValue = tokenPrice * principalAmount;

    if (earnings && listingActualEarnings > 0n && totalValue > 0n) {
      // Annualize realized returns only when listing end timestamp is available.
      // Otherwise fallback to target yield APY instead of using inaccurate timing guesses.
      const listingEndedAtOnChain = BigInt(listing.endedAt || "0");
      const lastDistAt = BigInt(earnings.lastDistributionAt || "0");
      const duration =
        listingEndedAtOnChain > 0n && lastDistAt > listingEndedAtOnChain ? lastDistAt - listingEndedAtOnChain : 0n;

      if (duration > 0n) {
        const secondsPerYear = 365n * 24n * 60n * 60n;
        const annualizedEarnings = (listingActualEarnings * secondsPerYear) / duration;
        const aprBps = (annualizedEarnings * BP_PRECISION) / totalValue;
        const aprPercent = Number(aprBps) / 100;
        return `${aprPercent.toFixed(2)}%`;
      }
    }

    // Fallback to target yield APY (or benchmark if unavailable)
    const targetYieldBps = token.targetYieldBP ? Number(token.targetYieldBP) : Number(BENCHMARK_YIELD_BP);
    const targetYieldPercent = targetYieldBps / 100;
    return `${targetYieldPercent.toFixed(2)}%`;
  }, [token, earnings, listing.amount, listing.endedAt, listingActualEarnings, listingSoldAmount]);

  // Format listing-scoped actual earnings (numeric value only — symbol rendered separately)
  const actualEarningsDisplay = useMemo(() => {
    if (listingActualEarnings === 0n) return "0.00";
    const amount = formatUnits(listingActualEarnings, paymentDecimals);
    return Number(amount).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }, [listingActualEarnings, paymentDecimals]);

  // Calculate projected earnings (per year and at maturity)
  const projectedEarnings = useMemo(() => {
    if (!token) return { perYear: "—", atMaturity: "—" };
    const tokenPrice = BigInt(token.price);
    const listingAmountForProjection =
      listing.isEnded || !hasAvailableTokens ? listingSoldAmount : BigInt(listing.amount);
    const totalValue = tokenPrice * listingAmountForProjection; // listing-specific value basis for projections
    if (totalValue === 0n) {
      return { perYear: "0.00", atMaturity: "0.00" };
    }
    const targetYieldBps = token.targetYieldBP ? BigInt(token.targetYieldBP) : BENCHMARK_YIELD_BP;

    // earnings per year = totalValue * targetYieldBP / 10000
    const earningsPerYear = (totalValue * targetYieldBps) / BP_PRECISION;
    const perYearFormatted = Number(formatUnits(earningsPerYear, paymentDecimals)).toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });

    // earnings at maturity = earningsPerYear * yearsToMaturity
    const maturitySec = Number(token.maturityDate);
    const nowSec = chainNowSec;
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
      (totalValue * DEPRECIATION_RATE_BP * BigInt(Math.round(yearsRemaining * 1000))) / (BP_PRECISION * 1000n);
    const recoverableBase = totalValue > depreciationAmount ? totalValue - depreciationAmount : 0n;

    const atMaturityTotal = recoverableBase + projectedTotalEarnings;
    const atMaturityFormatted = Number(formatUnits(atMaturityTotal, paymentDecimals)).toLocaleString(undefined, {
      minimumFractionDigits: 2,
      maximumFractionDigits: 2,
    });

    return { perYear: perYearFormatted, atMaturity: atMaturityFormatted };
  }, [token, listing.amount, listing.isEnded, hasAvailableTokens, listingSoldAmount, paymentDecimals, chainNowSec]);

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

    const displayAvailableNum = listing.isEnded ? 0 : availableNum;
    const soldNum = historicalSoldNum;
    const totalNum = listing.isEnded ? availableNum + historicalSoldNum : availableNum + soldNum;
    const soldPercentage = totalNum > 0 ? Math.round((soldNum / totalNum) * 100) : 0;
    return {
      available: formatCompact(displayAvailableNum),
      total: formatCompact(totalNum),
      soldPercentage,
    };
  }, [listing.amount, listing.amountSold, listing.isEnded, token]);

  // Check statuses
  const isExpired = useMemo(() => {
    return Number(listing.expiresAt) * 1000 < Date.now();
  }, [listing.expiresAt]);

  const isEnded = listing.isEnded;
  const isInactive = isEnded || isExpired;
  const isTokenMatured = token ? Number(token.maturityDate) <= chainNowSec : false;
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
  const isNewlyListed = hasAvailableTokens && !isEnded && (!earnings || earnings.distributionCount === "0");
  const isSellerOfListing = Boolean(address && listing.seller.toLowerCase() === address.toLowerCase());
  const isSecondaryListing = true;
  const showSecondaryListingBadge = !isInactive;
  // Primary sellers should not list wallet tokens; only secondary sellers can.
  const canListWalletTokens = !hasUserPrimaryListingForTokenId;
  // For primary sellers, relistable inventory is pooled in Marketplace tokenEscrow(tokenId),
  // not per-listing amount.
  const primarySellerInactiveEscrowAmount =
    isSellerOfListing && !isSecondaryListing && isInactive ? primaryTokenEscrow || 0n : 0n;
  const walletListableAmount = canListWalletTokens ? walletTokenBalance || 0n : 0n;
  const listableTokensAmount =
    isSellerOfListing && !isSecondaryListing ? primarySellerInactiveEscrowAmount : walletListableAmount;
  const canListTokens = listableTokensAmount > 0n;

  const registry = ASSET_REGISTRIES[assetType];
  const showInvestedBadge = !isSellerOfListing && ((walletTokenBalance || 0n) > 0n || hasUserBoughtListing);
  const actionState = useMemo(() => {
    type CandidateAction = { label: string; onClick?: () => void; className?: string };

    const listTokensLabel = hasUserActiveListingForTokenId || isSellerOfListing ? "List More Tokens" : "List Tokens";
    const hasClaimedTokens = (walletTokenBalance || 0n) > 0n;
    const canManageOwnListing = isSellerOfListing && !isInactive;
    const canRelistInactiveOwnPrimaryListing = isSellerOfListing && !isSecondaryListing && isInactive && canListTokens;

    const sellerManagementActions: CandidateAction[] = [];
    const primarySellerLifecycleActions: CandidateAction[] = [];
    const actionCandidates: CandidateAction[] = [];

    const successGhostClass = "btn-success bg-success/15 border-0 text-success hover:bg-success/25";
    const primaryGhostClass =
      "btn-primary bg-primary/10 text-primary border border-primary/20 hover:bg-primary/15 dark:bg-white/15 dark:text-white dark:border-white/20 dark:hover:bg-white/25";

    const pushAction = (action: CandidateAction) => {
      if (!action.onClick) return;
      actionCandidates.push(action);
    };

    const resolvePrimaryClass = (action: CandidateAction): string => {
      if (action.label === "Settle Asset") return isTokenMatured ? primaryGhostClass : "btn-error";
      if (action.label === "Claim Settlement") return successGhostClass;
      if (
        action.label === "Distribute Earnings" ||
        action.label === "Claim Earnings" ||
        action.label === "Claim Tokens"
      ) {
        return successGhostClass;
      }
      if (
        action.label === "List Tokens" ||
        action.label === "List More Tokens" ||
        action.label === "End Listing" ||
        action.label === "Buy Tokens"
      ) {
        return primaryGhostClass;
      }
      return action.className || "btn-primary";
    };

    if (isSellerOfListing && !isSecondaryListing && !isAssetSettled) {
      if (isTokenMatured && onSettleAssetClick) {
        primarySellerLifecycleActions.push({
          label: "Settle Asset",
          onClick: onSettleAssetClick,
        });
      }
      if (onDistributeEarningsClick && listingSoldAmount > 0n) {
        primarySellerLifecycleActions.push({
          label: "Distribute Earnings",
          onClick: onDistributeEarningsClick,
        });
      }
      if (!isTokenMatured && onSettleAssetClick) {
        primarySellerLifecycleActions.push({
          label: "Settle Asset",
          onClick: onSettleAssetClick,
          className: isTokenMatured ? undefined : "text-error",
        });
      }
    }

    if (canManageOwnListing) {
      if (isSecondaryListing) {
        if (onEndListingClick) sellerManagementActions.push({ label: "End Listing", onClick: onEndListingClick });
        if (canListTokens) {
          sellerManagementActions.push({
            label: listTokensLabel,
            onClick: () => onListTokensClick?.(listableTokensAmount.toString()),
          });
        }
      } else {
        if (onEndListingClick) sellerManagementActions.push({ label: "End Listing", onClick: onEndListingClick });
      }
    }

    if (canRelistInactiveOwnPrimaryListing) {
      pushAction({
        label: listTokensLabel,
        onClick: () => onListTokensClick?.(listableTokensAmount.toString()),
      });
      primarySellerLifecycleActions.forEach(pushAction);
    } else if (isSellerOfListing && !isSecondaryListing && isInactive && primarySellerLifecycleActions.length > 0) {
      primarySellerLifecycleActions.forEach(pushAction);
    } else if (sellerManagementActions.length > 0) {
      sellerManagementActions.forEach(pushAction);
    } else if (canClaimEarningsOnThisListing) {
      pushAction({ label: "Claim Earnings", onClick: onClaimEarningsClick });
      if (canClaimSettlement) {
        pushAction({ label: "Claim Settlement", onClick: onClaimSettlementClick });
      } else if (canListTokens) {
        pushAction({
          label: listTokensLabel,
          onClick: () => onListTokensClick?.(listableTokensAmount.toString()),
        });
      }
    } else if (!isSellerOfListing && !isInactive) {
      if (hasAvailableTokens) {
        pushAction({ label: "Buy Tokens", onClick: onBuyClick });
      }
      if (canListTokens) {
        pushAction({
          label: listTokensLabel,
          onClick: () => onListTokensClick?.(listableTokensAmount.toString()),
        });
      }
    } else if (hasClaimedTokens) {
      if (canClaimSettlement) {
        pushAction({ label: "Claim Settlement", onClick: onClaimSettlementClick });
      } else {
        pushAction({
          label: listTokensLabel,
          onClick: () => onListTokensClick?.(listableTokensAmount.toString()),
        });
      }
    }

    const primaryAction = actionCandidates[0];
    if (primaryAction) {
      return {
        primaryLabel: primaryAction.label,
        primaryClass: resolvePrimaryClass(primaryAction),
        primaryDisabled: false,
        primaryOnClick: primaryAction.onClick,
        secondaryActions: actionCandidates.slice(1),
      };
    }

    const defaultLabel =
      !isSellerOfListing && !isInactive && !hasAvailableTokens
        ? soldOutDurationLabel || "Sold Out"
        : isEnded
          ? "Ended"
          : isExpired
            ? "Expired"
            : "Buy Tokens";
    return {
      primaryLabel: defaultLabel,
      primaryClass: defaultLabel === "Buy Tokens" ? primaryGhostClass : "btn-primary",
      primaryDisabled: true,
      primaryOnClick: undefined,
      secondaryActions: [],
    };
  }, [
    canClaimSettlement,
    canClaimEarningsOnThisListing,
    hasAvailableTokens,
    soldOutDurationLabel,
    hasUserActiveListingForTokenId,
    listingSoldAmount,
    isTokenMatured,
    isEnded,
    isExpired,
    isInactive,
    isAssetSettled,
    isSecondaryListing,
    isSellerOfListing,
    listableTokensAmount,
    canListTokens,
    onBuyClick,
    onDistributeEarningsClick,
    onClaimEarningsClick,
    onClaimSettlementClick,
    onEndListingClick,
    onListTokensClick,
    onSettleAssetClick,
    walletTokenBalance,
  ]);

  const isCardPressable = Boolean(actionState.primaryOnClick) && !actionState.primaryDisabled;
  const hasAvailableActions = isCardPressable || actionState.secondaryActions.some(action => Boolean(action.onClick));
  const primaryButtonClass = actionState.primaryDisabled
    ? `${actionState.primaryClass} !bg-base-200 !text-base-content/45 !border-base-300 !shadow-none opacity-100`
    : actionState.primaryClass;
  const isListMode = viewMode === "list";
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

  if (isListMode) {
    return (
      <div
        className={`rounded-2xl border border-base-300 bg-base-100 shadow-sm transition-all duration-200 ${
          hasAvailableActions ? "hover:shadow-md" : "opacity-70 saturate-50"
        } ${isCardPressable ? "cursor-pointer" : ""}`}
        onClick={handleCardClick}
        onKeyDown={handleCardKeyDown}
        role={isCardPressable ? "button" : undefined}
        tabIndex={isCardPressable ? 0 : undefined}
        aria-label={isCardPressable ? actionState.primaryLabel : undefined}
      >
        <div className="p-3 sm:p-4">
          <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:gap-4">
            <div className="flex min-w-0 items-center gap-3 lg:w-[30%]">
              <div className="relative h-14 w-14 shrink-0 overflow-hidden rounded-lg bg-base-200">
                {imageUrl ? (
                  <Image src={imageUrl} alt={displayName} fill className="object-cover" unoptimized />
                ) : (
                  <div className="flex h-full w-full items-center justify-center">
                    <span className="text-xl opacity-40">{registry.icon}</span>
                  </div>
                )}
              </div>
              <div className="min-w-0">
                <div className="mb-0.5 flex flex-wrap items-center gap-1.5">
                  <span className="text-[10px] font-semibold uppercase tracking-wide opacity-50">{assetType}</span>
                  {showInvestedBadge && <span className="badge badge-xs badge-primary">💼 Invested</span>}
                  {isNewlyListed && <span className="badge badge-xs badge-success">✨ New</span>}
                  {showSecondaryListingBadge && <span className="badge badge-xs">🔁 Secondary</span>}
                  {(isEnded || isExpired) && (
                    <span className={`badge badge-xs ${isExpired ? "badge-warning" : "badge-neutral"}`}>
                      {isExpired ? "Expired" : "Ended"}
                    </span>
                  )}
                </div>
                <div className="line-clamp-2 break-words text-base font-bold leading-tight" title={displayName}>
                  {displayName}
                </div>
                {partner && <div className="truncate text-xs text-primary/80">by {partner.name}</div>}
              </div>
            </div>

            <div className="grid flex-1 grid-cols-2 gap-x-4 gap-y-2 text-sm sm:grid-cols-4 lg:w-[50%]">
              <div>
                <div className="text-[10px] uppercase tracking-wide opacity-50">Price</div>
                <div className="font-semibold leading-tight">{priceDisplay}</div>
                <div className="text-[11px] opacity-60">{paymentSymbol}</div>
              </div>
              <div>
                <div className="text-[10px] uppercase tracking-wide opacity-50">Available</div>
                <div className="font-semibold leading-tight">
                  {availableTokensDisplay.available}
                  <span className="opacity-50"> / {availableTokensDisplay.total}</span>
                </div>
              </div>
              <div>
                <div className="text-[10px] uppercase tracking-wide opacity-50">Sold</div>
                <div className="font-semibold leading-tight">{availableTokensDisplay.soldPercentage}%</div>
              </div>
              <div>
                <div className="text-[10px] uppercase tracking-wide opacity-50">APY</div>
                <div className="font-semibold leading-tight text-success">{apyDisplay}</div>
              </div>
              <div className="col-span-2 sm:col-span-4">
                <progress
                  className="progress h-1.5 w-full progress-primary"
                  value={availableTokensDisplay.soldPercentage}
                  max="100"
                ></progress>
              </div>
            </div>

            <div className="w-full lg:w-[220px]">
              {actionState.secondaryActions.length > 0 ? (
                <div ref={actionDropdownRef} className="dropdown dropdown-end w-full">
                  <div className="flex w-full">
                    <button
                      type="button"
                      className={`btn ${primaryButtonClass} rounded-r-none flex-1`}
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
                      className={`btn ${primaryButtonClass} rounded-l-none px-2 border-l border-current/15`}
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
                        className="h-4 w-4"
                      >
                        <path strokeLinecap="round" strokeLinejoin="round" d="m19.5 8.25-7.5 7.5-7.5-7.5" />
                      </svg>
                    </button>
                  </div>
                  {isActionMenuOpen && (
                    <ul className="dropdown-content z-[50] menu p-2 shadow bg-base-100 rounded-box w-52 mt-2">
                      {actionState.secondaryActions.map(action => (
                        <li key={action.label}>
                          <button
                            type="button"
                            onClick={() => {
                              setIsActionMenuOpen(false);
                              action.onClick?.();
                            }}
                            className={action.className ?? ""}
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
                  className={`btn ${primaryButtonClass} w-full`}
                  onClick={actionState.primaryOnClick}
                  disabled={actionState.primaryDisabled}
                >
                  {actionState.primaryLabel}
                </button>
              )}
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div
      className={`card h-full bg-base-100 shadow-lg transition-all duration-300 overflow-hidden group ${
        hasAvailableActions ? "hover:shadow-xl" : "opacity-70 saturate-50"
      } ${
        isCardPressable ? "cursor-pointer hover:-translate-y-1 active:translate-y-0 active:scale-[0.995]" : ""
      } ${isListMode ? "sm:flex sm:flex-row sm:min-h-[18rem]" : ""}`}
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
      <figure
        className={`relative bg-gradient-to-br from-base-200 to-base-300 overflow-hidden ${
          isListMode ? "h-44 sm:h-auto sm:w-64 md:w-72" : "h-48"
        }`}
      >
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
        {isEnded && !hasAvailableActions && (
          <div className="absolute inset-0 bg-base-300/80 flex items-center justify-center z-10">
            <span className="badge badge-neutral badge-lg font-bold shadow-lg">SALE ENDED</span>
          </div>
        )}
        {isExpired && !isEnded && !hasAvailableActions && (
          <div className="absolute inset-0 bg-warning/80 flex items-center justify-center z-10">
            <span className="badge badge-warning badge-lg font-bold shadow-lg">EXPIRED</span>
          </div>
        )}
      </figure>

      {/* Content Section */}
      <div className={`card-body gap-2 flex-1 ${isListMode ? "p-5 sm:py-4 sm:px-5" : "p-4"}`}>
        {/* Asset Type */}
        <span className="text-xs font-semibold uppercase tracking-wider opacity-50">{assetType}</span>

        {/* Asset Name */}
        <h3
          className={`card-title text-lg font-bold line-clamp-2 ${isListMode ? "" : "min-h-[3.5rem]"}`}
          title={displayName}
        >
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
            className="progress w-full h-2 progress-primary"
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
            <div ref={actionDropdownRef} className="dropdown dropdown-end w-full">
              <div className="flex w-full">
                <button
                  type="button"
                  className={`btn ${primaryButtonClass} rounded-r-none flex-1`}
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
                  className={`btn ${primaryButtonClass} rounded-l-none px-3 border-l border-current/15`}
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
                <ul className="dropdown-content z-[50] menu p-2 shadow bg-base-100 rounded-box w-52 mb-2 bottom-full">
                  {actionState.secondaryActions.map(action => (
                    <li key={action.label}>
                      <button
                        type="button"
                        onClick={() => {
                          setIsActionMenuOpen(false);
                          action.onClick?.();
                        }}
                        className={action.className ?? ""}
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
              className={`btn ${primaryButtonClass} btn-block`}
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
