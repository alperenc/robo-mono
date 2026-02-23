"use client";

import { useMemo } from "react";
import { erc20Abi } from "viem";
import { useReadContract } from "wagmi";
import { useDeployedContractInfo } from "~~/hooks/scaffold-eth";
import { useScaffoldReadContract } from "~~/hooks/scaffold-eth";

const FALLBACK_SYMBOL = "USDC";
const FALLBACK_DECIMALS = 6;

export const usePaymentToken = () => {
  const { data: treasuryContract } = useDeployedContractInfo({ contractName: "Treasury" });
  const { data: usdcAddress } = useScaffoldReadContract({
    contractName: "Treasury",
    functionName: "usdc",
  });

  const tokenAddress = (usdcAddress as `0x${string}`) || undefined;
  const treasuryAddress = treasuryContract?.address;
  const isTreasurySelfReference =
    !!tokenAddress && !!treasuryAddress && tokenAddress.toLowerCase() === treasuryAddress.toLowerCase();
  const shouldReadTokenMetadata = !!tokenAddress && !isTreasurySelfReference;

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
    }),
    [tokenAddress, symbol, decimals],
  );
};
