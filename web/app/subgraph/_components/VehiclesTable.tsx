"use client";

import { useEffect, useState } from "react";
import { Address } from "~~/components/scaffold-eth";
import { useSelectedNetwork } from "~~/hooks/scaffold-eth";
import { getSubgraphQueryUrl } from "~~/utils/subgraph";

type VehicleRow = {
  id: string;
  partner: `0x${string}`;
  vin?: string;
  make?: string;
  model?: string;
  year?: string;
  blockNumber: string;
};

type VehiclesQueryResult = {
  vehicles: VehicleRow[];
};

const VehiclesTable = () => {
  const selectedNetwork = useSelectedNetwork();
  const subgraphUrl = getSubgraphQueryUrl(selectedNetwork.id);
  const [vehiclesData, setVehiclesData] = useState<VehiclesQueryResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        if (!subgraphUrl) {
          throw new Error(`No subgraph endpoint configured for ${selectedNetwork.name}.`);
        }

        const response = await fetch(subgraphUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            query: `
              query GetAllVehicles {
                vehicles(first: 25, orderBy: blockTimestamp, orderDirection: desc) {
                  id
                  partner
                  vin
                  make
                  model
                  year
                  blockNumber
                  blockTimestamp
                  transactionHash
                }
              }
            `,
          }),
        });

        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`);
        }

        const result = (await response.json()) as { data?: VehiclesQueryResult };
        setVehiclesData(result.data ?? { vehicles: [] });
        setError(null);
      } catch (err) {
        console.error("Subgraph fetch error:", err);
        setError(err instanceof Error ? err.message : "Failed to fetch indexed vehicles.");
      }
    };

    fetchData();
  }, [selectedNetwork.name, subgraphUrl]);

  if (error) {
    return <div className="mt-6 text-center text-error">Error fetching data: {error}</div>;
  }

  if (!vehiclesData) {
    return <div className="mt-6 text-center">Loading indexed vehicles...</div>;
  }

  return (
    <div className="mt-10 flex justify-center items-center">
      <div className="overflow-x-auto shadow-2xl rounded-xl">
        <table className="table bg-base-100 table-zebra">
          <thead>
            <tr className="rounded-xl">
              <th className="bg-primary">ID</th>
              <th className="bg-primary">Year</th>
              <th className="bg-primary">Make</th>
              <th className="bg-primary">Model</th>
              <th className="bg-primary">VIN</th>
              <th className="bg-primary">Partner</th>
              <th className="bg-primary">Block Number</th>
            </tr>
          </thead>
          <tbody>
            {vehiclesData.vehicles.map(vehicle => (
              <tr key={vehicle.id}>
                <th>{vehicle.id}</th>
                <td>{vehicle.year?.toString() || "-"}</td>
                <td>{vehicle.make || "-"}</td>
                <td>{vehicle.model || "-"}</td>
                <td>{vehicle.vin}</td>
                <td>
                  <Address address={vehicle.partner} />
                </td>
                <td>{vehicle.blockNumber}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default VehiclesTable;
