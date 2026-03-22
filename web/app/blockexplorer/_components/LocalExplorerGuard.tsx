"use client";

import Link from "next/link";
import { hardhat } from "viem/chains";
import { useTargetNetwork } from "~~/hooks/scaffold-eth/useTargetNetwork";

export const LocalExplorerGuard = ({ children }: { children: React.ReactNode }) => {
  const { targetNetwork } = useTargetNetwork();
  const isLocalNetwork = targetNetwork.id === hardhat.id;

  if (isLocalNetwork) {
    return <>{children}</>;
  }

  return (
    <div className="container mx-auto my-16 px-4">
      <div className="max-w-2xl mx-auto rounded-3xl border border-base-300 bg-base-100 p-8 shadow-lg">
        <h1 className="text-3xl font-bold mb-4">Local Explorer Only</h1>
        <p className="text-base-content/70 mb-6">
          These in-app explorer routes are only available for the local Foundry chain. On testnets, use the selected
          network&apos;s external explorer instead.
        </p>
        <Link
          href={targetNetwork.blockExplorers?.default?.url || "#"}
          target="_blank"
          rel="noopener noreferrer"
          className="btn btn-primary"
        >
          Open {targetNetwork.blockExplorers?.default?.name || `${targetNetwork.name} Explorer`}
        </Link>
      </div>
    </div>
  );
};
