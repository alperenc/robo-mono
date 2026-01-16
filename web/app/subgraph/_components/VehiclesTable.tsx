"use client";

import { useEffect, useState } from "react";
import { Address } from "~~/components/scaffold-eth";

const VehiclesTable = () => {
  const [vehiclesData, setVehiclesData] = useState<any>(null);
  const [error, setError] = useState<any>(null);

  useEffect(() => {
    const fetchData = async () => {
      try {
        const response = await fetch("http://localhost:8000/subgraphs/name/roboshare/protocol", {
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

        const result = await response.json();
        setVehiclesData(result.data);
      } catch (err) {
        console.error("Subgraph fetch error:", err);
        setError(err);
      }
    };

    fetchData();
  }, []);

  if (error) {
    return <div className="text-center text-error">Error fetching data: {error.message}</div>;
  }

  if (!vehiclesData) {
    return <div className="text-center">Loading...</div>;
  }

  return (
    <div className="flex justify-center items-center mt-10">
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
            {vehiclesData?.vehicles?.map((vehicle: any) => (
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
