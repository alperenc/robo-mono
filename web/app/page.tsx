"use client";

import { useEffect, useMemo } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { foundry } from "viem/chains";
import { useChainId, useChains, useSwitchChain } from "wagmi";
import {
  ArrowRightIcon,
  ArrowsRightLeftIcon,
  BuildingStorefrontIcon,
  CurrencyDollarIcon,
  UserGroupIcon,
} from "@heroicons/react/24/outline";
import { useSelectedNetwork } from "~~/hooks/scaffold-eth";
import { getSubgraphQueryUrl } from "~~/utils/subgraph";

const HomePage = () => {
  const router = useRouter();
  const walletChainId = useChainId();
  const selectedNetwork = useSelectedNetwork(walletChainId);
  const chains = useChains();
  const { switchChain } = useSwitchChain();

  const activeChain = chains.find(chain => chain.id === selectedNetwork.id) ?? selectedNetwork;
  const hasMarketsSupport = !!getSubgraphQueryUrl(selectedNetwork.id);
  const supportedChains = useMemo(
    () =>
      chains
        .filter(chain => chain.id !== foundry.id && !!getSubgraphQueryUrl(chain.id))
        .sort((left, right) => {
          if (left.id === selectedNetwork.id) return -1;
          if (right.id === selectedNetwork.id) return 1;
          return 0;
        }),
    [chains, selectedNetwork.id],
  );

  useEffect(() => {
    if (hasMarketsSupport) {
      router.replace("/markets");
    }
  }, [hasMarketsSupport, router]);

  return (
    <div className="flex flex-1 justify-center px-6 py-10 sm:py-14">
      <div className="w-full max-w-6xl space-y-8">
        <section className="overflow-hidden rounded-[2rem] border border-base-300 bg-base-100 shadow-xl shadow-base-300/40">
          <div className="grid gap-8 px-6 py-8 sm:px-8 sm:py-10 lg:grid-cols-[1.3fr_0.9fr] lg:px-10">
            <div className="space-y-6">
              <div className="space-y-3">
                <p className="text-sm font-semibold uppercase tracking-[0.3em] text-base-content/50">Roboshare</p>
                <h1 className="max-w-3xl text-4xl font-black tracking-tight text-base-content sm:text-5xl">
                  Asset-backed markets for investors and partners.
                </h1>
                <p className="max-w-2xl text-lg leading-relaxed text-base-content/70">
                  Browse live offerings, acquire claim units, collect payouts, and manage partner inventory from one
                  app. Sign in from the header to use an embedded wallet, or continue with your existing wallet.
                </p>
              </div>

              <div className="grid gap-3 sm:grid-cols-3">
                <div className="rounded-3xl border border-base-300 bg-base-200/60 p-4">
                  <BuildingStorefrontIcon className="h-6 w-6 text-primary" />
                  <div className="mt-3 text-sm font-semibold text-base-content">Explore offerings</div>
                  <p className="mt-1 text-sm text-base-content/70">
                    Primary pools and secondary listings are available from the Markets view.
                  </p>
                </div>
                <div className="rounded-3xl border border-base-300 bg-base-200/60 p-4">
                  <CurrencyDollarIcon className="h-6 w-6 text-primary" />
                  <div className="mt-3 text-sm font-semibold text-base-content">Claim payouts</div>
                  <p className="mt-1 text-sm text-base-content/70">
                    Holdings surface claimable earnings, settlement proceeds, and batch payout actions.
                  </p>
                </div>
                <div className="rounded-3xl border border-base-300 bg-base-200/60 p-4">
                  <UserGroupIcon className="h-6 w-6 text-primary" />
                  <div className="mt-3 text-sm font-semibold text-base-content">Run partner flows</div>
                  <p className="mt-1 text-sm text-base-content/70">
                    Authorized partners can register assets, launch pools, distribute earnings, and settle assets.
                  </p>
                </div>
              </div>

              <div className="flex flex-col gap-3 sm:flex-row">
                <Link href="/markets" className="btn btn-primary rounded-full sm:min-w-44">
                  Open Markets
                  <ArrowRightIcon className="h-4 w-4" />
                </Link>
                <Link href="/partner" className="btn btn-outline rounded-full sm:min-w-44">
                  Partner Dashboard
                </Link>
              </div>
            </div>

            <div className="rounded-[1.75rem] border border-base-300 bg-base-200/70 p-5 sm:p-6">
              <p className="text-sm font-semibold uppercase tracking-[0.24em] text-base-content/50">Environment</p>
              <div className="mt-4 space-y-4">
                <div>
                  <div className="text-xs font-semibold uppercase tracking-[0.2em] text-base-content/50">
                    Selected Network
                  </div>
                  <div className="mt-1 text-2xl font-bold text-base-content">{activeChain.name}</div>
                  <p className="mt-2 text-sm text-base-content/70">
                    {hasMarketsSupport
                      ? "Roboshare is configured on this network. The app should forward you to Markets automatically."
                      : "This network does not have a configured Roboshare subgraph yet. Switch to a supported network to continue."}
                  </p>
                </div>

                <div className="rounded-2xl border border-base-300 bg-base-100/80 p-4">
                  <div className="text-xs font-semibold uppercase tracking-[0.2em] text-base-content/50">
                    Current Focus
                  </div>
                  <p className="mt-2 text-sm leading-relaxed text-base-content/70">
                    The app is currently centered on testnet investor and partner flows. Mainnet routing and mainnet
                    subgraphs can be added later without changing the current navigation model.
                  </p>
                </div>

                {supportedChains.length > 0 ? (
                  <div>
                    <div className="text-xs font-semibold uppercase tracking-[0.2em] text-base-content/50">
                      Supported Networks
                    </div>
                    <div className="mt-3 flex flex-wrap gap-3">
                      {supportedChains.map(chain => (
                        <button
                          key={chain.id}
                          type="button"
                          className={`btn rounded-full ${
                            chain.id === selectedNetwork.id ? "btn-primary" : "btn-outline"
                          }`}
                          onClick={() => switchChain({ chainId: chain.id })}
                        >
                          <ArrowsRightLeftIcon className="h-4 w-4" />
                          {chain.name}
                        </button>
                      ))}
                    </div>
                  </div>
                ) : null}
              </div>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
};

export default HomePage;
