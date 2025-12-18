"use client";

import { useEffect, useState } from "react";
import { NextPage } from "next";
import { useAccount } from "wagmi";
import { GetVehiclesDocument, execute } from "~~/.graphclient";
import deployedContracts from "~~/contracts/deployedContracts";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

const MintPage: NextPage = () => {
  const { address: connectedAddress } = useAccount();
  const [myVehicles, setMyVehicles] = useState<any[]>([]);

  const [formData, setFormData] = useState({
    vehicleId: "",
    tokenPrice: "",
    tokenSupply: "",
  });

  const { writeContractAsync: writeVehicleRegistry } = useScaffoldWriteContract("VehicleRegistry");
  const { writeContractAsync: writeMockUSDC } = useScaffoldWriteContract("MockUSDC");

  const treasuryAddress = deployedContracts[31337]?.Treasury?.address;

  // Fetch user's vehicles from Subgraph
  useEffect(() => {
    const fetchVehicles = async () => {
      if (!connectedAddress) return;
      try {
        const { data } = await execute(GetVehiclesDocument, { partner: connectedAddress.toLowerCase() });
        if (data?.vehicles) {
          setMyVehicles(data.vehicles);
        }
      } catch (e) {
        console.error("Error fetching vehicles:", e);
      }
    };
    fetchVehicles();
  }, [connectedAddress]);

  // Read Revenue Token Supply to check if already minted
  // (We check the supply of the PREDICTED revenue token ID, which is assetId + 1)
  const predictedRevenueTokenId = formData.vehicleId ? BigInt(formData.vehicleId) + 1n : 0n;

  const { data: existingSupply } = useScaffoldReadContract({
    contractName: "RoboshareTokens",
    functionName: "getRevenueTokenSupply",
    args: [predictedRevenueTokenId],
    watch: true,
  });

  const tokenPriceBigInt = formData.tokenPrice ? BigInt(formData.tokenPrice) : 0n;
  const tokenSupplyBigInt = formData.tokenSupply ? BigInt(formData.tokenSupply) : 0n;

  // Read required collateral
  const { data: requiredCollateral } = useScaffoldReadContract({
    contractName: "Treasury",
    functionName: "getTotalCollateralRequirement",
    args: [tokenPriceBigInt, tokenSupplyBigInt],
    watch: true,
  });

  // Read allowance
  const { data: allowance } = useScaffoldReadContract({
    contractName: "MockUSDC",
    functionName: "allowance",
    args: [connectedAddress, treasuryAddress],
    watch: true,
  });

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!treasuryAddress) {
      alert("Treasury contract not found!");
      return;
    }

    try {
      // 1. Check Approval
      if (requiredCollateral && (!allowance || allowance < requiredCollateral)) {
        console.log("Approving USDC...");
        await writeMockUSDC({
          functionName: "approve",
          args: [treasuryAddress, requiredCollateral],
        });
      }

      // 2. Mint Tokens
      console.log("Minting Revenue Tokens...");
      await writeVehicleRegistry({
        functionName: "mintRevenueTokens",
        args: [BigInt(formData.vehicleId), tokenPriceBigInt, tokenSupplyBigInt],
      });

      alert("Revenue Tokens minted successfully!");
    } catch (e) {
      console.error("Error:", e);
      alert("Transaction failed. See console.");
    }
  };

  const needsApproval = requiredCollateral && allowance ? allowance < requiredCollateral : true;
  const isAlreadyMinted = existingSupply && existingSupply > 0n;

  return (
    <div className="flex flex-col items-center py-10 gap-10">
      <div className="flex flex-col items-center">
        <h1 className="text-4xl font-bold">Tokenization Dashboard</h1>
        <p className="text-lg opacity-80">Mint Revenue Tokens for existing vehicles</p>
      </div>

      <div className="card w-full max-w-2xl bg-base-100 shadow-xl">
        <div className="card-body">
          <h2 className="card-title justify-center mb-4">Mint Revenue Tokens</h2>
          <form onSubmit={handleSubmit} className="flex flex-col gap-4">
            {/* Vehicle Selection */}
            <div className="form-control">
              <label className="label">
                <span className="label-text">Select Vehicle</span>
              </label>
              <select
                name="vehicleId"
                className="select select-bordered"
                value={formData.vehicleId}
                onChange={handleInputChange}
                required
              >
                <option value="" disabled>
                  Select a vehicle...
                </option>
                {myVehicles.map(v => (
                  <option key={v.id} value={v.id}>
                    VIN: {v.vin} (ID: {v.id})
                  </option>
                ))}
              </select>
            </div>

            {/* Warning if already minted */}
            {isAlreadyMinted && (
              <div className="alert alert-warning shadow-sm">
                <span>
                  Warning: This vehicle already has revenue tokens minted (Supply: {existingSupply.toString()}). You
                  cannot mint again.
                </span>
              </div>
            )}

            <div className="flex gap-4">
              <div className="form-control w-1/2">
                <label className="label">
                  <span className="label-text">Token Price (USDC)</span>
                </label>
                <input
                  type="number"
                  name="tokenPrice"
                  placeholder="100"
                  className="input input-bordered"
                  value={formData.tokenPrice}
                  onChange={handleInputChange}
                  disabled={!!isAlreadyMinted}
                  required
                />
              </div>
              <div className="form-control w-1/2">
                <label className="label">
                  <span className="label-text">Total Supply</span>
                </label>
                <input
                  type="number"
                  name="tokenSupply"
                  placeholder="1000"
                  className="input input-bordered"
                  value={formData.tokenSupply}
                  onChange={handleInputChange}
                  disabled={!!isAlreadyMinted}
                  required
                />
              </div>
            </div>

            {/* Collateral Info */}
            <div className="alert alert-info shadow-sm mt-2">
              <div>
                <h3 className="font-bold">Required Collateral</h3>
                <div className="text-xs">You must approve and lock USDC to mint tokens.</div>
              </div>
              <div className="text-xl font-mono">{requiredCollateral ? requiredCollateral.toString() : "0"} USDC</div>
            </div>

            <div className="form-control mt-6">
              <button type="submit" className="btn btn-primary" disabled={!!isAlreadyMinted || !formData.vehicleId}>
                {needsApproval ? "Approve USDC & Mint" : "Mint Tokens"}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
};

export default MintPage;
