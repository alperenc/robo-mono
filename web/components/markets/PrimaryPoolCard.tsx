"use client";

import { useEffect, useRef, useState } from "react";
import { formatUnits } from "viem";
import { usePaymentToken } from "~~/hooks/usePaymentToken";

interface PrimaryPoolCardProps {
  pool: {
    id: string;
    tokenId: string;
    assetId: string;
    partner: string;
    pricePerToken: string;
    maxSupply: string;
    immediateProceeds: boolean;
    protectionEnabled: boolean;
    isPaused: boolean;
    isClosed: boolean;
    createdAt: string;
  };
  vehicle?: {
    id: string;
    make?: string;
    model?: string;
    year?: string;
    vin?: string;
  };
  token?: {
    price: string;
    supply: string;
    maturityDate: string;
    targetYieldBP?: string;
  };
  partner?: {
    name: string;
    address: string;
  };
  imageUrl?: string;
  viewMode?: "list" | "grid";
  primaryActionLabel: string;
  primaryActionDisabled?: boolean;
  primaryActionOnClick?: () => void;
  secondaryActions?: { label: string; onClick?: () => void }[];
  showNewPoolBadge?: boolean;
}

export function PrimaryPoolCard({
  pool,
  vehicle,
  token,
  partner,
  imageUrl,
  viewMode = "grid",
  primaryActionLabel,
  primaryActionDisabled = false,
  primaryActionOnClick,
  secondaryActions = [],
  showNewPoolBadge = false,
}: PrimaryPoolCardProps) {
  const { symbol, decimals } = usePaymentToken();
  const actionDropdownRef = useRef<HTMLDivElement>(null);
  const [isActionMenuOpen, setIsActionMenuOpen] = useState(false);
  const displayName =
    vehicle?.make && vehicle?.model && vehicle?.year
      ? `${vehicle.year} ${vehicle.make} ${vehicle.model}`
      : vehicle?.vin || `Asset #${pool.assetId}`;

  const currentSupply = token?.supply ? BigInt(token.supply) : 0n;
  const maxSupply = BigInt(pool.maxSupply);
  const remainingSupply = maxSupply > currentSupply ? maxSupply - currentSupply : 0n;
  const priceDisplay = Number(formatUnits(BigInt(pool.pricePerToken), decimals)).toLocaleString(undefined, {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
  const yieldDisplay = token?.targetYieldBP ? `${(Number(token.targetYieldBP) / 100).toFixed(2)}%` : "—";
  const statusLabel = pool.isClosed ? "Closed" : pool.isPaused ? "Paused" : "Open";
  const statusClass = pool.isClosed
    ? "bg-base-300 text-base-content/70"
    : pool.isPaused
      ? "bg-warning/15 text-warning"
      : "bg-success/15 text-success";
  const benefitLabel = pool.immediateProceeds ? "Higher Upside" : "Early Liquidity";
  const benefitClass = pool.immediateProceeds
    ? "rounded-full bg-primary/10 px-3 py-1 text-xs font-semibold text-primary dark:text-base-content"
    : "rounded-full bg-primary/10 px-3 py-1 text-xs font-semibold text-primary dark:text-base-content";
  const protectionClass = pool.protectionEnabled
    ? "rounded-full bg-primary/10 px-3 py-1 text-xs font-semibold text-primary dark:text-base-content"
    : "rounded-full bg-base-200 px-3 py-1 text-xs font-semibold text-base-content/70";
  const circulatingDisplay = currentSupply === 0n ? "--" : `${currentSupply.toLocaleString()} tokens`;
  const allocatedPercentage = maxSupply > 0n ? Number((currentSupply * 100n) / maxSupply) : 0;
  const isListMode = viewMode === "list";
  const hasSecondaryActions = secondaryActions.some(action => Boolean(action.onClick));
  const enabledPrimaryButtonClass = "btn btn-primary bg-primary/15 border-0 text-primary hover:bg-primary/25";
  const enabledSuccessButtonClass = "btn btn-success bg-success/15 border-0 text-success hover:bg-success/25";
  const disabledPrimaryButtonClass =
    "btn btn-ghost border border-base-300 bg-base-200 text-base-content/45 hover:border-base-300 hover:bg-base-200 dark:border-base-300 dark:bg-base-200 dark:text-base-content/45";
  const isSuccessPrimary = primaryActionLabel === "Claim Earnings" || primaryActionLabel === "Claim Settlement";
  const activePrimaryButtonClass = isSuccessPrimary ? enabledSuccessButtonClass : enabledPrimaryButtonClass;

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

  const renderActionButton = (menuPlacement: "top" | "bottom") => {
    if (!hasSecondaryActions) {
      return (
        <button
          className={`${primaryActionDisabled ? disabledPrimaryButtonClass : activePrimaryButtonClass} w-full shadow-none`}
          onClick={primaryActionOnClick}
          disabled={primaryActionDisabled}
        >
          {primaryActionLabel}
        </button>
      );
    }

    return (
      <div ref={actionDropdownRef} className="dropdown dropdown-end w-full">
        <div className="flex w-full">
          <button
            type="button"
            className={`${
              primaryActionDisabled ? disabledPrimaryButtonClass : activePrimaryButtonClass
            } rounded-r-none flex-1 shadow-none`}
            onClick={() => {
              setIsActionMenuOpen(false);
              primaryActionOnClick?.();
            }}
            disabled={primaryActionDisabled}
          >
            {primaryActionLabel}
          </button>
          <button
            type="button"
            className={`${activePrimaryButtonClass} rounded-l-none px-2 border-l border-current/15 shadow-none`}
            aria-expanded={isActionMenuOpen}
            aria-haspopup="menu"
            onClick={() => setIsActionMenuOpen(prev => !prev)}
            disabled={primaryActionDisabled && !hasSecondaryActions}
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              strokeWidth="1.5"
              stroke="currentColor"
              aria-hidden="true"
              className="h-4 w-4"
            >
              <path strokeLinecap="round" strokeLinejoin="round" d="m19.5 8.25-7.5 7.5-7.5-7.5" />
            </svg>
          </button>
        </div>
        {isActionMenuOpen && (
          <ul
            className={`dropdown-content z-[50] menu p-2 shadow bg-base-100 rounded-box w-52 ${
              menuPlacement === "top" ? "mb-2 bottom-full" : "mt-2"
            }`}
          >
            {secondaryActions.map(action => (
              <li key={action.label}>
                <button
                  type="button"
                  onClick={() => {
                    setIsActionMenuOpen(false);
                    action.onClick?.();
                  }}
                >
                  {action.label}
                </button>
              </li>
            ))}
          </ul>
        )}
      </div>
    );
  };

  if (isListMode) {
    return (
      <article className="overflow-hidden rounded-2xl border border-base-300 bg-base-100 shadow-sm">
        <div className="flex flex-col lg:flex-row">
          <div className="relative h-40 shrink-0 overflow-hidden bg-base-200 lg:h-auto lg:w-60 xl:w-72">
            {imageUrl ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={imageUrl} alt={displayName} className="h-full w-full object-cover" />
            ) : (
              <div className="flex h-full w-full items-center justify-center text-base-content/40 text-sm">
                No Image
              </div>
            )}
            {showNewPoolBadge && (
              <div className="absolute left-[-3.5rem] top-4 rotate-[-35deg] bg-success px-16 py-1 text-[10px] font-bold uppercase tracking-[0.18em] text-success-content shadow-md">
                New Pool
              </div>
            )}
            <div className="absolute inset-x-4 bottom-4 flex items-end justify-end">
              <span className="rounded-full bg-base-100/90 px-3 py-1 text-xs font-bold text-success shadow-md backdrop-blur-sm">
                {yieldDisplay} APY
              </span>
            </div>
          </div>

          <div className="flex flex-1 flex-col gap-3 p-4 sm:p-5">
            <div className="flex min-w-0 flex-col gap-3 lg:flex-row lg:items-center lg:gap-4">
              <div className="min-w-0 lg:w-[32%]">
                <div className="min-h-[4rem]">
                  <div className="line-clamp-2 break-words text-lg font-bold leading-tight" title={displayName}>
                    {displayName}
                  </div>
                  <div className="mt-1 flex flex-wrap items-center gap-2">
                    <span className="truncate text-sm text-base-content/60">
                      {partner?.name || partner?.address || pool.partner}
                    </span>
                    <span className={`rounded-full px-2 py-0.5 text-[10px] font-semibold ${statusClass}`}>
                      {statusLabel}
                    </span>
                  </div>
                </div>
                <div className="mt-2 flex min-h-[4.5rem] flex-wrap content-start items-start gap-2">
                  <span className={benefitClass}>{benefitLabel}</span>
                  <span className={protectionClass}>
                    {pool.protectionEnabled ? "Protection Enabled" : "No Protection"}
                  </span>
                </div>
              </div>

              <div className="grid flex-1 grid-cols-2 gap-x-4 gap-y-2 text-sm sm:grid-cols-3 lg:w-[42%]">
                <div>
                  <div className="text-[10px] uppercase tracking-wide opacity-50">Circulating</div>
                  <div className="font-semibold leading-tight">
                    {currentSupply === 0n ? "--" : currentSupply.toLocaleString()}
                  </div>
                  <div className="text-[11px] opacity-60">tokens</div>
                </div>
                <div>
                  <div className="text-[10px] uppercase tracking-wide opacity-50">Available</div>
                  <div className="font-semibold leading-tight">{remainingSupply.toLocaleString()}</div>
                  <div className="text-[11px] opacity-60">tokens</div>
                </div>
                <div>
                  <div className="text-[10px] uppercase tracking-wide opacity-50">Price</div>
                  <div className="font-semibold leading-tight">{priceDisplay}</div>
                  <div className="text-[11px] opacity-60">{symbol}</div>
                </div>
                <div className="col-span-2 sm:col-span-3">
                  <div className="mb-1 flex justify-between text-[10px] uppercase tracking-wide opacity-50">
                    <span>Allocated</span>
                    <span className="font-semibold opacity-100">{allocatedPercentage}%</span>
                  </div>
                  <progress
                    className="progress h-1.5 w-full progress-primary"
                    value={allocatedPercentage}
                    max="100"
                  ></progress>
                </div>
              </div>

              <div className="w-full lg:w-[220px]">
                {renderActionButton("bottom")}
                <div className="mt-2 text-center text-xs text-base-content/60">
                  Max supply {maxSupply.toLocaleString()} tokens
                </div>
              </div>
            </div>
          </div>
        </div>
      </article>
    );
  }

  return (
    <article className="rounded-2xl border border-base-300 bg-base-100 shadow-sm overflow-hidden flex flex-col">
      <div className="relative aspect-[16/10] bg-base-200">
        {imageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img src={imageUrl} alt={displayName} className="w-full h-full object-cover" />
        ) : (
          <div className="w-full h-full flex items-center justify-center text-base-content/40 text-sm">No Image</div>
        )}
        {showNewPoolBadge && (
          <div className="absolute inset-x-0 top-0 flex items-center justify-center bg-success text-success-content px-4 py-2 text-xs font-bold tracking-wide shadow-md">
            ✨ New Pool
          </div>
        )}
        <div className="absolute inset-x-4 bottom-4 flex items-end justify-end gap-3">
          <span className="rounded-full bg-base-100/90 px-3 py-1 text-xs font-bold text-success shadow-md backdrop-blur-sm">
            {yieldDisplay} APY
          </span>
        </div>
      </div>

      <div className="grid flex-1 grid-rows-[5.5rem_2rem_auto_auto_auto] gap-4 p-5">
        <div className="grid grid-cols-[minmax(0,1fr)_auto] grid-rows-[auto_auto] items-start gap-x-3 gap-y-1">
          <h3 className="line-clamp-2 text-xl font-bold leading-tight" title={displayName}>
            {displayName}
          </h3>
          <span
            className={`row-span-2 rounded-full px-3 py-1 text-xs font-semibold shrink-0 self-start ${statusClass}`}
          >
            {statusLabel}
          </span>
          <p
            className="truncate text-sm text-base-content/60"
            title={partner?.name || partner?.address || pool.partner}
          >
            {partner?.name || partner?.address || pool.partner}
          </p>
        </div>

        <div className="flex flex-wrap content-start gap-2">
          <span className={benefitClass}>{benefitLabel}</span>
          <span className={protectionClass}>{pool.protectionEnabled ? "Protection Enabled" : "No Protection"}</span>
        </div>

        <div className="rounded-xl bg-base-200 p-4">
          <div className="flex items-end justify-between gap-3">
            <div>
              <div className="text-xs uppercase tracking-wide opacity-50">Circulating</div>
              <div className="mt-1 text-lg font-bold">{circulatingDisplay}</div>
            </div>
            <div className="text-right">
              <div className="text-xs uppercase tracking-wide opacity-50">Allocated</div>
              <div className="mt-1 font-semibold">{allocatedPercentage}%</div>
            </div>
          </div>
          <progress
            className="progress w-full h-2 progress-primary mt-3"
            value={allocatedPercentage}
            max="100"
          ></progress>
        </div>

        <div className="grid grid-cols-2 gap-3 text-sm">
          <div className="rounded-xl bg-base-200 p-3">
            <div className="text-base-content/60">Available</div>
            <div className="mt-1 text-2xl font-bold leading-none">{remainingSupply.toLocaleString()}</div>
            <div className="mt-1 text-base-content/70 font-semibold">tokens</div>
          </div>
          <div className="rounded-xl bg-base-200 p-3">
            <div className="text-base-content/60">Price</div>
            <div className="mt-1 text-2xl font-bold leading-none">{priceDisplay}</div>
            <div className="mt-1 text-base-content/70 font-semibold">{symbol}</div>
          </div>
        </div>

        <div className="flex flex-col gap-2 self-end">
          <div className="w-full">{renderActionButton("top")}</div>
          <div className="text-center text-xs text-base-content/60">Max supply {maxSupply.toLocaleString()} tokens</div>
        </div>
      </div>
    </article>
  );
}
