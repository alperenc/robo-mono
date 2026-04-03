"use client";

import { ReactNode } from "react";
import { Address } from "viem";
import { BlockieAvatar } from "~~/components/scaffold-eth";

type AccountIdentityCardProps = {
  address: Address;
  primaryLabel: string;
  secondaryLabel?: string;
  aside?: ReactNode;
  className?: string;
};

export const AccountIdentityCard = ({
  address,
  primaryLabel,
  secondaryLabel,
  aside,
  className = "",
}: AccountIdentityCardProps) => {
  return (
    <div
      className={`flex items-center justify-between gap-3 rounded-xl border border-base-300 bg-base-100 px-4 py-3 ${className}`}
    >
      <div className="flex min-w-0 items-center gap-3">
        <div className="shrink-0">
          <BlockieAvatar address={address} size={36} />
        </div>
        <div className="min-w-0">
          <div className="truncate text-sm font-semibold text-base-content">{primaryLabel}</div>
          {secondaryLabel ? <div className="text-xs text-base-content/60">{secondaryLabel}</div> : null}
        </div>
      </div>
      {aside ? <div className="shrink-0">{aside}</div> : null}
    </div>
  );
};
