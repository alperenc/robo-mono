"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { NextPage } from "next";
import { useAccount, useChainId, useChains, useReadContracts, useSwitchChain } from "wagmi";
import {
  AdjustmentsHorizontalIcon,
  ArrowsUpDownIcon,
  Bars4Icon,
  BriefcaseIcon,
  Squares2X2Icon,
} from "@heroicons/react/24/outline";
import { AcquirePositionModal } from "~~/components/markets/AcquirePositionModal";
import { ClaimEarningsModal } from "~~/components/markets/ClaimEarningsModal";
import { ClaimSettlementModal } from "~~/components/markets/ClaimSettlementModal";
import { MarketAssetCard } from "~~/components/markets/MarketAssetCard";
import { PrimaryPoolCard } from "~~/components/markets/PrimaryPoolCard";
import { RedeemLiquidityModal } from "~~/components/markets/RedeemLiquidityModal";
import { CreateSecondaryListingModal } from "~~/components/partner/CreateSecondaryListingModal";
import { DistributeEarningsModal } from "~~/components/partner/DistributeEarningsModal";
import { EndSecondaryListingModal } from "~~/components/partner/EndSecondaryListingModal";
import { SettleAssetModal } from "~~/components/partner/SettleAssetModal";
import { ASSET_REGISTRIES, AssetType } from "~~/config/assetTypes";
import deployedContracts from "~~/contracts/deployedContracts";
import { fetchIpfsMetadata, ipfsToHttp } from "~~/utils/ipfsGateway";
import { getTargetNetworks } from "~~/utils/scaffold-eth";

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
  isPrimary: boolean;
  status: string;
  isEnded: boolean;
  endedAt?: string | null;
  createdAt: string;
}

interface SubgraphPrimaryPool {
  id: string;
  tokenId: string;
  assetId: string;
  partner: string;
  pricePerToken: string;
  maxSupply: string;
  immediateProceeds: boolean;
  protectionEnabled: boolean;
  isPaused: boolean;
  isClosed: boolean;
  createdAt: string;
  pausedAt?: string | null;
  closedAt?: string | null;
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
  targetYieldBP?: string;
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
type MarketTab = "pools" | "secondary";

// Protocol constants for APY calculation/sorting
const BENCHMARK_EARNINGS_BP = 1000n;
const BP_PRECISION = 10000n;

const MarketsPage: NextPage = () => {
  const { address } = useAccount();
  // State
  const [listings, setListings] = useState<SubgraphListing[]>([]);
  const [primaryPools, setPrimaryPools] = useState<SubgraphPrimaryPool[]>([]);
  const [vehicles, setVehicles] = useState<SubgraphVehicle[]>([]);
  const [tokens, setTokens] = useState<SubgraphToken[]>([]);
  const [assetEarnings, setAssetEarnings] = useState<SubgraphAssetEarnings[]>([]);
  const [partners, setPartners] = useState<SubgraphPartner[]>([]);
  const [userListingIds, setUserListingIds] = useState<Set<string>>(new Set());
  const [recentPurchases, setRecentPurchases] = useState<Set<string>>(new Set());
  const [soldOutAtByListing, setSoldOutAtByListing] = useState<Record<string, string>>({});
  const [imageUrls, setImageUrls] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Filters & Sorting
  const [filterType, setFilterType] = useState<AssetType | "ALL">("ALL");
  const [sortBy, setSortBy] = useState<SortOption>("apr_desc");
  const [showOnlyHoldings, setShowOnlyHoldings] = useState(false);
  const [viewMode, setViewMode] = useState<"list" | "grid">("grid");
  const [marketTab, setMarketTab] = useState<MarketTab>("pools");

  useEffect(() => {
    const enforceGridOnMobile = () => {
      if (window.innerWidth < 1024) {
        setViewMode("grid");
      }
    };

    enforceGridOnMobile();
    window.addEventListener("resize", enforceGridOnMobile);
    return () => window.removeEventListener("resize", enforceGridOnMobile);
  }, []);

  // Modal states
  const [selectedListing, setSelectedListing] = useState<SubgraphListing | null>(null);
  const [selectedPool, setSelectedPool] = useState<SubgraphPrimaryPool | null>(null);
  const [selectedRedeemPool, setSelectedRedeemPool] = useState<SubgraphPrimaryPool | null>(null);
  const [isBuyModalOpen, setIsBuyModalOpen] = useState(false);
  const [isClaimEarningsOpen, setIsClaimEarningsOpen] = useState(false);
  const [isClaimSettlementOpen, setIsClaimSettlementOpen] = useState(false);
  const [isListTokensOpen, setIsListTokensOpen] = useState(false);
  const [isEndListingOpen, setIsEndListingOpen] = useState(false);
  const [isDistributeEarningsOpen, setIsDistributeEarningsOpen] = useState(false);
  const [isSettleAssetOpen, setIsSettleAssetOpen] = useState(false);
  const [prefillListAmount, setPrefillListAmount] = useState<string | undefined>(undefined);

  // Network info
  const chainId = useChainId();
  const chains = useChains();
  const currentChain = chains.find(c => c.id === chainId);
  const networkName = currentChain?.name || "Localhost";
  const { switchChain } = useSwitchChain();
  const targetNetworks = getTargetNetworks();

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
            query GetMarketsPageData {
              listings(first: 100, orderBy: createdAt, orderDirection: desc) {
                id
                tokenId
                assetId
                seller
                isPrimary
                amount
                amountSold
                pricePerToken
                expiresAt
                buyerPaysFee
                status
                isEnded
                endedAt
                createdAt
              }
              primaryPools(first: 100, orderBy: createdAt, orderDirection: desc) {
                id
                tokenId
                assetId
                partner
                pricePerToken
                maxSupply
                immediateProceeds
                protectionEnabled
                isPaused
                isClosed
                createdAt
                pausedAt
                closedAt
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
                targetYieldBP
                maturityDate
              }
              partners(first: 100) {
                id
                name
                address
              }
              assetEarnings(first: 100) {
                id
                assetId
                totalRevenue
                totalEarnings
                distributionCount
                firstDistributionAt
                lastDistributionAt
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

        setListings(prev => {
          const incoming = (data?.listings || []) as SubgraphListing[];
          const prevById = new Map(prev.map(l => [l.id, l]));
          return incoming.map(listing => {
            const prevListing = prevById.get(listing.id);
            if (!prevListing) return listing;

            // Protect optimistic terminal transitions from stale subgraph snapshots.
            const hasOptimisticTerminal = prevListing.isEnded;
            const incomingIsTerminal = listing.isEnded;
            if (hasOptimisticTerminal && !incomingIsTerminal) {
              return {
                ...listing,
                isEnded: prevListing.isEnded,
                status: prevListing.status,
              };
            }
            return listing;
          });
        });
        setVehicles(data?.vehicles || []);
        setPrimaryPools(data?.primaryPools || []);
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

  // Fetch Holdings (Escrow + Wallet) for "Your Holdings" filter
  const {
    data: holdingsData,
    isLoading: isLoadingHoldings,
    refetch: refetchHoldings,
  } = useReadContracts({
    contracts: listings.map(l => ({
      address: deployedContracts[31337]?.RoboshareTokens?.address,
      abi: deployedContracts[31337]?.RoboshareTokens?.abi,
      functionName: "balanceOf",
      args: [address, BigInt(l.tokenId)],
    })) as any,
    // Also used for action-priority sorting and CTA visibility heuristics, not just the holdings-only filter.
    query: { enabled: !!address && listings.length > 0 },
  });

  const {
    data: primaryPoolHoldingsData,
    isLoading: isLoadingPrimaryPoolHoldings,
    refetch: refetchPrimaryPoolHoldings,
  } = useReadContracts({
    contracts: primaryPools.map(pool => ({
      address: deployedContracts[31337]?.RoboshareTokens?.address,
      abi: deployedContracts[31337]?.RoboshareTokens?.abi,
      functionName: "balanceOf",
      args: [address, BigInt(pool.tokenId)],
    })) as any,
    query: { enabled: !!address && primaryPools.length > 0 },
  });

  const {
    data: primaryPoolSupplyData,
    isLoading: isLoadingPrimaryPoolSupply,
    refetch: refetchPrimaryPoolSupply,
  } = useReadContracts({
    contracts: primaryPools.map(pool => ({
      address: deployedContracts[31337]?.RoboshareTokens?.address,
      abi: deployedContracts[31337]?.RoboshareTokens?.abi,
      functionName: "getRevenueTokenSupply",
      args: [BigInt(pool.tokenId)],
    })) as any,
    query: { enabled: primaryPools.length > 0 },
  });

  const { data: primaryPoolRedemptionPreviewData, refetch: refetchPrimaryPoolRedemptionPreviews } = useReadContracts({
    allowFailure: true,
    contracts: primaryPools.map((pool, index) => {
      const holdingResult = primaryPoolHoldingsData?.[index];
      const holding =
        holdingResult?.status === "success" && holdingResult.result !== undefined
          ? (holdingResult.result as bigint)
          : 0n;
      return {
        address: deployedContracts[31337]?.Marketplace?.address,
        abi: deployedContracts[31337]?.Marketplace?.abi,
        functionName: "previewPrimaryRedemption",
        args: [BigInt(pool.tokenId), holding > 0n ? holding : 1n],
      };
    }) as any,
    query: { enabled: !!address && primaryPools.length > 0 && !!primaryPoolHoldingsData },
  });

  // Fetch actionability previews (claimable earnings/settlement) for sorting heuristics.
  const uniqueAssetIds = useMemo(() => {
    return Array.from(new Set(listings.map(l => l.assetId)));
  }, [listings]);

  const { data: actionPreviewData } = useReadContracts({
    allowFailure: true,
    contracts: uniqueAssetIds.flatMap(assetId => [
      {
        address: deployedContracts[31337]?.Treasury?.address,
        abi: deployedContracts[31337]?.Treasury?.abi,
        functionName: "previewClaimEarnings",
        args: [BigInt(assetId), address],
      },
      {
        address: deployedContracts[31337]?.Treasury?.address,
        abi: deployedContracts[31337]?.Treasury?.abi,
        functionName: "previewSettlementClaim",
        args: [BigInt(assetId), address],
      },
    ]) as any,
    query: { enabled: !!address && uniqueAssetIds.length > 0 },
  });
  const { data: assetStatusPreviewData } = useReadContracts({
    allowFailure: true,
    contracts: uniqueAssetIds.map(assetId => ({
      address: deployedContracts[31337]?.RegistryRouter?.address,
      abi: deployedContracts[31337]?.RegistryRouter?.abi,
      functionName: "getAssetStatus",
      args: [BigInt(assetId)],
    })) as any,
    query: { enabled: uniqueAssetIds.length > 0 },
  });

  // Initial fetch
  useEffect(() => {
    fetchData();
  }, [fetchData]);

  useEffect(() => {
    if (listings.length === 0) return;
    setSoldOutAtByListing(prev => {
      const next = { ...prev };
      let changed = false;
      const nowSec = Math.floor(Date.now() / 1000).toString();
      for (const listing of listings) {
        const isActive = !listing.isEnded && listing.status !== "expired";
        const isSoldOut = listing.amount === "0";
        if (isActive && isSoldOut && !next[listing.id]) {
          next[listing.id] = nowSec;
          changed = true;
        }
      }
      return changed ? next : prev;
    });
  }, [listings]);

  // Reset user-specific filters when the account changes
  useEffect(() => {
    setUserListingIds(new Set());
    setRecentPurchases(new Set());
  }, [address]);

  // Refetch holdings when the account or holdings filter changes
  useEffect(() => {
    if (showOnlyHoldings && address) {
      refetchHoldings?.();
    }
  }, [address, showOnlyHoldings, refetchHoldings]);

  // Extract listing IDs where user has tokens or escrow
  const userHoldingsIds = useMemo(() => {
    const ids = new Set<string>();
    if (holdingsData) {
      listings.forEach((listing, index) => {
        const walletResult = holdingsData[index];
        const hasWallet = walletResult?.status === "success" && (walletResult.result as bigint) > 0n;
        if (hasWallet) {
          ids.add(listing.id);
        }
      });
    }
    return ids;
  }, [holdingsData, listings]);

  const userPrimaryPoolTokenIds = useMemo(() => {
    const ids = new Set<string>();
    if (!primaryPoolHoldingsData) return ids;
    primaryPools.forEach((pool, index) => {
      const result = primaryPoolHoldingsData[index];
      const hasWallet = result?.status === "success" && (result.result as bigint) > 0n;
      if (hasWallet) ids.add(pool.tokenId);
    });
    return ids;
  }, [primaryPoolHoldingsData, primaryPools]);

  const primaryPoolSupplyByTokenId = useMemo(() => {
    const byTokenId = new Map<string, string>();
    primaryPools.forEach((pool, index) => {
      const result = primaryPoolSupplyData?.[index];
      const currentSupply =
        result?.status === "success" && result.result !== undefined ? String(result.result as bigint) : "0";
      byTokenId.set(pool.tokenId, currentSupply);
    });
    return byTokenId;
  }, [primaryPools, primaryPoolSupplyData]);

  const primaryPoolHoldingsByTokenId = useMemo(() => {
    const byTokenId = new Map<string, bigint>();
    primaryPools.forEach((pool, index) => {
      const result = primaryPoolHoldingsData?.[index];
      const holding = result?.status === "success" && result.result !== undefined ? (result.result as bigint) : 0n;
      byTokenId.set(pool.tokenId, holding);
    });
    return byTokenId;
  }, [primaryPools, primaryPoolHoldingsData]);

  const primaryPoolRedemptionByTokenId = useMemo(() => {
    const byTokenId = new Map<string, { payout: bigint; liquidity: bigint; circulatingSupply: bigint }>();
    primaryPools.forEach((pool, index) => {
      const result = primaryPoolRedemptionPreviewData?.[index];
      if (result?.status !== "success" || !Array.isArray(result.result)) {
        byTokenId.set(pool.tokenId, { payout: 0n, liquidity: 0n, circulatingSupply: 0n });
        return;
      }
      const [payout, liquidity, circulatingSupply] = result.result as [bigint, bigint, bigint];
      byTokenId.set(pool.tokenId, { payout, liquidity, circulatingSupply });
    });
    return byTokenId;
  }, [primaryPools, primaryPoolRedemptionPreviewData]);

  const assetActionPreview = useMemo(() => {
    const byAssetId = new Map<string, { claimableEarnings: bigint; claimableSettlement: bigint }>();
    if (!actionPreviewData) return byAssetId;

    uniqueAssetIds.forEach((assetId, index) => {
      const earningsResult = actionPreviewData[index * 2];
      const settlementResult = actionPreviewData[index * 2 + 1];
      const claimableEarnings =
        earningsResult?.status === "success" ? ((earningsResult.result as bigint | undefined) ?? 0n) : 0n;
      const claimableSettlement =
        settlementResult?.status === "success" ? ((settlementResult.result as bigint | undefined) ?? 0n) : 0n;
      byAssetId.set(assetId, { claimableEarnings, claimableSettlement });
    });

    return byAssetId;
  }, [actionPreviewData, uniqueAssetIds]);

  const assetStatusById = useMemo(() => {
    const byAssetId = new Map<string, number>();
    if (!assetStatusPreviewData) return byAssetId;

    uniqueAssetIds.forEach((assetId, index) => {
      const result = assetStatusPreviewData[index];
      const status =
        result?.status === "success" && result.result !== undefined ? Number(result.result as bigint | number) : -1;
      byAssetId.set(assetId, status);
    });

    return byAssetId;
  }, [assetStatusPreviewData, uniqueAssetIds]);

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

  const tokenSoldTotals = useMemo(() => {
    const totals = new Map<string, bigint>();
    for (const listing of listings) {
      const sold = listing.amountSold ? BigInt(listing.amountSold) : 0n;
      if (sold <= 0n) continue;
      totals.set(listing.tokenId, (totals.get(listing.tokenId) ?? 0n) + sold);
    }
    return totals;
  }, [listings]);

  // Helper to calculate listing APY for sorting (match card display logic)
  const calculateListingApy = useCallback(
    (listing: SubgraphListing): number => {
      const token = tokens.find(t => t.revenueTokenId === listing.tokenId);
      const earning = assetEarnings.find(e => e.assetId === listing.assetId);

      if (!token) return Number(BENCHMARK_EARNINGS_BP) / 100;

      const listingSoldAmount =
        listing.amountSold && listing.amountSold !== "0"
          ? BigInt(listing.amountSold)
          : (() => {
              const derived = BigInt(token.supply) - BigInt(listing.amount);
              return derived > 0n ? derived : 0n;
            })();

      const soldSupplyForAllocation = tokenSoldTotals.get(listing.tokenId) ?? listingSoldAmount;
      const listingActualEarnings =
        !earning || earning.totalEarnings === "0" || listingSoldAmount <= 0n || soldSupplyForAllocation <= 0n
          ? 0n
          : (BigInt(earning.totalEarnings) * listingSoldAmount) / soldSupplyForAllocation;

      const tokenPrice = BigInt(token.price);
      const principalAmount = listingSoldAmount > 0n ? listingSoldAmount : BigInt(listing.amount);
      const totalValue = tokenPrice * principalAmount;

      if (earning && listingActualEarnings > 0n && totalValue > 0n) {
        const listingEndedAtOnChain = BigInt(listing.endedAt || "0");
        const lastDistAt = BigInt(earning.lastDistributionAt || "0");
        const duration =
          listingEndedAtOnChain > 0n && lastDistAt > listingEndedAtOnChain ? lastDistAt - listingEndedAtOnChain : 0n;

        if (duration > 0n) {
          const secondsPerYear = 365n * 24n * 60n * 60n;
          const annualizedEarnings = (listingActualEarnings * secondsPerYear) / duration;
          const aprBps = (annualizedEarnings * BP_PRECISION) / totalValue;
          return Number(aprBps) / 100;
        }
      }

      const targetYieldBp = token.targetYieldBP ? Number(token.targetYieldBP) : Number(BENCHMARK_EARNINGS_BP);
      return targetYieldBp / 100;
    },
    [tokens, assetEarnings, tokenSoldTotals],
  );

  const hasLikelyAction = useCallback(
    (listing: SubgraphListing): boolean => {
      // Generic actionable state for any user (e.g. buyable active listings).
      const isEndedOrExpired = listing.isEnded || listing.status === "expired";
      const hasAvailableTokens = BigInt(listing.amount) > 0n;
      if (!isEndedOrExpired && hasAvailableTokens) return true;

      if (!address) return false;

      const isSeller = listing.seller.toLowerCase() === address.toLowerCase();
      const hasBoughtListing = userListingIds.has(listing.id) || recentPurchases.has(listing.id);
      const hasTokensForListing = userHoldingsIds.has(listing.id);
      const preview = assetActionPreview.get(listing.assetId);
      const assetStatus = assetStatusById.get(listing.assetId) ?? -1;
      const isAssetSettled = assetStatus === 3 || assetStatus === 4;
      const hasClaimableEarnings = (preview?.claimableEarnings ?? 0n) > 0n;
      const hasClaimableSettlement = (preview?.claimableSettlement ?? 0n) > 0n;

      // Seller-managed listings are often actionable while the listing is live/expired.
      // Ended seller listings can still be actionable while the underlying asset remains unsettled
      // (e.g. Distribute Earnings / Settle Asset on primary listings).
      if (isSeller && (!listing.isEnded || !isAssetSettled)) return true;

      // Non-ended listings the user participated in often still expose actionable CTAs
      // (e.g. claim earnings on expired listings) even when generic availability is zero.
      if (!listing.isEnded && hasBoughtListing) return true;

      // Buyer/holder actions that the card can actually surface.
      if (hasBoughtListing && hasClaimableEarnings) return true;
      if (hasTokensForListing && hasClaimableSettlement) return true;

      // Conservative fallback: do not prioritize based on holdings/history alone.
      return false;
    },
    [address, assetActionPreview, assetStatusById, recentPurchases, userHoldingsIds, userListingIds],
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
      if (!address) return [];
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

    // Sort (active listings first)
    filtered.sort((a, b) => {
      // Surface listings that likely have user actions first.
      const aHasAction = hasLikelyAction(a);
      const bHasAction = hasLikelyAction(b);
      if (aHasAction !== bHasAction) return aHasAction ? -1 : 1;

      // Then prefer active listings over ended/expired listings.
      const aEndedOrExpired = a.isEnded || a.status === "expired";
      const bEndedOrExpired = b.isEnded || b.status === "expired";
      if (aEndedOrExpired !== bEndedOrExpired) return aEndedOrExpired ? 1 : -1;

      switch (sortBy) {
        case "apr_desc":
          return calculateListingApy(b) - calculateListingApy(a);
        case "apr_asc":
          return calculateListingApy(a) - calculateListingApy(b);
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
    calculateListingApy,
    showOnlyHoldings,
    userListingIds,
    recentPurchases,
    userHoldingsIds,
    address,
    hasLikelyAction,
  ]);

  const displayPrimaryPools = useMemo(() => {
    let filtered = [...primaryPools];

    if (filterType !== "ALL" && filterType !== AssetType.VEHICLE) {
      filtered = [];
    }

    if (showOnlyHoldings) {
      if (!address) return [];
      filtered = filtered.filter(pool => userPrimaryPoolTokenIds.has(pool.tokenId));
    }

    filtered.sort((a, b) => {
      switch (sortBy) {
        case "price_asc":
          return Number(a.pricePerToken) - Number(b.pricePerToken);
        case "price_desc":
          return Number(b.pricePerToken) - Number(a.pricePerToken);
        case "newest":
          return Number(b.createdAt) - Number(a.createdAt);
        case "apr_desc": {
          const aToken = tokens.find(t => t.revenueTokenId === a.tokenId);
          const bToken = tokens.find(t => t.revenueTokenId === b.tokenId);
          return (
            Number(bToken?.targetYieldBP || BENCHMARK_EARNINGS_BP) -
            Number(aToken?.targetYieldBP || BENCHMARK_EARNINGS_BP)
          );
        }
        case "apr_asc": {
          const aToken = tokens.find(t => t.revenueTokenId === a.tokenId);
          const bToken = tokens.find(t => t.revenueTokenId === b.tokenId);
          return (
            Number(aToken?.targetYieldBP || BENCHMARK_EARNINGS_BP) -
            Number(bToken?.targetYieldBP || BENCHMARK_EARNINGS_BP)
          );
        }
        case "earnings_desc":
        case "earnings_asc": {
          const aEarnings = BigInt(assetEarnings.find(e => e.assetId === a.assetId)?.totalEarnings || "0");
          const bEarnings = BigInt(assetEarnings.find(e => e.assetId === b.assetId)?.totalEarnings || "0");
          if (sortBy === "earnings_desc") return bEarnings > aEarnings ? 1 : bEarnings < aEarnings ? -1 : 0;
          return aEarnings > bEarnings ? 1 : aEarnings < bEarnings ? -1 : 0;
        }
        default:
          return 0;
      }
    });

    return filtered;
  }, [primaryPools, filterType, showOnlyHoldings, address, tokens, sortBy, assetEarnings, userPrimaryPoolTokenIds]);

  const sellerTokenIdCounts = useMemo(() => {
    const counts = new Map<string, number>();
    if (!address) return counts;
    const lower = address.toLowerCase();
    for (const listing of listings) {
      if (listing.seller.toLowerCase() !== lower) continue;
      counts.set(listing.tokenId, (counts.get(listing.tokenId) ?? 0) + 1);
    }
    return counts;
  }, [address, listings]);

  const activeSellerTokenIdCounts = useMemo(() => {
    const counts = new Map<string, number>();
    if (!address) return counts;
    const lower = address.toLowerCase();
    for (const listing of listings) {
      const isActive = !listing.isEnded && listing.status !== "expired";
      if (!isActive) continue;
      if (listing.seller.toLowerCase() !== lower) continue;
      counts.set(listing.tokenId, (counts.get(listing.tokenId) ?? 0) + 1);
    }
    return counts;
  }, [address, listings]);

  const poolUserActionStateByTokenId = useMemo(() => {
    const byTokenId = new Map<
      string,
      {
        primaryLabel: string;
        primaryDisabled: boolean;
        primaryAction: "buy" | "redeem" | "list" | null;
        secondaryActions: Array<{ label: string; action: "buy" | "redeem" | "list" }>;
      }
    >();

    for (const pool of primaryPools) {
      const currentSupply = BigInt(primaryPoolSupplyByTokenId.get(pool.tokenId) || "0");
      const maxSupply = BigInt(pool.maxSupply);
      const remainingSupply = maxSupply > currentSupply ? maxSupply - currentSupply : 0n;
      const holding = primaryPoolHoldingsByTokenId.get(pool.tokenId) ?? 0n;
      const hasHolding = holding > 0n;
      const hasActiveListing = (activeSellerTokenIdCounts.get(pool.tokenId) ?? 0) > 0;
      const redemption = primaryPoolRedemptionByTokenId.get(pool.tokenId) ?? {
        payout: 0n,
        liquidity: 0n,
        circulatingSupply: 0n,
      };
      const canRedeem = hasHolding && redemption.payout > 0n;
      const canAddMore = !pool.isClosed && !pool.isPaused && remainingSupply > 0n;
      const canList = hasHolding;

      if (canRedeem) {
        byTokenId.set(pool.tokenId, {
          primaryLabel: "Redeem Liquidity",
          primaryDisabled: false,
          primaryAction: "redeem",
          secondaryActions: [
            ...(canList
              ? [{ label: hasActiveListing ? "List More Tokens" : "List Tokens", action: "list" as const }]
              : []),
            ...(canAddMore ? [{ label: "Add More Liquidity", action: "buy" as const }] : []),
          ],
        });
        continue;
      }

      if (canList) {
        byTokenId.set(pool.tokenId, {
          primaryLabel: hasActiveListing ? "List More Tokens" : "List Tokens",
          primaryDisabled: false,
          primaryAction: "list",
          secondaryActions: [...(canAddMore ? [{ label: "Add More Liquidity", action: "buy" as const }] : [])],
        });
        continue;
      }

      byTokenId.set(pool.tokenId, {
        primaryLabel: "Add Liquidity",
        primaryDisabled: !canAddMore,
        primaryAction: canAddMore ? "buy" : null,
        secondaryActions: [],
      });
    }

    return byTokenId;
  }, [
    activeSellerTokenIdCounts,
    primaryPoolHoldingsByTokenId,
    primaryPoolRedemptionByTokenId,
    primaryPoolSupplyByTokenId,
    primaryPools,
  ]);

  const primarySellerTokenIdCounts = useMemo(() => {
    const counts = new Map<string, number>();
    if (!address) return counts;
    const lower = address.toLowerCase();
    for (const listing of listings) {
      if (!listing.isPrimary) continue;
      if (listing.seller.toLowerCase() !== lower) continue;
      counts.set(listing.tokenId, (counts.get(listing.tokenId) ?? 0) + 1);
    }
    return counts;
  }, [address, listings]);

  const refreshMarketsAfterSuccess = useCallback(
    (opts?: { skipImmediateFetch?: boolean }) => {
      if (!opts?.skipImmediateFetch) {
        fetchData(false);
      }
      refetchHoldings?.();
      // Subgraph/indexing can lag by a few seconds; retry refresh to reflect latest listing state.
      window.setTimeout(() => fetchData(false), 1200);
      window.setTimeout(() => fetchData(false), 3500);
      refetchPrimaryPoolHoldings?.();
      refetchPrimaryPoolSupply?.();
      refetchPrimaryPoolRedemptionPreviews?.();
    },
    [
      fetchData,
      refetchHoldings,
      refetchPrimaryPoolHoldings,
      refetchPrimaryPoolRedemptionPreviews,
      refetchPrimaryPoolSupply,
    ],
  );

  const applyListingActionSuccess = useCallback(
    (listingId: string, updates: Partial<SubgraphListing>) => {
      setListings(prev => prev.map(l => (l.id === listingId ? { ...l, ...updates } : l)));
      // Keep optimistic UI until indexers catch up; avoid immediate stale overwrite.
      refreshMarketsAfterSuccess({ skipImmediateFetch: true });
    },
    [refreshMarketsAfterSuccess],
  );

  // Get active registries for filter tabs
  const activeRegistries = Object.entries(ASSET_REGISTRIES).filter(([, r]) => r.active);

  return (
    <div className="flex flex-col gap-8 py-8 px-4 sm:px-6 lg:px-8 w-full max-w-full lg:max-w-[75%] 2xl:max-w-[80%] mx-auto overflow-x-hidden">
      {/* Header */}
      <div className="flex flex-col gap-4">
        <div>
          <div className="flex items-center gap-3">
            <h1 className="text-3xl lg:text-4xl font-bold">Explore Markets</h1>
            <div className="dropdown dropdown-end">
              <div
                tabIndex={0}
                role="button"
                className="flex items-center gap-2 text-sm opacity-70 px-2 py-1 rounded-full border border-base-300 hover:border-base-400 transition-colors"
              >
                <span className="w-2.5 h-2.5 rounded-full bg-success animate-pulse"></span>
                <span>{networkName}</span>
                <span className="ml-1">▾</span>
              </div>
              <ul tabIndex={0} className="dropdown-content z-[10] menu p-2 shadow bg-base-100 rounded-box w-56 mt-2">
                {targetNetworks
                  .filter(net => net.id !== chainId)
                  .map(net => (
                    <li key={net.id}>
                      <button
                        type="button"
                        className="menu-item btn-sm rounded-xl flex gap-3 py-3 whitespace-nowrap"
                        onClick={() => switchChain?.({ chainId: net.id })}
                      >
                        Switch to {net.name}
                      </button>
                    </li>
                  ))}
              </ul>
            </div>
          </div>
          <p className="text-lg opacity-70 mt-2">Discover and invest in tokenized real-world assets</p>
        </div>

        {/* Filters & Sort */}
        <div className="flex flex-col lg:flex-row lg:items-center gap-4 p-4 bg-base-200 rounded-xl overflow-hidden">
          <div className="flex items-center gap-3 min-w-0">
            <div className="flex bg-base-100 rounded-lg p-1 gap-1 overflow-x-auto scrollbar-hide">
              <button
                className={`btn btn-sm shrink-0 ${marketTab === "pools" ? "btn-primary" : "btn-ghost"}`}
                onClick={() => setMarketTab("pools")}
              >
                Pools
              </button>
              <button
                className={`btn btn-sm shrink-0 ${marketTab === "secondary" ? "btn-primary" : "btn-ghost"}`}
                onClick={() => setMarketTab("secondary")}
              >
                Secondary
              </button>
            </div>
          </div>

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
                <option value="apr_desc">Highest APY</option>
                <option value="apr_asc">Lowest APY</option>
                <option value="earnings_desc">Most Earnings</option>
                <option value="earnings_asc">Least Earnings</option>
                <option value="newest">Newest</option>
                <option value="price_asc">Lowest Price</option>
                <option value="price_desc">Highest Price</option>
              </select>
            </div>

            {/* View Mode Switcher - Hidden on mobile */}
            <div className="hidden lg:flex items-center gap-2 bg-base-100 p-1 rounded-lg border border-base-200">
              <button
                className={`btn btn-sm btn-square ${viewMode === "list" ? "btn-primary" : "btn-ghost"}`}
                onClick={() => setViewMode("list")}
                title="List View"
              >
                <Bars4Icon className="w-5 h-5" />
              </button>
              <button
                className={`btn btn-sm btn-square ${viewMode === "grid" ? "btn-primary" : "btn-ghost"}`}
                onClick={() => setViewMode("grid")}
                title="Grid View"
              >
                <Squares2X2Icon className="w-5 h-5" />
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Content */}
      {loading ||
      isLoadingPrimaryPoolSupply ||
      (showOnlyHoldings && (isLoadingHoldings || isLoadingPrimaryPoolHoldings)) ? (
        <div className="flex justify-center py-20">
          <span className="loading loading-spinner loading-lg text-primary"></span>
        </div>
      ) : error ? (
        <div className="alert alert-error">
          <span>{error}</span>
        </div>
      ) : marketTab === "pools" ? (
        displayPrimaryPools.length === 0 ? (
          <div className="hero bg-base-200 rounded-2xl py-16">
            <div className="hero-content text-center">
              <div className="max-w-md">
                <h2 className="text-2xl font-bold">No Pools Found</h2>
                <p className="py-4 opacity-70">There are currently no primary pools matching your filters.</p>
              </div>
            </div>
          </div>
        ) : (
          <div
            className={`grid gap-6 items-stretch ${
              viewMode === "grid" ? "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-4" : "grid-cols-1"
            }`}
          >
            {displayPrimaryPools.map(pool => {
              const vehicle = vehicles.find(v => v.id === pool.assetId);
              const token = tokens.find(t => t.revenueTokenId === pool.tokenId);
              const partner = partners.find(p => p.address.toLowerCase() === pool.partner.toLowerCase());

              return (
                <PrimaryPoolCard
                  key={pool.id}
                  pool={pool}
                  vehicle={vehicle}
                  token={
                    token
                      ? { ...token, supply: primaryPoolSupplyByTokenId.get(pool.tokenId) || token.supply }
                      : undefined
                  }
                  partner={partner}
                  imageUrl={vehicle?.id ? imageUrls[vehicle.id] : undefined}
                  viewMode={viewMode}
                  primaryActionLabel={poolUserActionStateByTokenId.get(pool.tokenId)?.primaryLabel || "Add Liquidity"}
                  primaryActionDisabled={poolUserActionStateByTokenId.get(pool.tokenId)?.primaryDisabled ?? true}
                  primaryActionOnClick={() => {
                    const action = poolUserActionStateByTokenId.get(pool.tokenId)?.primaryAction;
                    if (action === "redeem") {
                      setSelectedRedeemPool(pool);
                      setSelectedListing(null);
                      setSelectedPool(null);
                      return;
                    }
                    if (action === "list") {
                      setSelectedPool(pool);
                      setSelectedListing(null);
                      setPrefillListAmount((primaryPoolHoldingsByTokenId.get(pool.tokenId) ?? 0n).toString());
                      setIsListTokensOpen(true);
                      return;
                    }
                    if (action === "buy") {
                      setSelectedPool(pool);
                      setSelectedListing(null);
                      setIsBuyModalOpen(true);
                    }
                  }}
                  secondaryActions={(poolUserActionStateByTokenId.get(pool.tokenId)?.secondaryActions || []).map(
                    action => ({
                      label: action.label,
                      onClick: () => {
                        if (action.action === "redeem") {
                          setSelectedRedeemPool(pool);
                          setSelectedListing(null);
                          setSelectedPool(null);
                          return;
                        }
                        if (action.action === "list") {
                          setSelectedPool(pool);
                          setSelectedListing(null);
                          setPrefillListAmount((primaryPoolHoldingsByTokenId.get(pool.tokenId) ?? 0n).toString());
                          setIsListTokensOpen(true);
                          return;
                        }
                        setSelectedPool(pool);
                        setSelectedListing(null);
                        setIsBuyModalOpen(true);
                      },
                    }),
                  )}
                />
              );
            })}
          </div>
        )
      ) : displayListings.length === 0 ? (
        <div className="hero bg-base-200 rounded-2xl py-16">
          <div className="hero-content text-center">
            <div className="max-w-md">
              <h2 className="text-2xl font-bold">No Secondary Listings Found</h2>
              <p className="py-4 opacity-70">There are currently no secondary listings matching your filters.</p>
            </div>
          </div>
        </div>
      ) : (
        <div
          className={`grid gap-6 items-stretch ${
            viewMode === "grid" ? "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 2xl:grid-cols-4" : "grid-cols-1"
          }`}
        >
          {displayListings.map((listing, index) => {
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
                listing={{ ...listing, soldOutAt: soldOutAtByListing[listing.id] }}
                vehicle={vehicle}
                token={token}
                earnings={earning}
                partner={partner}
                imageUrl={vehicle?.id ? imageUrls[vehicle.id] : undefined}
                networkName={networkName}
                assetType={AssetType.VEHICLE}
                priority={index < 4}
                viewMode={viewMode}
                hasUserListingForTokenId={(sellerTokenIdCounts.get(listing.tokenId) ?? 0) > 0}
                hasUserActiveListingForTokenId={(activeSellerTokenIdCounts.get(listing.tokenId) ?? 0) > 0}
                hasUserPrimaryListingForTokenId={(primarySellerTokenIdCounts.get(listing.tokenId) ?? 0) > 0}
                hasUserBoughtListing={userListingIds.has(listing.id) || recentPurchases.has(listing.id)}
                tokenTotalSoldAmount={(tokenSoldTotals.get(listing.tokenId) ?? 0n).toString()}
                onBuyClick={() => {
                  setSelectedListing(listing);
                  setIsBuyModalOpen(true);
                }}
                onClaimEarningsClick={() => {
                  setSelectedListing(listing);
                  setIsClaimEarningsOpen(true);
                }}
                onClaimSettlementClick={() => {
                  setSelectedListing(listing);
                  setIsClaimSettlementOpen(true);
                }}
                onListTokensClick={amount => {
                  setSelectedListing(listing);
                  setPrefillListAmount(amount);
                  setIsListTokensOpen(true);
                }}
                onEndListingClick={() => {
                  setSelectedListing(listing);
                  setIsEndListingOpen(true);
                }}
                onDistributeEarningsClick={() => {
                  setSelectedListing(listing);
                  setIsDistributeEarningsOpen(true);
                }}
                onSettleAssetClick={() => {
                  setSelectedListing(listing);
                  setIsSettleAssetOpen(true);
                }}
              />
            );
          })}
        </div>
      )}

      {selectedRedeemPool && (
        <RedeemLiquidityModal
          isOpen={!!selectedRedeemPool}
          onSuccess={() => {
            refreshMarketsAfterSuccess();
          }}
          onClose={() => {
            setSelectedRedeemPool(null);
            refreshMarketsAfterSuccess();
          }}
          tokenId={selectedRedeemPool.tokenId}
          vehicleName={(() => {
            const vehicle = vehicles.find(v => v.id === selectedRedeemPool.assetId);
            return vehicle
              ? `${vehicle.year} ${vehicle.make} ${vehicle.model}`
              : `Asset #${selectedRedeemPool.assetId}`;
          })()}
          maxRedeemableAmount={(primaryPoolHoldingsByTokenId.get(selectedRedeemPool.tokenId) ?? 0n).toString()}
        />
      )}

      {/* Stats Footer */}
      {!loading && !error && (marketTab === "pools" ? displayPrimaryPools.length > 0 : displayListings.length > 0) && (
        <div className="stats shadow bg-base-200 w-full">
          <div className="stat">
            <div className="stat-title">
              {showOnlyHoldings ? "Your Holdings" : marketTab === "pools" ? "Primary Pools" : "Secondary Listings"}
            </div>
            <div className="stat-value text-success">
              {marketTab === "pools" ? displayPrimaryPools.length : displayListings.length}
            </div>
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
      {(selectedListing || selectedPool) && (
        <AcquirePositionModal
          isOpen={isBuyModalOpen}
          onClose={() => {
            setIsBuyModalOpen(false);
            setSelectedListing(null);
            setSelectedPool(null);
            // Refresh data to update cards with any changes
            fetchData(false);
            refetchHoldings?.();
            refetchPrimaryPoolHoldings?.();
            refetchPrimaryPoolSupply?.();
          }}
          onPurchaseComplete={id => {
            if (selectedListing && id) {
              setRecentPurchases(prev => new Set(prev).add(id));
            }
            // Refetch data after purchase (without showing loading spinner)
            fetchData(false);
            refetchHoldings?.();
            refetchPrimaryPoolHoldings?.();
            refetchPrimaryPoolSupply?.();
          }}
          purchaseTarget={
            selectedListing
              ? {
                  kind: "secondary" as const,
                  listing: selectedListing,
                }
              : {
                  kind: "primary" as const,
                  pool: selectedPool!,
                  currentSupply: primaryPoolSupplyByTokenId.get(selectedPool!.tokenId) || "0",
                }
          }
          listedTokens={(() => {
            if (!selectedListing || !address) return "0";
            const tokenId = selectedListing.tokenId;
            const sellerListings = listings.filter(l => {
              const isActive = !l.isEnded && l.status !== "expired";
              return isActive && l.tokenId === tokenId && l.seller.toLowerCase() === address.toLowerCase();
            });
            const total = sellerListings.reduce((sum, l) => sum + BigInt(l.amount), 0n);
            return total.toString();
          })()}
          vehicleName={(() => {
            const targetAssetId = selectedListing?.assetId || selectedPool?.assetId;
            const vehicle = targetAssetId ? vehicles.find(v => v.id === targetAssetId) : undefined;
            if (vehicle?.make && vehicle?.model && vehicle?.year) {
              return `${vehicle.year} ${vehicle.make} ${vehicle.model}`;
            }
            return `Asset #${targetAssetId}`;
          })()}
          partnerName={(() => {
            const targetAssetId = selectedListing?.assetId || selectedPool?.assetId;
            const vehicle = targetAssetId ? vehicles.find(v => v.id === targetAssetId) : undefined;
            if (vehicle) {
              const partner = partners.find(p => p.address.toLowerCase() === vehicle.partner.toLowerCase());
              return partner?.name;
            }
            return undefined;
          })()}
          totalSupply={(() => {
            if (selectedPool) return selectedPool.maxSupply;
            const tokenId = (BigInt(selectedListing!.assetId) + 1n).toString();
            const token = tokens.find(t => t.revenueTokenId === tokenId);
            return token?.supply;
          })()}
        />
      )}

      {/* Claim Modals */}
      {selectedListing && (
        <>
          <ClaimEarningsModal
            isOpen={isClaimEarningsOpen}
            onClose={() => {
              setIsClaimEarningsOpen(false);
              setSelectedListing(null);
              fetchData(false);
              refetchHoldings();
            }}
            assetId={selectedListing.assetId}
            vehicleName={(() => {
              const vehicle = vehicles.find(v => v.id === selectedListing.assetId);
              return vehicle ? `${vehicle.year} ${vehicle.make} ${vehicle.model}` : `Asset #${selectedListing.assetId}`;
            })()}
          />
          <ClaimSettlementModal
            isOpen={isClaimSettlementOpen}
            onClose={() => {
              setIsClaimSettlementOpen(false);
              setSelectedListing(null);
              fetchData(false);
              refetchHoldings();
            }}
            assetId={selectedListing.assetId}
            vehicleName={(() => {
              const vehicle = vehicles.find(v => v.id === selectedListing.assetId);
              return vehicle ? `${vehicle.year} ${vehicle.make} ${vehicle.model}` : `Asset #${selectedListing.assetId}`;
            })()}
          />
        </>
      )}

      {(selectedListing || selectedPool) && isListTokensOpen && (
        <CreateSecondaryListingModal
          isOpen={isListTokensOpen}
          onSuccess={() => {
            refreshMarketsAfterSuccess();
          }}
          onClose={() => {
            setIsListTokensOpen(false);
            setSelectedListing(null);
            setSelectedPool(null);
            setPrefillListAmount(undefined);
          }}
          vehicleId={selectedListing?.assetId || selectedPool!.assetId}
          vin={(() => {
            const assetId = selectedListing?.assetId || selectedPool!.assetId;
            const vehicle = vehicles.find(v => v.id === assetId);
            return vehicle?.vin || "";
          })()}
          assetName={(() => {
            const assetId = selectedListing?.assetId || selectedPool!.assetId;
            const vehicle = vehicles.find(v => v.id === assetId);
            return vehicle ? `${vehicle.year} ${vehicle.make} ${vehicle.model}` : `Asset #${assetId}`;
          })()}
          prefillAmount={prefillListAmount}
        />
      )}

      {selectedListing && (
        <EndSecondaryListingModal
          isOpen={isEndListingOpen}
          onSuccess={() => {
            applyListingActionSuccess(selectedListing.id, { isEnded: true, status: "ended" });
          }}
          onClose={() => {
            setIsEndListingOpen(false);
            setSelectedListing(null);
          }}
          listingId={selectedListing.id}
          tokenAmount={selectedListing.amount}
          tokenId={selectedListing.tokenId}
          amountSold={selectedListing.amountSold}
          pricePerToken={selectedListing.pricePerToken}
          isPrimary={selectedListing.isPrimary}
        />
      )}

      {selectedListing && (
        <DistributeEarningsModal
          isOpen={isDistributeEarningsOpen}
          onSuccess={() => {
            refreshMarketsAfterSuccess();
          }}
          onClose={() => {
            setIsDistributeEarningsOpen(false);
            setSelectedListing(null);
            refreshMarketsAfterSuccess();
          }}
          assetId={selectedListing.assetId}
          assetName={(() => {
            const vehicle = vehicles.find(v => v.id === selectedListing.assetId);
            return vehicle ? `${vehicle.year} ${vehicle.make} ${vehicle.model}` : `Asset #${selectedListing.assetId}`;
          })()}
        />
      )}

      {selectedListing && (
        <SettleAssetModal
          isOpen={isSettleAssetOpen}
          onClose={() => {
            setIsSettleAssetOpen(false);
            setSelectedListing(null);
            refreshMarketsAfterSuccess();
          }}
          assetId={selectedListing.assetId}
          assetName={(() => {
            const vehicle = vehicles.find(v => v.id === selectedListing.assetId);
            return vehicle ? `${vehicle.year} ${vehicle.make} ${vehicle.model}` : `Asset #${selectedListing.assetId}`;
          })()}
        />
      )}
    </div>
  );
};

export default MarketsPage;
