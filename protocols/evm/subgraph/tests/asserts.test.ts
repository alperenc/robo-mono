import { describe, test, assert, beforeAll } from "matchstick-as";
import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { Partner, Vehicle, Listing, EarningsDistribution, AssetEarnings, BoundId } from "../generated/schema";

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

    test("EarningsDistribution entity", () => {
        // Testing EarningsDistribution entity creation
        let distributionId = "0x1234567890abcdef-1";

        let distribution = new EarningsDistribution(distributionId);
        distribution.assetId = BigInt.fromI32(1);
        distribution.partner = Bytes.fromHexString(
            "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
        );
        distribution.totalRevenue = BigInt.fromI64(1000000000); // 1000 USDC
        distribution.netEarnings = BigInt.fromI64(100000000);   // 100 USDC
        distribution.period = BigInt.fromI32(1);
        distribution.blockNumber = BigInt.fromI32(12345);
        distribution.blockTimestamp = BigInt.fromI32(1709849870);
        distribution.transactionHash = Bytes.fromHexString(
            "0x4909fcb0b41989e28308afcb0cf55adb6faba28e14fcbf66c489c69b8fe95dd9"
        );
        distribution.save();

        // Loading and asserting
        let loaded = EarningsDistribution.load(distributionId);
        assert.assertNotNull(loaded, "EarningsDistribution should not be null");
        assert.fieldEquals("EarningsDistribution", distributionId, "assetId", "1");
        assert.fieldEquals("EarningsDistribution", distributionId, "totalRevenue", "1000000000");
        assert.fieldEquals("EarningsDistribution", distributionId, "netEarnings", "100000000");
        assert.fieldEquals("EarningsDistribution", distributionId, "period", "1");

        assert.entityCount("EarningsDistribution", 1);
    });

    test("AssetEarnings aggregate entity", () => {
        // Testing AssetEarnings entity creation and aggregation
        let assetId = "1";

        // Create initial AssetEarnings
        let assetEarnings = new AssetEarnings(assetId);
        assetEarnings.assetId = BigInt.fromI32(1);
        assetEarnings.totalEarnings = BigInt.fromI64(100000000);  // 100 USDC
        assetEarnings.totalRevenue = BigInt.fromI64(1000000000); // 1000 USDC
        assetEarnings.distributionCount = BigInt.fromI32(1);
        assetEarnings.firstDistributionAt = BigInt.fromI32(1709849870);
        assetEarnings.lastDistributionAt = BigInt.fromI32(1709849870);
        assetEarnings.save();

        // Verify initial state
        assert.fieldEquals("AssetEarnings", assetId, "totalEarnings", "100000000");
        assert.fieldEquals("AssetEarnings", assetId, "distributionCount", "1");

        // Simulate second distribution (aggregation)
        let loaded = AssetEarnings.load(assetId);
        if (loaded) {
            loaded.totalEarnings = loaded.totalEarnings.plus(BigInt.fromI64(150000000));
            loaded.totalRevenue = loaded.totalRevenue.plus(BigInt.fromI64(1500000000));
            loaded.distributionCount = loaded.distributionCount.plus(BigInt.fromI32(1));
            loaded.lastDistributionAt = BigInt.fromI32(1712441870);
            loaded.save();
        }

        // Verify aggregated state
        assert.fieldEquals("AssetEarnings", assetId, "totalEarnings", "250000000"); // 100 + 150
        assert.fieldEquals("AssetEarnings", assetId, "totalRevenue", "2500000000"); // 1000 + 1500
        assert.fieldEquals("AssetEarnings", assetId, "distributionCount", "2");
        assert.fieldEquals("AssetEarnings", assetId, "firstDistributionAt", "1709849870");
        assert.fieldEquals("AssetEarnings", assetId, "lastDistributionAt", "1712441870");

        assert.entityCount("AssetEarnings", 1);
    });

    test("BoundId entity", () => {
        // Testing BoundId entity creation
        let id = "1";
        let registryAddress = "0xeD1DB453C3156Ff3155a97AD217b3087D5Dc5f6E";

        let boundId = new BoundId(id);
        boundId.idValue = BigInt.fromI32(1);
        boundId.registry = Bytes.fromHexString(registryAddress);
        boundId.blockNumber = BigInt.fromI32(12345);
        boundId.blockTimestamp = BigInt.fromI32(1709849870);
        boundId.transactionHash = Bytes.fromHexString(
            "0x5909fcb0b41989e28308afcb0cf55adb6faba28e14fcbf66c489c69b8fe95dda"
        );
        boundId.save();

        // Loading and asserting
        let loaded = BoundId.load(id);
        assert.assertNotNull(loaded, "BoundId should not be null");
        assert.fieldEquals("BoundId", id, "idValue", "1");
        assert.fieldEquals("BoundId", id, "registry", registryAddress.toLowerCase());

        assert.entityCount("BoundId", 1);
    });
});

