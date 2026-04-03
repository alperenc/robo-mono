"use client";

import Link from "next/link";
import { PaginationButton, SearchBar, TransactionsTable } from "./_components";
import type { NextPage } from "next";
import { hardhat } from "viem/chains";
import { useFetchBlocks } from "~~/hooks/scaffold-eth";
import { useTargetNetwork } from "~~/hooks/scaffold-eth/useTargetNetwork";

const BlockExplorer: NextPage = () => {
  const { blocks, transactionReceipts, currentPage, totalBlocks, setCurrentPage, error } = useFetchBlocks();
  const { targetNetwork } = useTargetNetwork();
  const isLocalNetwork = targetNetwork.id === hardhat.id;

  if (!isLocalNetwork) {
    return (
      <div className="container mx-auto my-16 px-4">
        <div className="max-w-2xl mx-auto rounded-3xl border border-base-300 bg-base-100 p-8 shadow-lg">
          <h1 className="text-3xl font-bold mb-4">Local Explorer Only</h1>
          <p className="text-base-content/70 mb-6">
            The in-app block explorer is only available for the local Foundry chain. On testnets, use the selected
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
  }

  if (error) {
    return (
      <div className="container mx-auto my-16 px-4">
        <div className="max-w-2xl mx-auto rounded-3xl border border-base-300 bg-base-100 p-8 shadow-lg">
          <h1 className="text-3xl font-bold mb-4">Local Explorer Unavailable</h1>
          <p className="text-base-content/70 mb-3">
            The local explorer only works when the Foundry chain is running and reachable from the web app.
          </p>
          <p className="text-sm text-error m-0">{error.message}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto my-10">
      <SearchBar />
      <TransactionsTable blocks={blocks} transactionReceipts={transactionReceipts} />
      <PaginationButton currentPage={currentPage} totalItems={Number(totalBlocks)} setCurrentPage={setCurrentPage} />
    </div>
  );
};

export default BlockExplorer;
