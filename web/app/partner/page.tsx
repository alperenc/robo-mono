"use client";

import { useEffect, useState } from "react";
import { NextPage } from "next";
import { useAccount, useReadContracts } from "wagmi";
import { ChevronDownIcon } from "@heroicons/react/24/outline";
import { GetVehiclesDocument, execute } from "~~/.graphclient";
import { ListVehicleModal } from "~~/components/partner/ListVehicleModal";
import { MintTokensModal } from "~~/components/partner/MintTokensModal";
import { RegisterVehicleModal } from "~~/components/partner/RegisterVehicleModal";
import deployedContracts from "~~/contracts/deployedContracts";

type RegisterMode = "REGISTER_ONLY" | "REGISTER_AND_MINT";

const PartnerDashboard: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const [vehicles, setVehicles] = useState<any[]>([]);

  // Modal States
  const [isRegisterOpen, setIsRegisterOpen] = useState(false);
  const [registerMode, setRegisterMode] = useState<RegisterMode>("REGISTER_AND_MINT"); // Default mode for register
  const [selectedVehicle, setSelectedVehicle] = useState<{ id: string; vin: string } | null>(null);
  const [mintModalOpen, setMintModalOpen] = useState(false);
  const [listModalOpen, setListModalOpen] = useState(false);

  // 1. Fetch Basic Vehicle Data from Subgraph
  useEffect(() => {
    const fetchVehicles = async () => {
      if (!connectedAddress) return;
      try {
        const { data } = await execute(GetVehiclesDocument, { partner: connectedAddress.toLowerCase() });
        if (data?.vehicles) {
          setVehicles(data.vehicles);
        }
      } catch (e) {
        console.error("Error fetching vehicles:", e);
      }
    };
    fetchVehicles();
  }, [connectedAddress, isRegisterOpen, mintModalOpen, listModalOpen]); // Refresh when modals close

  // 2. Fetch Token Status (Supply) for each vehicle to determine if Active or Pending
  // We predict revenueTokenId = assetId + 1
  const contractConfig = {
    address: deployedContracts[31337]?.RoboshareTokens?.address,
    abi: deployedContracts[31337]?.RoboshareTokens?.abi,
  } as const;

  const { data: supplies } = useReadContracts({
    contracts: vehicles.map(v => ({
      ...contractConfig,
      functionName: "getRevenueTokenSupply",
      args: [BigInt(v.id) + 1n],
    })),
    query: {
      enabled: vehicles.length > 0,
    },
  });

  // 3. Categorize Vehicles
  const pendingVehicles: any[] = [];
  const activeVehicles: any[] = [];

  vehicles.forEach((vehicle, index) => {
    const supply = supplies?.[index]?.result as bigint | undefined;
    // If supply > 0, it's active (tokens minted). Else pending.
    if (supply !== undefined && supply > 0n) {
      activeVehicles.push({ ...vehicle, supply });
    } else {
      pendingVehicles.push({ ...vehicle });
    }
  });

  const openMintModal = (vehicle: any) => {
    setSelectedVehicle(vehicle);
    setMintModalOpen(true);
  };

  const openListModal = (vehicle: any) => {
    setSelectedVehicle(vehicle);
    setListModalOpen(true);
  };

  if (!connectedAddress) {
    return <div className="text-center py-20">Please connect your wallet.</div>;
  }

  return (
    <div className="flex flex-col gap-10 py-10 px-5 max-w-7xl mx-auto">
      {/* Header & Main CTA */}
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-4xl font-bold">Partner Dashboard</h1>
          <p className="opacity-70">Manage your fleet and revenue tokens</p>
        </div>
        <div className="flex">
          <button
            className="btn btn-primary rounded-r-none border-r-base-100"
            onClick={() => {
              setIsRegisterOpen(true);
              setRegisterMode("REGISTER_AND_MINT");
            }}
          >
            Register Vehicle
          </button>
          <div className="dropdown dropdown-end">
            <div tabIndex={0} role="button" className="btn btn-primary rounded-l-none px-2 min-h-0 h-full">
              <ChevronDownIcon className="h-5 w-5" />
            </div>
            <ul tabIndex={0} className="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52">
              <li>
                <a
                  onClick={() => {
                    setIsRegisterOpen(true);
                    setRegisterMode("REGISTER_AND_MINT");
                  }}
                >
                  Register & Mint
                </a>
              </li>
              <li>
                <a
                  onClick={() => {
                    setIsRegisterOpen(true);
                    setRegisterMode("REGISTER_ONLY");
                  }}
                >
                  Register Only
                </a>
              </li>
            </ul>
          </div>
        </div>
      </div>

      {/* EMPTY STATE */}
      {vehicles.length === 0 && (
        <div className="hero bg-base-200 rounded-xl p-10">
          <div className="hero-content text-center">
            <div className="max-w-md">
              <h2 className="text-3xl font-bold">Start Your Fleet</h2>
              <p className="py-6">
                You haven&apos;t registered any vehicles yet. Register a vehicle to start tokenizing and earning
                revenue.
              </p>
              <div className="flex justify-center">
                <button
                  className="btn btn-primary rounded-r-none border-r-base-100"
                  onClick={() => {
                    setIsRegisterOpen(true);
                    setRegisterMode("REGISTER_AND_MINT");
                  }}
                >
                  Get Started
                </button>
                <div className="dropdown dropdown-end">
                  <div tabIndex={0} role="button" className="btn btn-primary rounded-l-none px-2 min-h-0 h-full">
                    <ChevronDownIcon className="h-5 w-5" />
                  </div>
                  <ul
                    tabIndex={0}
                    className="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52 text-left"
                  >
                    <li>
                      <a
                        onClick={() => {
                          setIsRegisterOpen(true);
                          setRegisterMode("REGISTER_AND_MINT");
                        }}
                      >
                        Register & Mint
                      </a>
                    </li>
                    <li>
                      <a
                        onClick={() => {
                          setIsRegisterOpen(true);
                          setRegisterMode("REGISTER_ONLY");
                        }}
                      >
                        Register Only
                      </a>
                    </li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* PENDING SECTION */}
      {pendingVehicles.length > 0 && (
        <section>
          <h2 className="text-2xl font-bold mb-4 border-b pb-2">
            Pending Tokenization <span className="badge badge-ghost">{pendingVehicles.length}</span>
          </h2>
          <div className="grid gap-4">
            {pendingVehicles.map(v => (
              <div
                key={v.id}
                className="card bg-base-100 shadow-md border-l-4 border-warning flex-row items-center p-4"
              >
                <div className="flex-1">
                  <div className="font-bold text-lg">{v.vin}</div>
                  <div className="text-sm opacity-70">ID: {v.id}</div>
                </div>
                <div className="flex-none">
                  <button className="btn btn-sm btn-outline btn-warning" onClick={() => openMintModal(v)}>
                    Mint Tokens
                  </button>
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* ACTIVE SECTION */}
      {activeVehicles.length > 0 && (
        <section>
          <h2 className="text-2xl font-bold mb-4 border-b pb-2">
            Active Fleet <span className="badge badge-success">{activeVehicles.length}</span>
          </h2>
          <div className="grid gap-4">
            {activeVehicles.map(v => (
              <div
                key={v.id}
                className="card bg-base-100 shadow-md border-l-4 border-success flex-row items-center p-4"
              >
                <div className="flex-1">
                  <div className="font-bold text-lg">{v.vin}</div>
                  <div className="text-sm opacity-70">
                    ID: {v.id} • Supply: {v.supply?.toString()}
                  </div>
                </div>
                <div className="flex-none">
                  <button className="btn btn-sm btn-success text-white" onClick={() => openListModal(v)}>
                    List for Sale
                  </button>
                </div>
              </div>
            ))}
          </div>
        </section>
      )}

      {/* Modals */}
      <RegisterVehicleModal
        isOpen={isRegisterOpen}
        onClose={() => setIsRegisterOpen(false)}
        initialMode={registerMode}
      />

      {selectedVehicle && (
        <>
          <MintTokensModal
            isOpen={mintModalOpen}
            onClose={() => setMintModalOpen(false)}
            vehicleId={selectedVehicle.id}
            vin={selectedVehicle.vin}
          />
          <ListVehicleModal
            isOpen={listModalOpen}
            onClose={() => setListModalOpen(false)}
            vehicleId={selectedVehicle.id}
            vin={selectedVehicle.vin}
          />
        </>
      )}
    </div>
  );
};

export default PartnerDashboard;
