import deployedContracts from "~~/contracts/deployedContracts";

export enum AssetType {
  VEHICLE = "VEHICLE",
  REAL_ESTATE = "REAL_ESTATE", // Future proofing
}

export const ASSET_REGISTRIES = {
  [AssetType.VEHICLE]: {
    name: "Vehicle",
    pluralName: "Vehicles",
    contractName: "VehicleRegistry",
    address: deployedContracts[31337]?.VehicleRegistry?.address,
    icon: "🚗",
    description: "Register a car, truck, or fleet vehicle.",
    active: true,
    collectiveNoun: "fleet",
  },
  // Future implementation
  [AssetType.REAL_ESTATE]: {
    name: "Real Estate",
    pluralName: "Real Estate",
    contractName: "RealEstateRegistry",
    address: "0x0000000000000000000000000000000000000000",
    icon: "🏠",
    description: "Register a property or land.",
    active: false,
    collectiveNoun: "portfolio",
  },
};
