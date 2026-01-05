import { describe, test, assert, beforeAll } from "matchstick-as";
import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { Partner, Vehicle, Listing } from "../generated/schema";

describe("Asserts", () => {
    beforeAll(() => {
        // Mocking the Partner
        let partner = new Partner("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045");
        partner.name = "Test Partner";
        partner.authorizedAt = BigInt.fromI32(1709849870);
        partner.address = Bytes.fromHexString(
            "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
        );
        partner.save();

        // Mocking Vehicle
        let vehicle = new Vehicle("1");
        vehicle.partner = Bytes.fromHexString(
            "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
        );
        vehicle.vin = "1HGBH41JXMN109186";
        vehicle.make = "Honda";
        vehicle.model = "Accord";
        vehicle.year = BigInt.fromI32(2023);
        vehicle.metadataURI = "ipfs://QmTest";
        vehicle.blockNumber = BigInt.fromI32(12345);
        vehicle.blockTimestamp = BigInt.fromI32(1709849870);
        vehicle.transactionHash = Bytes.fromHexString(
            "0x1909fcb0b41989e28308afcb0cf55adb6faba28e14fcbf66c489c69b8fe95dd6"
        );
        vehicle.save();
    });

    test("Vehicle and Partner entities", () => {
        // Testing proper entity creation and field assertion
        let vehicleId = "2";
        let partnerAddress = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96046";
        let vin = "2HGBH41JXMN109187";

        // Creating a new Partner entity
        let newPartner = new Partner(partnerAddress);
        newPartner.name = "Another Partner";
        newPartner.authorizedAt = BigInt.fromI32(1709859870);
        newPartner.address = Bytes.fromHexString(partnerAddress);
        newPartner.save();

        // Creating a new Vehicle entity
        let vehicle = new Vehicle(vehicleId);
        vehicle.partner = Bytes.fromHexString(partnerAddress);
        vehicle.vin = vin;
        vehicle.make = "Toyota";
        vehicle.model = "Camry";
        vehicle.year = BigInt.fromI32(2024);
        vehicle.metadataURI = "ipfs://QmTest2";
        vehicle.blockNumber = BigInt.fromI32(12346);
        vehicle.blockTimestamp = BigInt.fromI32(1709859870);
        vehicle.transactionHash = Bytes.fromHexString(
            "0x2909fcb0b41989e28308afcb0cf55adb6faba28e14fcbf66c489c69b8fe95dd7"
        );
        vehicle.save();

        // Loading the Vehicle entity and asserting its fields
        let loadedEntity = Vehicle.load(vehicleId);
        assert.assertNotNull(
            loadedEntity,
            "Loaded Vehicle entity should not be null"
        );
        assert.fieldEquals("Vehicle", vehicleId, "vin", vin);
        assert.fieldEquals("Vehicle", vehicleId, "make", "Toyota");
        assert.fieldEquals("Vehicle", vehicleId, "model", "Camry");
        assert.fieldEquals("Vehicle", vehicleId, "year", "2024");

        // Assert entity counts
        assert.entityCount("Partner", 2);
        assert.entityCount("Vehicle", 2);
    });

    test("Listing entity", () => {
        // Testing Listing entity creation
        let listingId = "1";

        let listing = new Listing(listingId);
        listing.tokenId = BigInt.fromI32(100);
        listing.assetId = BigInt.fromI32(1);
        listing.seller = Bytes.fromHexString(
            "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
        );
        listing.amount = BigInt.fromI32(1000);
        listing.pricePerToken = BigInt.fromI32(100);
        listing.expiresAt = BigInt.fromI32(1709949870);
        listing.buyerPaysFee = true;
        listing.createdAt = BigInt.fromI32(1709849870);
        listing.blockNumber = BigInt.fromI32(12345);
        listing.blockTimestamp = BigInt.fromI32(1709849870);
        listing.transactionHash = Bytes.fromHexString(
            "0x3909fcb0b41989e28308afcb0cf55adb6faba28e14fcbf66c489c69b8fe95dd8"
        );
        listing.save();

        // Loading the Listing entity and asserting its fields
        let loadedListing = Listing.load(listingId);
        assert.assertNotNull(
            loadedListing,
            "Loaded Listing entity should not be null"
        );
        assert.fieldEquals("Listing", listingId, "tokenId", "100");
        assert.fieldEquals("Listing", listingId, "assetId", "1");
        assert.fieldEquals("Listing", listingId, "amount", "1000");
        assert.fieldEquals("Listing", listingId, "pricePerToken", "100");
        assert.fieldEquals("Listing", listingId, "buyerPaysFee", "true");

        assert.entityCount("Listing", 1);
    });
});
