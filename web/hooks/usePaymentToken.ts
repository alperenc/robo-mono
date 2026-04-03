"use client";

import { useMemo } from "react";
import { Address, erc20Abi } from "viem";
import { useReadContract } from "wagmi";
import { useDeployedContractInfo, useSelectedNetwork } from "~~/hooks/scaffold-eth";
import { useScaffoldReadContract } from "~~/hooks/scaffold-eth";
import { getDeployedContract } from "~~/utils/contracts";

const FALLBACK_SYMBOL = "USDC";
const FALLBACK_DECIMALS = 6;

export const usePaymentToken = () => {
  const selectedNetwork = useSelectedNetwork();
  const { data: treasuryContract } = useDeployedContractInfo({ contractName: "Treasury" });
  const { data: usdcAddress } = useScaffoldReadContract({
    contractName: "Treasury",
    functionName: "usdc",
  });

  const tokenAddress = (usdcAddress as Address | undefined) || undefined;
  const treasuryAddress = treasuryContract?.address;
  const mockTokenAddress = getDeployedContract(selectedNetwork.id, "MockUSDC")?.address as Address | undefined;
  const isTreasurySelfReference =
    !!tokenAddress && !!treasuryAddress && tokenAddress.toLowerCase() === treasuryAddress.toLowerCase();
  const shouldReadTokenMetadata = !!tokenAddress && !isTreasurySelfReference;
  const isMockToken =
    !!tokenAddress && !!mockTokenAddress && tokenAddress.toLowerCase() === mockTokenAddress.toLowerCase();

  const { data: symbol } = useReadContract({
    address: tokenAddress,
    abi: erc20Abi,
    functionName: "symbol",
    query: { enabled: shouldReadTokenMetadata },
  });

  const { data: decimals } = useReadContract({
    address: tokenAddress,
    abi: erc20Abi,
    functionName: "decimals",
    query: { enabled: shouldReadTokenMetadata },
  });

  return useMemo(
    () => ({
      address: tokenAddress,
      symbol: (symbol as string) || FALLBACK_SYMBOL,
      decimals: typeof decimals === "number" ? decimals : FALLBACK_DECIMALS,
      isMockToken,
      mockAddress: mockTokenAddress,
    }),
    [decimals, isMockToken, mockTokenAddress, symbol, tokenAddress],
  );
};
