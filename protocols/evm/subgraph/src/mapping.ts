import { BigInt, Address } from "@graphprotocol/graph-ts"
import {
  MockUSDC,
  Transfer as MockUSDCTransferEvent
} from "../generated/MockUSDC/MockUSDC"
import {
  RoboshareTokens,
  TransferSingle as RoboshareTokensTransferSingleEvent,
  RevenueTokenInfoSet as RevenueTokenInfoSetEvent
} from "../generated/RoboshareTokens/RoboshareTokens"
import {
  PartnerManager,
  PartnerAuthorized as PartnerAuthorizedEvent
} from "../generated/PartnerManager/PartnerManager"
import {
  RegistryRouter,
  AssetRegistered as AssetRegisteredRouterEvent
} from "../generated/RegistryRouter/RegistryRouter"
import {
  VehicleRegistry,
  VehicleRegistered as VehicleRegisteredEvent
} from "../generated/VehicleRegistry/VehicleRegistry"
import {
  Treasury,
  CollateralLocked as CollateralLockedEvent
} from "../generated/Treasury/Treasury"
import {
  Marketplace,
  ListingCreated as ListingCreatedEvent
} from "../generated/Marketplace/Marketplace"

import {
  MockUSDCContract,
  Transfer,
  RoboshareTokensContract,
  RoboshareToken,
  TransferSingleEvent,
  PartnerManagerContract,
  Partner,
  RegistryRouterContract,
  RegisteredAssetRouter,
  VehicleRegistryContract,
  Vehicle,
  TreasuryContract,
  CollateralLock,
  MarketplaceContract,
  Listing
} from "../generated/schema"

export function handleMockUSDCTransfer(event: MockUSDCTransferEvent): void {
  let entity = new Transfer(
    event.transaction.hash.toHex() + "-" + event.logIndex.toString()
  )
  entity.from = event.params.from
  entity.to = event.params.to
  entity.value = event.params.value
  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash
  entity.save()

  let contract = MockUSDCContract.load("1")
  if (!contract) {
    contract = new MockUSDCContract("1")
    contract.address = event.address
    contract.save()
  }
}

export function handleRoboshareTokensTransferSingle(
  event: RoboshareTokensTransferSingleEvent
): void {
  let entity = new TransferSingleEvent(
    event.transaction.hash.toHex() + "-" + event.logIndex.toString()
  )
  entity.operator = event.params.operator
  entity.from = event.params.from
  entity.to = event.params.to
  entity.tokenId = event.params.id
  entity.value = event.params.value
  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash
  entity.save()

  let contract = RoboshareTokensContract.load("1")
  if (!contract) {
    contract = new RoboshareTokensContract("1")
    contract.address = event.address
    contract.save()
  }
}

export function handleRevenueTokenInfoSet(event: RevenueTokenInfoSetEvent): void {
  let token = new RoboshareToken(event.params.revenueTokenId.toString())
  token.revenueTokenId = event.params.revenueTokenId
  token.price = event.params.price
  token.supply = event.params.supply
  token.maturityDate = event.params.maturityDate
  token.setAtBlock = event.block.number
  token.save()
}

export function handlePartnerAuthorized(event: PartnerAuthorizedEvent): void {
  let partner = new Partner(event.params.partner.toHex())
  partner.address = event.params.partner
  partner.name = event.params.name
  partner.authorizedAt = event.block.timestamp
  partner.save()

  let contract = PartnerManagerContract.load("1")
  if (!contract) {
    contract = new PartnerManagerContract("1")
    contract.address = event.address
    contract.save()
  }
}

export function handleAssetRegisteredRouter(event: AssetRegisteredRouterEvent): void {
  let registeredAsset = new RegisteredAssetRouter(event.params.assetId.toString())
  registeredAsset.assetId = event.params.assetId
  registeredAsset.owner = event.params.owner
  registeredAsset.status = event.params.status
  registeredAsset.blockNumber = event.block.number
  registeredAsset.blockTimestamp = event.block.timestamp
  registeredAsset.transactionHash = event.transaction.hash
  registeredAsset.save()

  let contract = RegistryRouterContract.load("1")
  if (!contract) {
    contract = new RegistryRouterContract("1")
    contract.address = event.address
    contract.save()
  }
}

export function handleVehicleRegistered(event: VehicleRegisteredEvent): void {
  let vehicle = new Vehicle(event.params.vehicleId.toString())
  vehicle.partner = event.params.partner
  vehicle.vin = event.params.vin
  vehicle.blockNumber = event.block.number
  vehicle.blockTimestamp = event.block.timestamp
  vehicle.transactionHash = event.transaction.hash

  // Fetch vehicle info from contract
  let contract = VehicleRegistry.bind(event.address)
  let infoCall = contract.try_getVehicleInfo(event.params.vehicleId)
  if (!infoCall.reverted) {
    let info = infoCall.value
    vehicle.make = info.value1 // make
    vehicle.model = info.value2 // model
    vehicle.year = info.value3 // year
  }

  vehicle.save()

  let registryContract = VehicleRegistryContract.load("1")
  if (!registryContract) {
    registryContract = new VehicleRegistryContract("1")
    registryContract.address = event.address
    registryContract.save()
  }
}

export function handleCollateralLocked(event: CollateralLockedEvent): void {
  let collateralLock = new CollateralLock(
    event.params.assetId.toString() + "-" + event.transaction.hash.toHex()
  )
  collateralLock.assetId = event.params.assetId
  collateralLock.partner = event.params.partner
  collateralLock.amount = event.params.amount
  collateralLock.blockNumber = event.block.number
  collateralLock.blockTimestamp = event.block.timestamp
  collateralLock.transactionHash = event.transaction.hash
  collateralLock.save()

  let contract = TreasuryContract.load("1")
  if (!contract) {
    contract = new TreasuryContract("1")
    contract.address = event.address
    contract.save()
  }
}

export function handleListingCreated(event: ListingCreatedEvent): void {
  let listing = new Listing(event.params.listingId.toString())
  listing.tokenId = event.params.tokenId
  listing.assetId = event.params.assetId
  listing.seller = event.params.seller
  listing.amount = event.params.amount
  listing.pricePerToken = event.params.pricePerToken
  listing.expiresAt = event.params.expiresAt
  listing.buyerPaysFee = event.params.buyerPaysFee
  listing.createdAt = event.block.timestamp
  listing.blockNumber = event.block.number
  listing.blockTimestamp = event.block.timestamp
  listing.transactionHash = event.transaction.hash
  listing.save()

  let contract = MarketplaceContract.load("1")
  if (!contract) {
    contract = new MarketplaceContract("1")
    contract.address = event.address
    contract.save()
  }
}