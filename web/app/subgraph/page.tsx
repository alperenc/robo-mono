"use client";

import Link from "next/link";
import VehiclesTable from "./_components/VehiclesTable";
import { MagnifyingGlassIcon } from "@heroicons/react/24/outline";
import { RequireAdmin } from "~~/components/RequireAdmin";
import { useSelectedNetwork } from "~~/hooks/scaffold-eth";
import { getSubgraphGraphiqlUrl } from "~~/utils/subgraph";

export default function Subgraph() {
  const selectedNetwork = useSelectedNetwork();
  const graphiqlUrl = getSubgraphGraphiqlUrl(selectedNetwork.id);

  return (
    <RequireAdmin>
      <div className="container mx-auto my-10 px-4">
        <div className="mx-auto max-w-5xl rounded-3xl border border-base-300 bg-base-100 p-8 shadow-lg">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h1 className="mb-2 text-4xl font-bold">Indexed Data</h1>
              <p className="m-0 text-base-content/70">
                Internal subgraph tooling for reviewing indexed Roboshare data on {selectedNetwork.name}.
              </p>
            </div>
            <div className="flex items-center gap-3">
              <span className="badge badge-outline px-3 py-3 text-sm">{selectedNetwork.name}</span>
              {graphiqlUrl ? (
                <Link
                  href={graphiqlUrl}
                  passHref
                  className="btn btn-primary gap-2"
                  target="_blank"
                  rel="noopener noreferrer"
                >
                  <MagnifyingGlassIcon className="h-4 w-4" />
                  Open GraphiQL
                </Link>
              ) : null}
            </div>
          </div>
          {!graphiqlUrl ? (
            <div className="alert mt-6 border border-base-300 bg-base-200/70 text-base-content">
              <span>No subgraph endpoint is configured for {selectedNetwork.name}.</span>
            </div>
          ) : null}
        </div>
        <VehiclesTable />
      </div>
    </RequireAdmin>
  );
}
