"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { NextPage } from "next";
import { useAccount, useChainId, useChains, useReadContracts } from "wagmi";
import { AdjustmentsHorizontalIcon, ArrowsUpDownIcon, BriefcaseIcon } from "@heroicons/react/24/outline";
import { BuyTokensModal } from "~~/components/markets/BuyTokensModal";
import { ClaimRefundModal } from "~~/components/markets/ClaimRefundModal";
import { ClaimTokensModal } from "~~/components/markets/ClaimTokensModal";
import { MarketAssetCard } from "~~/components/markets/MarketAssetCard";
import { ASSET_REGISTRIES, AssetType } from "~~/config/assetTypes";
import deployedContracts from "~~/contracts/deployedContracts";
import { fetchIpfsMetadata, ipfsToHttp } from "~~/utils/ipfsGateway";

// Types for subgraph data
interface SubgraphListing {
  id: string;
  tokenId: string;
  assetId: string;
  seller: string;
  amount: string;
  amountSold: string;
  pricePerToken: string;
  expiresAt: string;
  buyerPaysFee: boolean;
  status: string;
  isCancelled: boolean;
  isEnded: boolean;
  claimedAmount: string;
  refundedUSDC: string;
  createdAt: string;
}

interface SubgraphVehicle {
  id: string;
  partner: string;
  vin: string;
  make?: string;
  model?: string;
  year?: string;
  metadataURI?: string;
}

interface SubgraphToken {
  id: string;
  revenueTokenId: string;
  price: string;
  supply: string;
  maturityDate: string;
}

interface SubgraphAssetEarnings {
  id: string;
  assetId: string;
  totalEarnings: string;
  totalRevenue: string;
  distributionCount: string;
  firstDistributionAt: string;
  lastDistributionAt: string;
}

interface SubgraphPartner {
  id: string;
  name: string;
  address: string;
}

type SortOption = "apr_desc" | "apr_asc" | "earnings_desc" | "earnings_asc" | "newest" | "price_asc" | "price_desc";

// Protocol constants for APR calculation
const BENCHMARK_EARNINGS_BP = 1000n;
const BP_PRECISION = 10000n;

const MarketsPage: NextPage = () => {
  const { address } = useAccount();
  // State
  const [listings, setListings] = useState<SubgraphListing[]>([]);
  const [vehicles, setVehicles] = useState<SubgraphVehicle[]>([]);
  const [tokens, setTokens] = useState<SubgraphToken[]>([]);
  const [assetEarnings, setAssetEarnings] = useState<SubgraphAssetEarnings[]>([]);
  const [partners, setPartners] = useState<SubgraphPartner[]>([]);
  const [userListingIds, setUserListingIds] = useState<Set<string>>(new Set());
  const [recentPurchases, setRecentPurchases] = useState<Set<string>>(new Set());
  const [imageUrls, setImageUrls] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Filters & Sorting
  const [filterType, setFilterType] = useState<AssetType | "ALL">("ALL");
  const [sortBy, setSortBy] = useState<SortOption>("apr_desc");
  const [showOnlyHoldings, setShowOnlyHoldings] = useState(false);

  // Modal states
  const [selectedListing, setSelectedListing] = useState<SubgraphListing | null>(null);
  const [isBuyModalOpen, setIsBuyModalOpen] = useState(false);
  const [isClaimTokensOpen, setIsClaimTokensOpen] = useState(false);
  const [isClaimRefundOpen, setIsClaimRefundOpen] = useState(false);

  // Network info
  const chainId = useChainId();
  const chains = useChains();
  const currentChain = chains.find(c => c.id === chainId);
  const networkName = currentChain?.name || "Localhost";

  // Fetch data from subgraph
  const fetchData = useCallback(
    async (showLoading = true) => {
      if (showLoading) setLoading(true);
      setError(null);

      try {
        // Build query with optional user-specific part
        const userQueryPart = address
          ? `
        tokenTrades(where: { buyer: "${address.toLowerCase()}" }, first: 1000) {
          listingId
        }
      `
          : "";

        const response = await fetch("http://localhost:8000/subgraphs/name/roboshare/protocol", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            query: `
            query GetMarketListings {
              listings(first: 100, orderBy: createdAt, orderDirection: desc) {
                id
                tokenId
                assetId
                seller
                amount
                amountSold
                pricePerToken
                expiresAt
                buyerPaysFee
                status
                isCancelled
                isEnded
                claimedAmount
                refundedUSDC
                createdAt
              }
              vehicles(first: 100) {
                id
                partner
                vin
                make
                model
                year
                metadataURI
              }
              roboshareTokens(first: 100) {
                id
                revenueTokenId
                price
                supply
                maturityDate
              }
              partners(first: 100) {
                id
                name
                address
              }
              ${userQueryPart}
            }
          `,
          }),
        });

        if (!response.ok) {
          throw new Error(`Subgraph fetch failed: ${response.statusText}`);
        }

        const { data, errors } = await response.json();

        if (errors) {
          console.warn("Subgraph query warnings:", errors);
        }

        setListings(data?.listings || []);
        setVehicles(data?.vehicles || []);
        setTokens(data?.roboshareTokens || []);
        setAssetEarnings(data?.assetEarnings || []);
        setPartners(data?.partners || []);

        if (data?.tokenTrades) {
          const ids = new Set<string>(data.tokenTrades.map((t: any) => t.listingId));
          setUserListingIds(ids);
        } else {
          setUserListingIds(new Set());
        }
      } catch (e: any) {
        console.error("Error fetching market data:", e);
        setError(e.message || "Failed to fetch market data");
      } finally {
        if (showLoading) setLoading(false);
      }
    },
    [address],
  );

  // Initial fetch
  useEffect(() => {
    fetchData();
  }, [fetchData]);

  // Fetch Holdings (Escrow + Wallet) for "Your Holdings" filter
  const {
    data: holdingsData,
    isLoading: isLoadingHoldings,
    refetch: refetchHoldings,
  } = useReadContracts({
    contracts: listings.flatMap(l => [
      {
        address: deployedContracts[31337]?.Marketplace?.address,
        abi: deployedContracts[31337]?.Marketplace?.abi,
        functionName: "buyerTokens",
        args: [BigInt(l.id), address],
      },
      {
        address: deployedContracts[31337]?.RoboshareTokens?.address,
        abi: deployedContracts[31337]?.RoboshareTokens?.abi,
        functionName: "balanceOf",
        args: [address, BigInt(l.assetId) + 1n],
      },
    ]) as any,
    query: { enabled: !!address && listings.length > 0 && showOnlyHoldings },
  });

  // Extract listing IDs where user has tokens or escrow
  const userHoldingsIds = useMemo(() => {
    const ids = new Set<string>();
    if (holdingsData) {
      listings.forEach((listing, index) => {
        const escrowResult = holdingsData[index * 2];
        const walletResult = holdingsData[index * 2 + 1];

        const hasEscrow = escrowResult?.status === "success" && (escrowResult.result as bigint) > 0n;
        const hasWallet = walletResult?.status === "success" && (walletResult.result as bigint) > 0n;

        if (hasEscrow || hasWallet) {
          ids.add(listing.id);
        }
      });
    }
    return ids;
  }, [holdingsData, listings]);

  // Fetch IPFS images
  useEffect(() => {
    const fetchImages = async () => {
      const vehiclesWithMetadata = vehicles.filter(v => v.metadataURI && !imageUrls[v.id]);
      if (vehiclesWithMetadata.length === 0) return;

      const newImageUrls: Record<string, string> = { ...imageUrls };

      await Promise.all(
        vehiclesWithMetadata.map(async vehicle => {
          if (!vehicle.metadataURI) return;
          try {
            const metadata = await fetchIpfsMetadata(vehicle.metadataURI);
            if (metadata?.image) {
              newImageUrls[vehicle.id] = ipfsToHttp(metadata.image) || "";
            }
          } catch (err) {
            console.error(`Error fetching metadata for vehicle ${vehicle.id}:`, err);
          }
        }),
      );

      setImageUrls(newImageUrls);
    };

    fetchImages();
  }, [vehicles, imageUrls]);

  // Helper to calculate APR for sorting
  const calculateApr = useCallback(
    (assetId: string): number => {
      const tokenId = (BigInt(assetId) + 1n).toString();
      const token = tokens.find(t => t.revenueTokenId === tokenId);
      const earning = assetEarnings.find(e => e.assetId === assetId);

      if (!token) return Number(BENCHMARK_EARNINGS_BP) / 100;

      const tokenPrice = BigInt(token.price);
      const tokenSupply = BigInt(token.supply);
      const totalValue = tokenPrice * tokenSupply;

      if (earning && earning.firstDistributionAt !== "0" && totalValue > 0n) {
        const totalEarnings = BigInt(earning.totalEarnings);
        const firstDistAt = BigInt(earning.firstDistributionAt);
        const lastDistAt = BigInt(earning.lastDistributionAt);
        const duration = lastDistAt - firstDistAt;

        if (duration > 0n) {
          const secondsPerYear = 365n * 24n * 60n * 60n;
          const annualizedEarnings = (totalEarnings * secondsPerYear) / duration;
          const aprBps = (annualizedEarnings * BP_PRECISION) / totalValue;
          return Number(aprBps) / 100;
        }
      }

      return Number(BENCHMARK_EARNINGS_BP) / 100;
    },
    [tokens, assetEarnings],
  );

  // Filter and sort listings
  const displayListings = useMemo(() => {
    let filtered = [...listings];

    // Filter by asset type
    if (filterType !== "ALL") {
      if (filterType !== AssetType.VEHICLE) {
        filtered = [];
      }
    }

    // Filter by Holdings
    if (showOnlyHoldings) {
      filtered = filtered.filter(l => {
        // Include if user traded in this listing (subgraph)
        if (userListingIds.has(l.id)) return true;
        // Include if user recently purchased (optimistic)
        if (recentPurchases.has(l.id)) return true;
        // Include if user has tokens or escrow (contract state)
        if (userHoldingsIds.has(l.id)) return true;
        // Include if user is the seller
        if (address && l.seller.toLowerCase() === address.toLowerCase()) return true;
        return false;
      });
    }

    // Sort
    filtered.sort((a, b) => {
      switch (sortBy) {
        case "apr_desc":
          return calculateApr(b.assetId) - calculateApr(a.assetId);
        case "apr_asc":
          return calculateApr(a.assetId) - calculateApr(b.assetId);
        case "earnings_desc": {
          const earningsA = BigInt(assetEarnings.find(e => e.assetId === a.assetId)?.totalEarnings || "0");
          const earningsB = BigInt(assetEarnings.find(e => e.assetId === b.assetId)?.totalEarnings || "0");
          return earningsB > earningsA ? 1 : earningsB < earningsA ? -1 : 0;
        }
        case "earnings_asc": {
          const earningsA = BigInt(assetEarnings.find(e => e.assetId === a.assetId)?.totalEarnings || "0");
          const earningsB = BigInt(assetEarnings.find(e => e.assetId === b.assetId)?.totalEarnings || "0");
          return earningsA > earningsB ? 1 : earningsA < earningsB ? -1 : 0;
        }
        case "newest":
          return Number(b.createdAt) - Number(a.createdAt);
        case "price_asc":
          return Number(a.pricePerToken) - Number(b.pricePerToken);
        case "price_desc":
          return Number(b.pricePerToken) - Number(a.pricePerToken);
        default:
          return 0;
      }
    });

    return filtered;
  }, [
    listings,
    filterType,
    sortBy,
    assetEarnings,
    calculateApr,
    showOnlyHoldings,
    userListingIds,
    recentPurchases,
    userHoldingsIds,
    address,
  ]);

  // Get active registries for filter tabs
  const activeRegistries = Object.entries(ASSET_REGISTRIES).filter(([, r]) => r.active);

  return (
    <div className="flex flex-col gap-8 py-8 px-4 sm:px-6 lg:px-8 w-full max-w-full lg:max-w-[75%] 2xl:max-w-[80%] mx-auto overflow-x-hidden">
      {/* Header */}
      <div className="flex flex-col gap-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div>
            <h1 className="text-3xl lg:text-4xl font-bold">Explore Markets</h1>
            <p className="text-lg opacity-70 mt-2">Discover and invest in tokenized real-world assets</p>
          </div>

          {/* Network Badge */}
          <div className="flex items-center gap-2">
            <span className="badge badge-lg badge-outline gap-2">
              <span className="w-2 h-2 rounded-full bg-success animate-pulse"></span>
              {networkName}
            </span>
          </div>
        </div>

        {/* Filters & Sort */}
        <div className="flex flex-col lg:flex-row lg:items-center gap-4 p-4 bg-base-200 rounded-xl overflow-hidden">
          {/* Asset Type Filter */}
          <div className="flex items-center gap-3 min-w-0">
            <AdjustmentsHorizontalIcon className="w-5 h-5 opacity-50 shrink-0" />
            <div className="flex bg-base-100 rounded-lg p-1 gap-1 overflow-x-auto scrollbar-hide">
              <button
                className={`btn btn-sm shrink-0 ${filterType === "ALL" ? "btn-primary" : "btn-ghost"}`}
                onClick={() => setFilterType("ALL")}
              >
                All Markets
              </button>
              {activeRegistries.map(([key, registry]) => (
                <button
                  key={key}
                  className={`btn btn-sm shrink-0 ${filterType === key ? "btn-primary" : "btn-ghost"}`}
                  onClick={() => setFilterType(key as AssetType)}
                >
                  {registry.icon} {registry.pluralName}
                </button>
              ))}
            </div>
          </div>

          {/* Spacer */}
          <div className="flex-1" />

          {/* Right Side Controls */}
          <div className="flex items-center gap-4">
            {/* Holdings Toggle */}
            <div className="flex items-center gap-3">
              <BriefcaseIcon className="w-5 h-5 opacity-50" />
              <label className="label cursor-pointer gap-2 bg-base-100 px-3 py-1.5 rounded-lg border border-base-200 hover:border-base-300 transition-colors h-8">
                <input
                  type="checkbox"
                  className="checkbox checkbox-xs checkbox-primary"
                  checked={showOnlyHoldings}
                  onChange={e => setShowOnlyHoldings(e.target.checked)}
                />
                <span className="label-text text-sm font-medium">Your Holdings</span>
              </label>
            </div>

            {/* Sort Dropdown */}
            <div className="flex items-center gap-3">
              <ArrowsUpDownIcon className="w-5 h-5 opacity-50" />
              <select
                className="select select-bordered select-sm bg-base-100"
                value={sortBy}
                onChange={e => setSortBy(e.target.value as SortOption)}
              >
                <option value="apr_desc">Highest APR</option>
                <option value="apr_asc">Lowest APR</option>
                <option value="earnings_desc">Most Earnings</option>
                <option value="earnings_asc">Least Earnings</option>
                <option value="newest">Newest</option>
                <option value="price_asc">Lowest Price</option>
                <option value="price_desc">Highest Price</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      {/* Content */}
      {loading || (showOnlyHoldings && isLoadingHoldings) ? (
        <div className="flex justify-center py-20">
          <span className="loading loading-spinner loading-lg text-primary"></span>
        </div>
      ) : error ? (
        <div className="alert alert-error">
          <span>{error}</span>
        </div>
      ) : displayListings.length === 0 ? (
        <div className="hero bg-base-200 rounded-2xl py-16">
          <div className="hero-content text-center">
            <div className="max-w-md">
              <h2 className="text-2xl font-bold">No Listings Found</h2>
              <p className="py-4 opacity-70">There are currently no assets matching your filters. Check back soon!</p>
            </div>
          </div>
        </div>
      ) : (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-4 gap-6">
          {displayListings.map(listing => {
            const vehicle = vehicles.find(v => v.id === listing.assetId);
            const tokenId = (BigInt(listing.assetId) + 1n).toString();
            const token = tokens.find(t => t.revenueTokenId === tokenId);
            const earning = assetEarnings.find(e => e.assetId === listing.assetId);
            const partner = vehicle
              ? partners.find(p => p.address.toLowerCase() === vehicle.partner.toLowerCase())
              : undefined;

            return (
              <MarketAssetCard
                key={listing.id}
                listing={listing}
                vehicle={vehicle}
                token={token}
                earnings={earning}
                partner={partner}
                imageUrl={vehicle?.id ? imageUrls[vehicle.id] : undefined}
                networkName={networkName}
                assetType={AssetType.VEHICLE}
                onBuyClick={() => {
                  setSelectedListing(listing);
                  setIsBuyModalOpen(true);
                }}
                onClaimTokensClick={() => {
                  setSelectedListing(listing);
                  setIsClaimTokensOpen(true);
                }}
                onClaimRefundClick={() => {
                  setSelectedListing(listing);
                  setIsClaimRefundOpen(true);
                }}
              />
            );
          })}
        </div>
      )}

      {/* Stats Footer */}
      {!loading && !error && displayListings.length > 0 && (
        <div className="stats shadow bg-base-200 w-full">
          <div className="stat">
            <div className="stat-title">{showOnlyHoldings ? "Your Holdings" : "Market Listings"}</div>
            <div className="stat-value text-success">{displayListings.length}</div>
          </div>
          <div className="stat">
            <div className="stat-title">Total Assets</div>
            <div className="stat-value">{vehicles.length}</div>
          </div>
          <div className="stat">
            <div className="stat-title">Partners</div>
            <div className="stat-value">{partners.length}</div>
          </div>
        </div>
      )}

      {/* Buy Tokens Modal */}
      {selectedListing && (
        <BuyTokensModal
          isOpen={isBuyModalOpen}
          onClose={() => {
            setIsBuyModalOpen(false);
            setSelectedListing(null);
            // Refresh data to update cards with any changes
            fetchData(false);
          }}
          onPurchaseComplete={listingId => {
            if (listingId) {
              setRecentPurchases(prev => new Set(prev).add(listingId));
            }
            // Refetch data after purchase (without showing loading spinner)
            fetchData(false);
          }}
          listing={selectedListing}
          vehicleName={(() => {
            const vehicle = vehicles.find(v => v.id === selectedListing.assetId);
            if (vehicle?.make && vehicle?.model && vehicle?.year) {
              return `${vehicle.year} ${vehicle.make} ${vehicle.model}`;
            }
            return `Asset #${selectedListing.assetId}`;
          })()}
          partnerName={(() => {
            const vehicle = vehicles.find(v => v.id === selectedListing.assetId);
            if (vehicle) {
              const partner = partners.find(p => p.address.toLowerCase() === vehicle.partner.toLowerCase());
              return partner?.name;
            }
            return undefined;
          })()}
          totalSupply={(() => {
            const tokenId = (BigInt(selectedListing.assetId) + 1n).toString();
            const token = tokens.find(t => t.revenueTokenId === tokenId);
            return token?.supply;
          })()}
        />
      )}

      {/* Claim Modals */}
      {selectedListing && (
        <>
          <ClaimTokensModal
            isOpen={isClaimTokensOpen}
            onClose={() => {
              setIsClaimTokensOpen(false);
              setSelectedListing(null);
              fetchData(false);
              refetchHoldings();
            }}
            listingId={selectedListing.id}
            tokenAmount={(() => {
              // Note: MarketAssetCard reads actual escrowed amount from contract
              // Here we just pass a placeholder or we could fetch it.
              // For better UX, we'll let the modal fetch it or pass it if we had it.
              // Actually, the modal should read it from contract.
              // But I defined the modal to take `tokenAmount` as prop.
              // I'll update the modal to read it internally.
              return "0"; // Modal will fetch
            })()}
            vehicleName={(() => {
              const vehicle = vehicles.find(v => v.id === selectedListing.assetId);
              return vehicle ? `${vehicle.year} ${vehicle.make} ${vehicle.model}` : `Asset #${selectedListing.assetId}`;
            })()}
          />
          <ClaimRefundModal
            isOpen={isClaimRefundOpen}
            onClose={() => {
              setIsClaimRefundOpen(false);
              setSelectedListing(null);
              fetchData(false);
              refetchHoldings();
            }}
            listingId={selectedListing.id}
            refundAmount="0" // Modal will fetch
            vehicleName={(() => {
              const vehicle = vehicles.find(v => v.id === selectedListing.assetId);
              return vehicle ? `${vehicle.year} ${vehicle.make} ${vehicle.model}` : `Asset #${selectedListing.assetId}`;
            })()}
          />
        </>
      )}
    </div>
  );
};

export default MarketsPage;
