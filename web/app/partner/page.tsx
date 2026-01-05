"use client";

import { useEffect, useRef, useState } from "react";
import { NextPage } from "next";
import { useAccount, useReadContracts } from "wagmi";
import { ChevronDownIcon } from "@heroicons/react/24/outline";
import { DistributeEarningsModal } from "~~/components/partner/DistributeEarningsModal";
import { EndListingModal } from "~~/components/partner/EndListingModal";
import { ExtendListingModal } from "~~/components/partner/ExtendListingModal";
import { ListVehicleModal } from "~~/components/partner/ListVehicleModal";
import { MintTokensModal } from "~~/components/partner/MintTokensModal";
import { RegisterAssetModal } from "~~/components/partner/RegisterAssetModal";
import { SettleAssetModal } from "~~/components/partner/SettleAssetModal";
import { ASSET_REGISTRIES, AssetType } from "~~/config/assetTypes";
import deployedContracts from "~~/contracts/deployedContracts";
import { fetchIpfsMetadata, ipfsToHttp } from "~~/utils/ipfsGateway";

type RegisterMode = "REGISTER_ONLY" | "REGISTER_AND_MINT";

// Unified Asset Interface for Dashboard logic
interface DashboardAsset {
  id: string;
  vin?: string;
  make?: string;
  model?: string;
  year?: string | bigint;
  partner: string;
  blockNumber: string;
  type: AssetType;
  supply?: bigint;
  metadataURI?: string;
  imageUrl?: string;
  assetStatus?: number; // 0=Pending, 1=Active, 2=Matured, 3=Retired, 4=Expired
}

// Listing interface from subgraph
interface SubgraphListing {
  id: string;
  tokenId: string;
  assetId: string;
  seller: string;
  amount: string;
  amountSold: string;
  pricePerToken: string;
  expiresAt: string;
  status: string;
  createdAt: string;
}

// Asset state enum for the 5 lifecycle states
type AssetState = "ACTIVE_FLEET" | "ACTIVE_LISTINGS" | "PENDING_LISTINGS" | "PENDING_TOKENIZATION" | "SETTLED";

interface CategorizedAsset extends DashboardAsset {
  state: AssetState;
  listings?: SubgraphListing[];
  totalSold?: bigint;
}

const PartnerDashboard: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const [allAssets, setAllAssets] = useState<DashboardAsset[]>([]);
  const [listings, setListings] = useState<SubgraphListing[]>([]);
  const [filterType, setFilterType] = useState<AssetType | "ALL">("ALL");
  const [filterState, setFilterState] = useState<AssetState | "ALL">("ALL");

  // Modal States
  const [isRegisterOpen, setIsRegisterOpen] = useState(false);
  const [registerMode, setRegisterMode] = useState<RegisterMode>("REGISTER_AND_MINT");
  const [selectedAsset, setSelectedAsset] = useState<DashboardAsset | null>(null);
  const [selectedCategorizedAsset, setSelectedCategorizedAsset] = useState<CategorizedAsset | null>(null);
  const [mintModalOpen, setMintModalOpen] = useState(false);
  const [listModalOpen, setListModalOpen] = useState(false);
  const [selectedListing, setSelectedListing] = useState<SubgraphListing | null>(null);
  const [distributeEarningsModalOpen, setDistributeEarningsModalOpen] = useState(false);
  const [settleAssetModalOpen, setSettleAssetModalOpen] = useState(false);
  const [extendListingModalOpen, setExtendListingModalOpen] = useState(false);
  const [endListingModalOpen, setEndListingModalOpen] = useState(false);
  const [refreshCounter, setRefreshCounter] = useState(0);

  // Trigger a data refresh with delay to allow subgraph to index
  const triggerRefresh = (delayMs = 2000) => {
    setTimeout(() => {
      setRefreshCounter(c => c + 1);
    }, delayMs);
  };

  // Dynamic Labels (Global)
  const activeRegistries = Object.values(ASSET_REGISTRIES).filter(r => r.active);
  const isSingleAssetType = activeRegistries.length === 1;

  const registerButtonLabel = isSingleAssetType ? `Register ${activeRegistries[0].name}` : "Register Asset";

  const dashboardSubtitle = isSingleAssetType
    ? `Manage your ${activeRegistries[0].name.toLowerCase()} ${activeRegistries[0].collectiveNoun} and revenue tokens`
    : "Manage your registered assets and revenue tokens";

  // Fetch assets and listings
  useEffect(() => {
    const fetchData = async () => {
      if (!connectedAddress) return;

      const assets: DashboardAsset[] = [];

      try {
        // Fetch vehicles and listings in one query
        if (ASSET_REGISTRIES[AssetType.VEHICLE].active) {
          const response = await fetch("http://localhost:8000/subgraphs/name/roboshare/protocol", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              query: `
                query GetPartnerData {
                  vehicles(first: 100, orderBy: blockTimestamp, orderDirection: desc) {
                    id
                    partner
                    vin
                    make
                    model
                    year
                    metadataURI
                    blockNumber
                    blockTimestamp
                    transactionHash
                  }
                  listings(first: 100, orderBy: createdAt, orderDirection: desc) {
                    id
                    tokenId
                    assetId
                    seller
                    amount
                    amountSold
                    pricePerToken
                    expiresAt
                    status
                    createdAt
                  }
                }
              `,
            }),
          });

          if (!response.ok) throw new Error(`Subgraph fetch failed: ${response.statusText}`);

          const responseJson = await response.json();
          const { data } = responseJson;

          // Filter vehicles for this partner
          const myVehicles = (data?.vehicles || []).filter(
            (v: any) => v.partner.toLowerCase() === connectedAddress?.toLowerCase(),
          );

          const normalizedVehicles: DashboardAsset[] = myVehicles.map((v: any) => ({
            ...v,
            type: AssetType.VEHICLE,
          }));
          assets.push(...normalizedVehicles);

          // Filter listings for this partner
          const myListings = (data?.listings || []).filter(
            (l: any) => l.seller.toLowerCase() === connectedAddress?.toLowerCase(),
          );
          setListings(myListings);
        }

        setAllAssets(assets);
      } catch (e) {
        console.error("Error fetching data:", e);
      }
    };
    fetchData();
  }, [connectedAddress, refreshCounter]);

  // Fetch image URLs from IPFS metadata
  useEffect(() => {
    const fetchImageUrls = async () => {
      const assetsWithMetadata = allAssets.filter(a => a.metadataURI && !a.imageUrl);
      if (assetsWithMetadata.length === 0) return;

      const updatedAssets = await Promise.all(
        allAssets.map(async asset => {
          if (asset.imageUrl || !asset.metadataURI) return asset;

          try {
            const metadata = await fetchIpfsMetadata(asset.metadataURI);
            if (metadata?.image) {
              return { ...asset, imageUrl: ipfsToHttp(metadata.image) || undefined };
            }
          } catch (error) {
            console.error(`Error fetching metadata for asset ${asset.id}:`, error);
          }
          return asset;
        }),
      );

      const hasNewImages = updatedAssets.some((a, i) => a.imageUrl !== allAssets[i].imageUrl);
      if (hasNewImages) {
        setAllAssets(updatedAssets);
      }
    };

    fetchImageUrls();
  }, [allAssets]);

  // Fetch Token Supplies
  const contractConfig = {
    address: deployedContracts[31337]?.RoboshareTokens?.address,
    abi: deployedContracts[31337]?.RoboshareTokens?.abi,
  } as const;

  // Type for useReadContracts result item
  type ContractResult<T> = { result?: T; status: string; error?: Error };

  const { data: suppliesData, refetch: refetchSupplies } = useReadContracts({
    contracts: allAssets.map(asset => ({
      ...contractConfig,
      functionName: "getRevenueTokenSupply",
      args: [BigInt(asset.id) + 1n],
    })),
    query: { enabled: allAssets.length > 0 },
  });
  // Cast to break deep type inference
  const supplies = suppliesData as ContractResult<bigint>[] | undefined;

  // Fetch Asset Statuses from RegistryRouter
  const routerConfig = {
    address: deployedContracts[31337]?.RegistryRouter?.address,
    abi: deployedContracts[31337]?.RegistryRouter?.abi,
  } as const;

  const { data: statusesData, refetch: refetchStatuses } = useReadContracts({
    contracts: allAssets.map(asset => ({
      ...routerConfig,
      functionName: "getAssetStatus",
      args: [BigInt(asset.id)],
    })),
    query: { enabled: allAssets.length > 0 },
  });
  // Cast to break deep type inference
  const assetStatuses = statusesData as ContractResult<number>[] | undefined;

  // Store refetch functions in refs to avoid deep type instantiation in useCallback deps
  const refetchSuppliesRef = useRef(refetchSupplies);
  const refetchStatusesRef = useRef(refetchStatuses);
  refetchSuppliesRef.current = refetchSupplies;
  refetchStatusesRef.current = refetchStatuses;

  // Refetch supplies and statuses when refreshCounter changes
  useEffect(() => {
    if (refreshCounter > 0 && allAssets.length > 0) {
      void refetchSuppliesRef.current();
      void refetchStatusesRef.current();
    }
  }, [refreshCounter, allAssets.length]);

  // Categorize assets into 5 states
  const categorizeAssets = (): {
    activeFleet: CategorizedAsset[];
    activeListings: CategorizedAsset[];
    pendingListings: CategorizedAsset[];
    pendingTokenization: CategorizedAsset[];
    settledAssets: CategorizedAsset[];
  } => {
    const activeFleet: CategorizedAsset[] = [];
    const activeListings: CategorizedAsset[] = [];
    const pendingListings: CategorizedAsset[] = [];
    const pendingTokenization: CategorizedAsset[] = [];
    const settledAssets: CategorizedAsset[] = [];

    allAssets.forEach((asset, index) => {
      // Filter by asset type if needed
      if (!ASSET_REGISTRIES[asset.type].active) return;
      if (filterType !== "ALL" && filterType !== asset.type) return;

      const supply = supplies?.[index]?.result as bigint | undefined;
      const status = assetStatuses?.[index]?.result as number | undefined;
      const assetListings = listings.filter(l => l.assetId === asset.id);
      const activeAssetListings = assetListings.filter(l => l.status === "active");
      const totalSold = assetListings.reduce((acc, l) => acc + BigInt(l.amountSold || "0"), 0n);

      const categorizedAsset: CategorizedAsset = {
        ...asset,
        supply,
        assetStatus: status,
        listings: assetListings,
        totalSold,
        state: "PENDING_TOKENIZATION",
      };

      // State determination logic:
      // 0. Check if asset is settled (status 3=Retired or 4=Expired) - takes priority
      // 1. No supply = PENDING_TOKENIZATION
      // 2. Has supply, has active listings = ACTIVE_LISTINGS
      // 3. Has supply, no active listings, and tokens sold = ACTIVE_FLEET
      // 4. Has supply, no active listings, no tokens sold = PENDING_LISTINGS

      if (status === 3 || status === 4) {
        // Retired (3) or Expired (4) = SETTLED
        categorizedAsset.state = "SETTLED";
        settledAssets.push(categorizedAsset);
      } else if (!supply || supply === 0n) {
        categorizedAsset.state = "PENDING_TOKENIZATION";
        pendingTokenization.push(categorizedAsset);
      } else if (activeAssetListings.length > 0) {
        categorizedAsset.state = "ACTIVE_LISTINGS";
        activeListings.push(categorizedAsset);
      } else if (totalSold > 0n) {
        categorizedAsset.state = "ACTIVE_FLEET";
        activeFleet.push(categorizedAsset);
      } else {
        categorizedAsset.state = "PENDING_LISTINGS";
        pendingListings.push(categorizedAsset);
      }
    });

    return { activeFleet, activeListings, pendingListings, pendingTokenization, settledAssets };
  };

  const {
    activeFleet,
    activeListings: activeListingsAssets,
    pendingListings,
    pendingTokenization,
    settledAssets,
  } = categorizeAssets();
  const totalAssets =
    activeFleet.length +
    activeListingsAssets.length +
    pendingListings.length +
    pendingTokenization.length +
    settledAssets.length;

  // Helper functions
  const getAssetDisplayName = (asset: DashboardAsset) => {
    if (asset.make) return `${asset.year} ${asset.make} ${asset.model}`;
    if (asset.vin) return asset.vin;
    return `Asset #${asset.id}`;
  };

  const openMintModal = (asset: DashboardAsset) => {
    setSelectedAsset(asset);
    setMintModalOpen(true);
  };

  const openListModal = (asset: DashboardAsset) => {
    setSelectedAsset(asset);
    setListModalOpen(true);
  };

  if (!connectedAddress) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="text-center py-20 text-xl opacity-70">Please connect your wallet to access the dashboard.</div>
      </div>
    );
  }

  // Asset Card Component
  const AssetCard = ({
    asset,
    borderColor,
    primaryAction,
    secondaryAction,
  }: {
    asset: CategorizedAsset;
    borderColor: string;
    primaryAction?: { label: string; onClick: () => void; className: string };
    secondaryAction?: { label: string; onClick: () => void };
  }) => (
    <div
      className={`card bg-base-100 shadow-sm border-l-4 ${borderColor} p-4 sm:p-6 hover:shadow-md transition-shadow`}
    >
      <div className="flex flex-col sm:flex-row sm:items-center gap-4">
        {/* Asset Image */}
        <div className="w-16 h-16 sm:w-20 sm:h-20 flex-shrink-0 rounded-lg bg-base-200 overflow-hidden">
          {asset.imageUrl ? (
            <img src={asset.imageUrl} alt={getAssetDisplayName(asset)} className="w-full h-full object-cover" />
          ) : (
            <div className="w-full h-full flex items-center justify-center text-base-content/30">
              <span className="text-2xl sm:text-3xl">{ASSET_REGISTRIES[asset.type].icon}</span>
            </div>
          )}
        </div>

        {/* Asset Info */}
        <div className="flex-1 min-w-0">
          <div className="flex items-center gap-2">
            <div className="text-xs sm:text-sm opacity-50 uppercase tracking-widest font-semibold">{asset.type}</div>
            {asset.assetStatus === 3 && <span className="badge badge-sm badge-ghost">Retired</span>}
            {asset.assetStatus === 4 && <span className="badge badge-sm badge-warning">Expired</span>}
          </div>
          <div className="font-bold text-lg sm:text-xl truncate">{getAssetDisplayName(asset)}</div>
          <div className="text-xs opacity-60 truncate">
            ID: {asset.id} {asset.vin ? `• VIN: ${asset.vin}` : ""}
            {asset.supply ? ` • Supply: ${asset.supply.toLocaleString()} tokens` : ""}
          </div>
        </div>

        {/* Actions - only render if primaryAction is provided */}
        {primaryAction && (
          <div className="flex-shrink-0 flex gap-2 mt-2 sm:mt-0">
            {secondaryAction && (
              <div className="dropdown dropdown-end w-full sm:w-auto">
                <div className="flex items-stretch w-full sm:w-auto">
                  <button
                    className={`${primaryAction.className} rounded-r-none border-r-base-100 flex-1 sm:flex-none`}
                    onClick={primaryAction.onClick}
                  >
                    {primaryAction.label}
                  </button>
                  <div
                    tabIndex={0}
                    role="button"
                    className={`${primaryAction.className} rounded-l-none px-2 flex items-center`}
                  >
                    <ChevronDownIcon className="h-5 w-5" />
                  </div>
                </div>
                <ul tabIndex={0} className="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-52 mt-2">
                  <li>
                    <a onClick={secondaryAction.onClick}>{secondaryAction.label}</a>
                  </li>
                </ul>
              </div>
            )}
            {!secondaryAction && (
              <button className={`${primaryAction.className} w-full sm:w-auto`} onClick={primaryAction.onClick}>
                {primaryAction.label}
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );

  // Section Component
  const Section = ({
    title,
    count,
    badgeClass,
    borderClass,
    children,
  }: {
    title: string;
    count: number;
    badgeClass: string;
    borderClass: string;
    children: React.ReactNode;
  }) => (
    <section className="space-y-4 sm:space-y-6">
      <h2 className={`text-xl sm:text-2xl font-bold border-b ${borderClass} pb-3 flex items-center gap-3`}>
        {title} <span className={`badge ${badgeClass} badge-md`}>{count}</span>
      </h2>
      <div className="grid gap-3 sm:gap-4">{children}</div>
    </section>
  );

  return (
    <div className="flex flex-col gap-8 sm:gap-12 py-6 sm:py-10 px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
      {/* Header & Global Actions */}
      <div className="flex flex-col gap-4 sm:gap-6">
        {/* Title row with CTA */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <h1 className="text-2xl sm:text-3xl lg:text-4xl font-bold text-primary">Partner Dashboard</h1>

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

        {/* Subtitle and filters row - responsive: stacked on mobile, inline on desktop */}
        <div className="flex flex-col gap-4">
          <p className="opacity-70 text-lg">{dashboardSubtitle}</p>

          {/* Filters container - stacked on mobile, inline on desktop, wraps if needed */}
          <div className="flex flex-col lg:flex-row lg:flex-wrap lg:items-center lg:justify-between gap-3 lg:gap-6">
            {/* Asset Type Filter */}
            {!isSingleAssetType && (
              <div className="flex flex-col sm:flex-row sm:items-center gap-2">
                <span className="text-xs font-bold uppercase opacity-50 lg:hidden">Asset Type</span>
                <div className="join bg-base-200 p-1 rounded-lg flex-wrap">
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
              </div>
            )}

            {/* Separator - desktop only */}
            {!isSingleAssetType && <div className="hidden lg:block w-px h-6 bg-base-300" />}

            {/* Section State Filter */}
            <div className="flex flex-col sm:flex-row sm:items-center gap-2 lg:ml-auto">
              <span className="text-xs font-bold uppercase opacity-50 lg:hidden">Status</span>
              <div className="join bg-base-200 p-1 rounded-lg flex-wrap">
                <button
                  className={`btn btn-sm join-item ${filterState === "ALL" ? "btn-primary" : "btn-ghost"}`}
                  onClick={() => setFilterState("ALL")}
                >
                  All
                </button>
                <button
                  className={`btn btn-sm join-item ${filterState === "ACTIVE_FLEET" ? "btn-primary" : "btn-ghost"}`}
                  onClick={() => setFilterState("ACTIVE_FLEET")}
                >
                  Revenue
                </button>
                <button
                  className={`btn btn-sm join-item ${filterState === "ACTIVE_LISTINGS" ? "btn-primary" : "btn-ghost"}`}
                  onClick={() => setFilterState("ACTIVE_LISTINGS")}
                >
                  Listed
                </button>
                <button
                  className={`btn btn-sm join-item ${filterState === "PENDING_LISTINGS" ? "btn-primary" : "btn-ghost"}`}
                  onClick={() => setFilterState("PENDING_LISTINGS")}
                >
                  Ready
                </button>
                <button
                  className={`btn btn-sm join-item ${filterState === "PENDING_TOKENIZATION" ? "btn-primary" : "btn-ghost"}`}
                  onClick={() => setFilterState("PENDING_TOKENIZATION")}
                >
                  Setup
                </button>
                <button
                  className={`btn btn-sm join-item ${filterState === "SETTLED" ? "btn-primary" : "btn-ghost"}`}
                  onClick={() => setFilterState("SETTLED")}
                >
                  Settled
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Main Content Area */}
      {totalAssets === 0 ? (
        /* EMPTY STATE */
        <div className="hero bg-base-200 rounded-2xl sm:rounded-3xl py-12 sm:py-20 px-6 sm:px-10 border-2 border-dashed border-base-300">
          <div className="hero-content text-center">
            <div className="max-w-md">
              <h2 className="text-2xl sm:text-3xl font-bold">
                {isSingleAssetType
                  ? `Start Your ${activeRegistries[0].name} ${activeRegistries[0].collectiveNoun.charAt(0).toUpperCase() + activeRegistries[0].collectiveNoun.slice(1)}`
                  : "Start Your Asset Portfolio"}
              </h2>
              <p className="py-4 sm:py-6 text-base sm:text-lg opacity-80">
                {isSingleAssetType
                  ? `You haven't registered any ${activeRegistries[0].pluralName.toLowerCase()} yet.`
                  : "You haven't registered any assets yet. Register an asset to start tokenizing and earning revenue."}
              </p>
              <div className="flex justify-center">
                <button
                  className="btn btn-primary sm:btn-lg rounded-r-none border-r-base-100"
                  onClick={() => {
                    setIsRegisterOpen(true);
                    setRegisterMode("REGISTER_AND_MINT");
                  }}
                >
                  Get Started
                </button>
                <div className="dropdown dropdown-end">
                  <div
                    tabIndex={0}
                    role="button"
                    className="btn btn-primary sm:btn-lg rounded-l-none px-2 sm:px-3 min-h-0 h-full"
                  >
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
        </div>
      ) : (
        <div className="flex flex-col gap-8 sm:gap-12">
          {/* GENERATING REVENUE - Tokens sold, earning revenue */}
          {activeFleet.length > 0 && (filterState === "ALL" || filterState === "ACTIVE_FLEET") && (
            <Section
              title="Generating Revenue"
              count={activeFleet.length}
              badgeClass="badge-success"
              borderClass="border-success/30"
            >
              {activeFleet.map(asset => (
                <AssetCard
                  key={asset.id}
                  asset={asset}
                  borderColor="border-success"
                  primaryAction={{
                    label: "Distribute Earnings",
                    onClick: () => {
                      setSelectedCategorizedAsset(asset);
                      setDistributeEarningsModalOpen(true);
                    },
                    className: "btn btn-success text-white",
                  }}
                  secondaryAction={{
                    label: "Settle Asset",
                    onClick: () => {
                      setSelectedCategorizedAsset(asset);
                      setSettleAssetModalOpen(true);
                    },
                  }}
                />
              ))}
            </Section>
          )}

          {/* LISTED FOR SALE - Listed on marketplace */}
          {activeListingsAssets.length > 0 && (filterState === "ALL" || filterState === "ACTIVE_LISTINGS") && (
            <Section
              title="Listed for Sale"
              count={activeListingsAssets.length}
              badgeClass="badge-info"
              borderClass="border-info/30"
            >
              {activeListingsAssets.map(asset => (
                <AssetCard
                  key={asset.id}
                  asset={asset}
                  borderColor="border-info"
                  primaryAction={{
                    label: "Extend Listing",
                    onClick: () => {
                      setSelectedCategorizedAsset(asset);
                      if (asset.listings && asset.listings.length > 0) {
                        setSelectedListing(asset.listings[0]);
                      }
                      setExtendListingModalOpen(true);
                    },
                    className: "btn btn-info text-white",
                  }}
                  secondaryAction={{
                    label: "End Listing",
                    onClick: () => {
                      setSelectedCategorizedAsset(asset);
                      if (asset.listings && asset.listings.length > 0) {
                        setSelectedListing(asset.listings[0]);
                      }
                      setEndListingModalOpen(true);
                    },
                  }}
                />
              ))}
            </Section>
          )}

          {/* READY TO LIST - Tokenized but not listed */}
          {pendingListings.length > 0 && (filterState === "ALL" || filterState === "PENDING_LISTINGS") && (
            <Section
              title="Ready to List"
              count={pendingListings.length}
              badgeClass="badge-warning"
              borderClass="border-warning/30"
            >
              {pendingListings.map(asset => (
                <AssetCard
                  key={asset.id}
                  asset={asset}
                  borderColor="border-warning"
                  primaryAction={{
                    label: "List For Sale",
                    onClick: () => openListModal(asset),
                    className: "btn btn-warning",
                  }}
                />
              ))}
            </Section>
          )}

          {/* NEEDS SETUP - Registered but no tokens minted */}
          {pendingTokenization.length > 0 && (filterState === "ALL" || filterState === "PENDING_TOKENIZATION") && (
            <Section
              title="Needs Setup"
              count={pendingTokenization.length}
              badgeClass="badge-neutral"
              borderClass="border-neutral/30"
            >
              {pendingTokenization.map(asset => (
                <AssetCard
                  key={asset.id}
                  asset={asset}
                  borderColor="border-neutral"
                  primaryAction={{
                    label: "Mint Revenue Tokens",
                    onClick: () => openMintModal(asset),
                    className: "btn btn-neutral",
                  }}
                />
              ))}
            </Section>
          )}

          {/* SETTLED - Assets that have been retired or settled */}
          {settledAssets.length > 0 && (filterState === "ALL" || filterState === "SETTLED") && (
            <Section
              title="Settled Assets"
              count={settledAssets.length}
              badgeClass="badge-ghost"
              borderClass="border-base-300"
            >
              {settledAssets.map(asset => (
                <AssetCard key={asset.id} asset={asset} borderColor="border-base-300" />
              ))}
            </Section>
          )}
        </div>
      )}

      {/* Modals */}
      <RegisterAssetModal
        isOpen={isRegisterOpen}
        onClose={() => {
          setIsRegisterOpen(false);
          triggerRefresh();
        }}
        initialMode={registerMode}
      />

      {selectedAsset && selectedAsset.type === AssetType.VEHICLE && (
        <>
          <MintTokensModal
            isOpen={mintModalOpen}
            onClose={() => {
              setMintModalOpen(false);
              triggerRefresh();
            }}
            vehicleId={selectedAsset.id}
            vin={selectedAsset.vin || ""}
          />
          <ListVehicleModal
            isOpen={listModalOpen}
            onClose={() => {
              setListModalOpen(false);
              triggerRefresh();
            }}
            vehicleId={selectedAsset.id}
            vin={selectedAsset.vin || ""}
          />
        </>
      )}

      {/* New Lifecycle Modals */}
      {selectedCategorizedAsset && (
        <>
          <DistributeEarningsModal
            isOpen={distributeEarningsModalOpen}
            onClose={() => {
              setDistributeEarningsModalOpen(false);
              triggerRefresh();
            }}
            assetId={selectedCategorizedAsset.id}
            assetName={getAssetDisplayName(selectedCategorizedAsset)}
          />
          <SettleAssetModal
            isOpen={settleAssetModalOpen}
            onClose={() => {
              setSettleAssetModalOpen(false);
              triggerRefresh();
            }}
            assetId={selectedCategorizedAsset.id}
            assetName={getAssetDisplayName(selectedCategorizedAsset)}
          />
        </>
      )}

      {selectedListing && (
        <>
          <ExtendListingModal
            isOpen={extendListingModalOpen}
            onClose={() => {
              setExtendListingModalOpen(false);
              triggerRefresh();
            }}
            listingId={selectedListing.id}
            currentExpiresAt={BigInt(selectedListing.expiresAt)}
          />
          <EndListingModal
            isOpen={endListingModalOpen}
            onClose={() => {
              setEndListingModalOpen(false);
              triggerRefresh();
            }}
            listingId={selectedListing.id}
            tokenAmount={selectedListing.amount}
          />
        </>
      )}
    </div>
  );
};

export default PartnerDashboard;
