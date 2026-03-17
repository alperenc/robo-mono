// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseTest } from "./BaseTest.t.sol";

abstract contract AssetMetadataBaseTest is BaseTest {
    string constant TEST_VIN = "1HGCM82633A123456";
    string constant TEST_MAKE = "Honda";
    string constant TEST_MODEL = "Civic";
    uint256 constant TEST_YEAR = 2024;
    uint256 constant TEST_MANUFACTURER_ID = 1;
    string constant TEST_OPTION_CODES = "EX-L,NAV,HSS";
    string constant TEST_METADATA_URI = "ipfs://QmYwAPJzv5CZsnA625b3Xm2fa12p45a8V34vG27s2p45a8";

    function _setupAssetRegistered() internal virtual override returns (uint256 assetId) {
        vm.prank(partner1);
        assetId = assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            ),
            ASSET_VALUE
        );
    }

    function _setupPrimaryPoolCreated() internal virtual override returns (uint256 revenueTokenId) {
        uint256 maturityDate = block.timestamp + 365 days;
        uint256 supply = ASSET_VALUE / REVENUE_TOKEN_PRICE;

        vm.prank(partner1);
        (revenueTokenId,) = assetRegistry.createRevenueTokenPool(
            scenario.assetId, REVENUE_TOKEN_PRICE, maturityDate, 10_000, 1_000, supply, false, false
        );
    }

    function _setupPurchasedFromPrimaryPool() internal virtual override {
        (uint256 expectedPayment,,) =
            marketplace.previewPrimaryPurchase(scenario.revenueTokenId, PRIMARY_PURCHASE_AMOUNT);
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.buyFromPrimaryPool(scenario.revenueTokenId, PRIMARY_PURCHASE_AMOUNT);
        vm.stopPrank();
    }

    function _generateVin(uint256 seed) internal pure returns (string memory) {
        string[10] memory vinPrefixes = [
            "1HGCM82633A",
            "2FMDK3GC1D",
            "3FA6P0H75H",
            "4T1BF1FK6G",
            "5NPE24AF3F",
            "6G2VX12G0L",
            "1N4AL3AP0G",
            "2T1BURHE3H",
            "3C4PDCAB0F",
            "4F4YR16U8V"
        ];

        uint256 prefixIndex = seed % 10;
        uint256 suffix = (seed % 900000) + 100000;
        return string(abi.encodePacked(vinPrefixes[prefixIndex], vm.toString(suffix)));
    }

    function _generateVehicleData(uint256 seed)
        internal
        pure
        returns (
            string memory vin,
            string memory make,
            string memory model,
            uint256 year,
            uint256 manufacturerId,
            string memory optionCodes,
            string memory metadataURI
        )
    {
        string[5] memory makes = ["Toyota", "Honda", "Ford", "BMW", "Tesla"];
        string[5] memory models = ["Camry", "Civic", "F-150", "X3", "Model 3"];

        vin = _generateVin(seed);
        make = makes[seed % 5];
        model = models[(seed + 1) % 5];
        year = 2020 + (seed % 5);
        manufacturerId = (seed % 100) + 1;
        optionCodes = "TEST,OPTION";
        metadataURI = "ipfs://QmYwAPJzv5CZsnAzt8auVTLpG1bG6dkprdFM5ocTyBCQb";
    }

    function _createMultipleTestVehicles(address partner, uint256 count) internal returns (uint256[] memory assetIds) {
        assetIds = new uint256[](count);

        vm.startPrank(partner);
        for (uint256 i = 0; i < count; i++) {
            (
                string memory vin,
                string memory make,
                string memory model,
                uint256 year,
                uint256 manufacturerId,
                string memory optionCodes,
                string memory metadataURI
            ) = _generateVehicleData(i + uint256(keccak256(abi.encodePacked(partner, block.timestamp))));

            assetIds[i] = assetRegistry.registerAsset(
                abi.encode(vin, make, model, year, manufacturerId, optionCodes, metadataURI), ASSET_VALUE
            );
        }
        vm.stopPrank();

        return assetIds;
    }
}
