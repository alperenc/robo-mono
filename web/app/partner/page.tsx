"use client";

import { useEffect, useState } from "react";
import { NextPage } from "next";
import { useAccount, useReadContracts } from "wagmi";
import { ChevronDownIcon } from "@heroicons/react/24/outline";
import { GetVehiclesDocument, execute } from "~~/.graphclient";
import { ListVehicleModal } from "~~/components/partner/ListVehicleModal";
import { MintTokensModal } from "~~/components/partner/MintTokensModal";
import { RegisterAssetModal } from "~~/components/partner/RegisterAssetModal";
import { ASSET_REGISTRIES, AssetType } from "~~/config/assetTypes";
import deployedContracts from "~~/contracts/deployedContracts";

type RegisterMode = "REGISTER_ONLY" | "REGISTER_AND_MINT";

// Unified Asset Interface for Dashboard logic
interface DashboardAsset {
  id: string;
  vin?: string; // Specific to Vehicle
  partner: string;
  blockNumber: string;
  type: AssetType; // The discriminator
  supply?: bigint; // Enriched data
}

const PartnerDashboard: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const [allAssets, setAllAssets] = useState<DashboardAsset[]>([]);
  const [filterType, setFilterType] = useState<AssetType | "ALL">("ALL");

  // Modal States
  const [isRegisterOpen, setIsRegisterOpen] = useState(false);
  const [registerMode, setRegisterMode] = useState<RegisterMode>("REGISTER_AND_MINT");
  const [selectedAsset, setSelectedAsset] = useState<DashboardAsset | null>(null);
  const [mintModalOpen, setMintModalOpen] = useState(false);
  const [listModalOpen, setListModalOpen] = useState(false);

  // Dynamic UI Configuration
  const activeRegistries = Object.values(ASSET_REGISTRIES).filter(r => r.active);
  const isSingleAssetType = activeRegistries.length === 1;

  const registerButtonLabel = isSingleAssetType ? `Register ${activeRegistries[0].name}` : "Register Asset";

  const dashboardSubtitle = isSingleAssetType
    ? `Manage your ${activeRegistries[0].name.toLowerCase()} ${activeRegistries[0].collectiveNoun} and revenue tokens`
    : "Manage your registered assets and revenue tokens";

  // 1. Fetch & Normalize Data (Generic Asset Aggregation)
  useEffect(() => {
    const fetchAssets = async () => {
      if (!connectedAddress) return;

      const assets: DashboardAsset[] = [];

      try {
        // --- Source 1: Vehicles ---
        if (ASSET_REGISTRIES[AssetType.VEHICLE].active) {
          const { data: vehicleData } = await execute(GetVehiclesDocument, { partner: connectedAddress.toLowerCase() });
          const normalizedVehicles: DashboardAsset[] = (vehicleData?.vehicles || []).map((v: any) => ({
            ...v,
            type: AssetType.VEHICLE,
          }));
          assets.push(...normalizedVehicles);
        }

        // --- Source 2: Real Estate (Placeholder for future expansion) ---
        // if (ASSET_REGISTRIES[AssetType.REAL_ESTATE].active) { ... fetch & normalize ... }

        setAllAssets(assets);
      } catch (e) {
        console.error("Error fetching assets:", e);
      }
    };
    fetchAssets();
  }, [connectedAddress, isRegisterOpen, mintModalOpen, listModalOpen]);

  // 2. Fetch Token Status (Batched for all assets)
  const contractConfig = {
    address: deployedContracts[31337]?.RoboshareTokens?.address,
    abi: deployedContracts[31337]?.RoboshareTokens?.abi,
  } as const;

  const { data: supplies } = useReadContracts({
    contracts: allAssets.map(asset => ({
      ...contractConfig,
      functionName: "getRevenueTokenSupply",
      args: [BigInt(asset.id) + 1n],
    })),
    query: {
      enabled: allAssets.length > 0,
    },
  });

  // 3. Filter & Categorize
  const filteredAssets = allAssets.filter(asset => {
    // Global Config Check: Asset type must be active
    if (!ASSET_REGISTRIES[asset.type].active) return false;

    // User Filter Check: ALL or specific match
    if (filterType !== "ALL" && filterType !== asset.type) return false;

    return true;
  });

  const pendingAssets: DashboardAsset[] = [];
  const activeAssets: DashboardAsset[] = [];

  filteredAssets.forEach(asset => {
    const originalIndex = allAssets.findIndex(a => a.id === asset.id);
    const supply = supplies?.[originalIndex]?.result as bigint | undefined;

    if (supply !== undefined && supply > 0n) {
      activeAssets.push({ ...asset, supply });
    } else {
      pendingAssets.push({ ...asset });
    }
  });

  // 4. Dynamic Empty State Content
  let emptyStateTitle = "Start Your Asset Portfolio";
  let emptyStateDesc =
    "You haven't registered any assets yet. Register an asset to start tokenizing and earning revenue.";

  if (isSingleAssetType) {
    const config = activeRegistries[0];
    emptyStateTitle = `Start Your ${config.name} ${config.collectiveNoun.charAt(0).toUpperCase() + config.collectiveNoun.slice(1)}`;
    emptyStateDesc = `You haven't registered any ${config.pluralName.toLowerCase()} yet.`;
  } else if (filterType !== "ALL") {
    const config = ASSET_REGISTRIES[filterType];
    emptyStateTitle = `Start Your ${config.name} ${config.collectiveNoun.charAt(0).toUpperCase() + config.collectiveNoun.slice(1)}`;
    emptyStateDesc = `You haven't registered any ${config.pluralName.toLowerCase()} yet.`;
  }

  const activeSectionTitle = isSingleAssetType
    ? `Active ${activeRegistries[0].collectiveNoun.charAt(0).toUpperCase() + activeRegistries[0].collectiveNoun.slice(1)}`
    : "Active Assets";

  const openMintModal = (asset: DashboardAsset) => {
    setSelectedAsset(asset);
    setMintModalOpen(true);
  };

  const openListModal = (asset: DashboardAsset) => {
    setSelectedAsset(asset);
    setListModalOpen(true);
  };

  if (!connectedAddress) {
    return <div className="text-center py-20 text-xl">Please connect your wallet to access the dashboard.</div>;
  }

  return (
    <div className="flex flex-col gap-10 py-10 px-5 max-w-7xl mx-auto">
      {/* Header & Global Actions */}
      <div className="flex justify-between items-end">
        <div>
          <h1 className="text-4xl font-bold text-primary">Partner Dashboard</h1>
          <p className="opacity-70 mt-2 text-lg">{dashboardSubtitle}</p>
        </div>

        <div className="flex gap-4 items-center">
          {/* Asset Type Filter - only show if multiple active registries */}
          {!isSingleAssetType && (
            <div className="join bg-base-200 p-1 rounded-lg">
              <button
                className={`btn btn-sm join-item ${filterType === "ALL" ? "btn-primary" : "btn-ghost"}`}
                onClick={() => setFilterType("ALL")}
              >
                All
              </button>
              {Object.entries(ASSET_REGISTRIES)
                .filter(([, r]) => r.active)
                .map(([key, registry]) => (
                  <button
                    key={key}
                    className={`btn btn-sm join-item ${filterType === key ? "btn-primary" : "btn-ghost"}`}
                    onClick={() => setFilterType(key as AssetType)}
                  >
                    {registry.pluralName}
                  </button>
                ))}
            </div>
          )}

          {/* Split Register Button */}
          <div className="flex">
            <button
              className="btn btn-primary rounded-r-none border-r-base-100"
              onClick={() => {
                setIsRegisterOpen(true);
                setRegisterMode("REGISTER_AND_MINT");
              }}
            >
              {registerButtonLabel}
            </button>
            <div className="dropdown dropdown-end">
              <div tabIndex={0} role="button" className="btn btn-primary rounded-l-none px-2 min-h-0 h-full">
                <ChevronDownIcon className="h-5 w-5" />
              </div>
              <ul tabIndex={0} className="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52 mt-2">
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

      {/* Main Content Area */}
      {filteredAssets.length === 0 ? (
        /* EMPTY STATE */
        <div className="hero bg-base-200 rounded-3xl py-20 px-10 border-2 border-dashed border-base-300">
          <div className="hero-content text-center">
            <div className="max-w-md">
              <h2 className="text-3xl font-bold">{emptyStateTitle}</h2>
              <p className="py-6 text-lg opacity-80">{emptyStateDesc}</p>
              <div className="flex justify-center">
                <button
                  className="btn btn-primary btn-lg rounded-r-none border-r-base-100"
                  onClick={() => {
                    setIsRegisterOpen(true);
                    setRegisterMode("REGISTER_AND_MINT");
                  }}
                >
                  Get Started
                </button>
                <div className="dropdown dropdown-end">
                  <div tabIndex={0} role="button" className="btn btn-primary btn-lg rounded-l-none px-3 min-h-0 h-full">
                    <ChevronDownIcon className="h-6 w-6" />
                  </div>
                  <ul
                    tabIndex={0}
                    className="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52 text-left mt-2"
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
      ) : (
        <div className="flex flex-col gap-12">
          {/* PENDING SECTION */}
          {pendingAssets.length > 0 && (
            <section>
              <h2 className="text-2xl font-bold mb-6 border-b border-warning/30 pb-2 flex items-center gap-2">
                Pending Tokenization <span className="badge badge-warning badge-md">{pendingAssets.length}</span>
              </h2>
              <div className="grid gap-4">
                {pendingAssets.map(asset => (
                  <div
                    key={asset.id}
                    className="card bg-base-100 shadow-sm border-l-4 border-warning flex-row items-center p-5 hover:shadow-md transition-shadow"
                  >
                    <div className="flex-1">
                      <div className="text-sm opacity-50 uppercase tracking-widest font-semibold">{asset.type}</div>
                      <div className="font-bold text-xl">
                        {asset.type === AssetType.VEHICLE ? asset.vin : `Asset #${asset.id}`}
                      </div>
                      <div className="text-xs opacity-60">System ID: {asset.id}</div>
                    </div>
                    <div className="flex-none">
                      <button className="btn btn-warning btn-outline" onClick={() => openMintModal(asset)}>
                        Mint Revenue Tokens
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </section>
          )}

          {/* ACTIVE SECTION */}
          {activeAssets.length > 0 && (
            <section>
              <h2 className="text-2xl font-bold mb-6 border-b border-success/30 pb-2 flex items-center gap-2">
                {activeSectionTitle} <span className="badge badge-success badge-md">{activeAssets.length}</span>
              </h2>
              <div className="grid gap-4">
                {activeAssets.map(asset => (
                  <div
                    key={asset.id}
                    className="card bg-base-100 shadow-sm border-l-4 border-success flex-row items-center p-5 hover:shadow-md transition-shadow"
                  >
                    <div className="flex-1">
                      <div className="text-sm opacity-50 uppercase tracking-widest font-semibold">{asset.type}</div>
                      <div className="font-bold text-xl">
                        {asset.type === AssetType.VEHICLE ? asset.vin : `Asset #${asset.id}`}
                      </div>
                      <div className="text-sm opacity-70">
                        Supply: <span className="font-mono">{asset.supply?.toString()}</span> shares
                      </div>
                    </div>
                    <div className="flex-none">
                      <button className="btn btn-success text-white" onClick={() => openListModal(asset)}>
                        List for Sale
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            </section>
          )}
        </div>
      )}

      {/* Modals */}
      <RegisterAssetModal isOpen={isRegisterOpen} onClose={() => setIsRegisterOpen(false)} initialMode={registerMode} />

      {selectedAsset && selectedAsset.type === AssetType.VEHICLE && (
        <>
          <MintTokensModal
            isOpen={mintModalOpen}
            onClose={() => setMintModalOpen(false)}
            vehicleId={selectedAsset.id}
            vin={selectedAsset.vin || ""}
          />
          <ListVehicleModal
            isOpen={listModalOpen}
            onClose={() => setListModalOpen(false)}
            vehicleId={selectedAsset.id}
            vin={selectedAsset.vin || ""}
          />
        </>
      )}
    </div>
  );
};

export default PartnerDashboard;
