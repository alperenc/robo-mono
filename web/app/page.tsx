"use client";

import { useEffect, useMemo } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useChainId, useChains, useSwitchChain } from "wagmi";
import { ArrowRightIcon } from "@heroicons/react/24/outline";
import { getSubgraphQueryUrl } from "~~/utils/subgraph";

const HomePage = () => {
  const router = useRouter();
  const chainId = useChainId();
  const chains = useChains();
  const { switchChain } = useSwitchChain();

  const supportedChains = useMemo(() => chains.filter(chain => !!getSubgraphQueryUrl(chain.id)), [chains]);
  const hasMarketsSupport = !!getSubgraphQueryUrl(chainId);

  useEffect(() => {
    if (hasMarketsSupport) {
      router.replace("/markets");
    }
  }, [hasMarketsSupport, router]);

  return (
    <div className="flex flex-1 items-center justify-center px-6 py-16">
      <div className="w-full max-w-2xl rounded-[2rem] border border-base-300 bg-base-100 p-8 shadow-xl shadow-base-300/40 sm:p-10">
        <div className="space-y-4">
          <p className="text-sm font-semibold uppercase tracking-[0.3em] text-base-content/50">Roboshare</p>
          <h1 className="text-4xl font-black tracking-tight text-base-content sm:text-5xl">Vehicle-backed markets.</h1>
          <p className="max-w-xl text-lg leading-relaxed text-base-content/70">
            The markets experience is available on supported Roboshare networks. This root page stays renderable for
            static export and unsupported wallet networks.
          </p>
        </div>

        <div className="mt-8 rounded-3xl border border-base-300 bg-base-200/60 p-5">
          <p className="text-sm font-semibold uppercase tracking-[0.24em] text-base-content/50">Current Network</p>
          <p className="mt-2 text-xl font-bold text-base-content">
            {chains.find(chain => chain.id === chainId)?.name ?? `Chain ${chainId}`}
          </p>
          <p className="mt-2 text-sm text-base-content/70">
            {hasMarketsSupport
              ? "Markets is supported here. You should be redirected automatically."
              : "Markets is not configured on this network yet. Switch to a supported network to continue."}
          </p>
        </div>

        <div className="mt-8 flex flex-col gap-3 sm:flex-row">
          <Link href={hasMarketsSupport ? "/markets" : "/partner"} className="btn btn-primary flex-1 rounded-full">
            {hasMarketsSupport ? "Open Markets" : "Open Dashboard"}
            <ArrowRightIcon className="h-4 w-4" />
          </Link>
        </div>

        {!hasMarketsSupport && supportedChains.length > 0 ? (
          <div className="mt-8">
            <p className="text-sm font-semibold uppercase tracking-[0.24em] text-base-content/50">Supported Networks</p>
            <div className="mt-3 flex flex-wrap gap-3">
              {supportedChains.map(chain => (
                <button
                  key={chain.id}
                  type="button"
                  className="btn btn-outline rounded-full"
                  onClick={() => switchChain({ chainId: chain.id })}
                >
                  {chain.name}
                </button>
              ))}
            </div>
          </div>
        ) : null}
      </div>
    </div>
  );
};

export default HomePage;
