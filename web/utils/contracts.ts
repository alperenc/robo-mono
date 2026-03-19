import deployedContracts from "~~/contracts/deployedContracts";
import { GenericContract } from "~~/utils/scaffold-eth/contract";

const contractsByChain = deployedContracts as Record<number, Record<string, GenericContract>>;

export const getDeployedContract = (chainId: number | undefined, contractName: string): GenericContract | undefined => {
  if (!chainId) {
    return undefined;
  }

  return contractsByChain[chainId]?.[contractName];
};
