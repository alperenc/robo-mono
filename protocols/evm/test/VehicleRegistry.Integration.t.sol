// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";

contract VehicleRegistryIntegrationTest is BaseTest {
    function setUp() public {
        _ensureState(SetupState.PartnersAuthorized);
    }

    // Vehicle Registration Tests

    function testRegisterAsset() public {
        (
            string memory vin,
            string memory make,
            string memory model,
            uint256 year,
            uint256 manufacturerId,
            string memory optionCodes,
            string memory metadataURI
        ) = generateVehicleData(1);

        vm.expectEmit(true, true, false, true);
        emit VehicleRegistry.VehicleRegistered(1, partner1, vin);

        vm.prank(partner1);
        uint256 newVehicleId =
            assetRegistry.registerAsset(abi.encode(vin, make, model, year, manufacturerId, optionCodes, metadataURI));

        assertEq(newVehicleId, 1);
        assertVehicleState(newVehicleId, partner1, vin, true);
        assertEq(roboshareTokens.getNextTokenId(), 3);
    }

    function testRegisterMultipleVehicles() public {
        (
            string memory vin1,
            string memory make1,
            string memory model1,
            uint256 year1,
            uint256 manufacturerId1,
            string memory optionCodes1,
            string memory metadataURI1
        ) = generateVehicleData(1);
        vm.prank(partner1);
        uint256 vehicleId1 = assetRegistry.registerAsset(
            abi.encode(vin1, make1, model1, year1, manufacturerId1, optionCodes1, metadataURI1)
        );

        (
            string memory vin2,
            string memory make2,
            string memory model2,
            uint256 year2,
            uint256 manufacturerId2,
            string memory optionCodes2,
            string memory metadataURI2
        ) = generateVehicleData(2);
        vm.prank(partner2);
        uint256 vehicleId2 = assetRegistry.registerAsset(
            abi.encode(vin2, make2, model2, year2, manufacturerId2, optionCodes2, metadataURI2)
        );

        assertEq(vehicleId1, 1);
        assertEq(vehicleId2, 3);
        assertVehicleState(vehicleId1, partner1, vin1, true);
        assertVehicleState(vehicleId2, partner2, vin2, true);
        assertEq(roboshareTokens.getNextTokenId(), 5);
    }

    // Revenue Share Token Tests

    function testMintRevenueTokens() public {
        _ensureState(SetupState.RevenueTokensMinted);

        assertGt(scenario.revenueTokenId, scenario.assetId);
        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), REVENUE_TOKEN_SUPPLY);

        // Verify collateral is locked
        (uint256 base, uint256 total, bool locked,,) = treasury.getAssetCollateralInfo(scenario.assetId);
        assertGt(base, 0);
        assertGt(total, base);
        assertEq(locked, true);
    }

    function testRegisterAssetAndMintTokens() public {
        _ensureState(SetupState.PartnersAuthorized);

        // Ensure partner1 has enough USDC and approves the treasury
        deal(address(usdc), partner1, type(uint256).max);
        vm.prank(partner1);
        usdc.approve(address(treasury), type(uint256).max);

        (
            string memory vin,
            string memory make,
            string memory model,
            uint256 year,
            uint256 manufacturerId,
            string memory optionCodes,
            string memory metadataURI
        ) = generateVehicleData(1);

        vm.prank(partner1);
        (uint256 newAssetId, uint256 newRevenueTokenId) = assetRegistry.registerAssetAndMintTokens(
            abi.encode(vin, make, model, year, manufacturerId, optionCodes, metadataURI),
            REVENUE_TOKEN_PRICE,
            REVENUE_TOKEN_SUPPLY
        );

        assertGt(newAssetId, 0);
        assertGt(newRevenueTokenId, scenario.assetId);
        assertTrue(assetRegistry.assetExists(newAssetId));
        assertEq(roboshareTokens.balanceOf(partner1, newAssetId), 1);
        assertEq(roboshareTokens.balanceOf(partner1, newRevenueTokenId), REVENUE_TOKEN_SUPPLY);

        // Verify collateral is locked
        (uint256 base, uint256 total, bool locked,,) = treasury.getAssetCollateralInfo(newAssetId);
        assertGt(base, 0);
        assertGt(total, base);
        assertEq(locked, true);
    }

    // Metadata Update Tests

    function testUpdateVehicleMetadata() public {
        _ensureState(SetupState.RevenueTokensMinted);
        // Use a valid IPFS URI (prefix + 46-char CID)
        string memory newURI = "ipfs://QmYwAPJzv5CZsnAzt8auVTLpG1bG6dkprdFM5ocTyBCQb";

        vm.prank(partner1);
        assetRegistry.updateVehicleMetadata(scenario.assetId, newURI);

        (,,,,,, string memory metadataURI) = assetRegistry.getVehicleInfo(scenario.assetId);
        assertEq(metadataURI, newURI);
    }

    function testUpdateVehicleMetadataInvalidUri() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.expectRevert(VehicleLib__InvalidMetadataURI.selector);
        vm.prank(partner1);
        assetRegistry.updateVehicleMetadata(scenario.assetId, "http://not-ipfs");
    }

    function testTokenIdConversions() public {
        _ensureState(SetupState.RevenueTokensMinted);
        assertEq(assetRegistry.getTokenIdFromAssetId(scenario.assetId), scenario.revenueTokenId);
        assertEq(assetRegistry.getAssetIdFromTokenId(scenario.revenueTokenId), scenario.assetId);
    }

    // Access Control Tests

    function testRegisterAssetUnauthorizedPartner() public {
        vm.expectRevert(PartnerManager.PartnerManager__NotAuthorized.selector);
        vm.prank(unauthorized);
        assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            )
        );
    }

    function testMintRevenueTokensUnauthorizedPartner() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.expectRevert(PartnerManager.PartnerManager__NotAuthorized.selector);
        vm.prank(unauthorized);
        assetRegistry.mintRevenueTokens(scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
    }

    function testUpdateMetadataUnauthorizedPartner() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.expectRevert(PartnerManager.PartnerManager__NotAuthorized.selector);
        vm.prank(unauthorized);
        assetRegistry.updateVehicleMetadata(scenario.assetId, "ipfs://QmYwAPJzv5CZsnAzt8auVTLpG1bG6dkprdFM5ocTyBCQb");
    }

    // Error Cases

    function testRegisterAssetDuplicateVIN() public {
        _ensureState(SetupState.RevenueTokensMinted);
        (
            ,
            string memory make,
            string memory model,
            uint256 year,
            uint256 manufacturerId,
            string memory optionCodes,
            string memory metadataURI
        ) = generateVehicleData(3);
        vm.expectRevert(VehicleRegistry__VehicleAlreadyExists.selector);
        vm.prank(partner2);
        assetRegistry.registerAsset(abi.encode(TEST_VIN, make, model, year, manufacturerId, optionCodes, metadataURI));
    }

    function testMintRevenueTokensNonexistentVehicle() public {
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetRegistry__AssetNotFound.selector, 999));
        vm.prank(partner1);
        assetRegistry.mintRevenueTokens(999, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
    }

    function testMintRevenueTokensAlreadyMinted() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.prank(partner1);
        vm.expectRevert(VehicleRegistry__RevenueTokensAlreadyMinted.selector);
        assetRegistry.mintRevenueTokens(scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
    }

    function testUpdateMetadataNonexistentVehicle() public {
        vm.expectRevert(VehicleRegistry__VehicleDoesNotExist.selector);
        vm.prank(partner1);
        assetRegistry.updateVehicleMetadata(999, "ipfs://QmYwAPJzv5CZsnAzt8auVTLpG1bG6dkprdFM5ocTyBCQb");
    }

    function testMintRevenueTokensTreasuryNotSet() public {
        vm.startPrank(admin);
        // Deploy a new registry without setting the treasury
        VehicleRegistry newRegistry = new VehicleRegistry();
        newRegistry.initialize(admin, address(roboshareTokens), address(partnerManager));

        // Grant minter role to the new registry
        roboshareTokens.grantRole(roboshareTokens.MINTER_ROLE(), address(newRegistry));
        vm.stopPrank();

        // Register an asset on the new registry
        vm.prank(partner1);
        uint256 tempAssetId = newRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            )
        );

        // Attempt to mint tokens should fail as treasury is not set
        vm.prank(partner1);
        vm.expectRevert(VehicleRegistry__TreasuryNotSet.selector);
        newRegistry.mintRevenueTokens(tempAssetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
    }

    function testRegisterAssetAndMintTokensTreasuryNotSet() public {
        vm.startPrank(admin);
        // Deploy a new registry without setting the treasury
        VehicleRegistry newRegistry = new VehicleRegistry();
        newRegistry.initialize(admin, address(roboshareTokens), address(partnerManager));
        vm.stopPrank();

        // Attempt to call registerAssetAndMintTokens should fail as treasury is not set
        vm.prank(partner1);
        vm.expectRevert(VehicleRegistry__TreasuryNotSet.selector);
        newRegistry.registerAssetAndMintTokens(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            ),
            REVENUE_TOKEN_PRICE,
            REVENUE_TOKEN_SUPPLY
        );
    }

    function testMintRevenueTokensNotVehicleOwner() public {
        _ensureState(SetupState.AssetRegistered); // Asset is registered by partner1

        // partner2 is authorized but does not own the asset
        vm.prank(partner2);
        vm.expectRevert(VehicleRegistry__NotVehicleOwner.selector);
        assetRegistry.mintRevenueTokens(scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
    }

    function testTokenIdConversionNonexistentVehicle() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.expectRevert(VehicleRegistry__IncorrectRevenueTokenId.selector);
        assetRegistry.getAssetIdFromTokenId(100);

        vm.expectRevert(VehicleRegistry__IncorrectVehicleId.selector);
        assetRegistry.getTokenIdFromAssetId(101);
    }

    function testGetVehicleIdFromRevenueTokenIdErrorCases() public {
        _ensureState(SetupState.PartnersAuthorized);

        // Test revenueTokenId == 0
        vm.expectRevert(VehicleRegistry__IncorrectRevenueTokenId.selector);
        assetRegistry.getAssetIdFromTokenId(0);

        // Test revenueTokenId % 2 != 0 (odd revenue token ID)
        vm.expectRevert(VehicleRegistry__IncorrectRevenueTokenId.selector);
        assetRegistry.getAssetIdFromTokenId(1); // 1 is an odd ID

        // Test revenueTokenId >= _tokenIdCounter (non-existent revenue token ID)
        vm.expectRevert(VehicleRegistry__IncorrectRevenueTokenId.selector);
        assetRegistry.getAssetIdFromTokenId(999999);

        // Test vehicles[vehicleId].vehicleId == 0 (corresponding vehicle NFT doesn't exist)
        // To test this, we need a revenueTokenId that is valid in terms of parity and counter,
        // but whose corresponding vehicleId does not exist. This is hard to achieve without
        // directly manipulating _tokenIdCounter or deleting a vehicle, which is not possible.
        // The existing test `testMintRevenueTokensForNonexistentVehicleFails` covers a similar scenario.
    }

    // View Function Tests

    function testVehicleExists() public {
        assertFalse(assetRegistry.assetExists(999));
        _ensureState(SetupState.RevenueTokensMinted);
        assertTrue(assetRegistry.assetExists(scenario.assetId));
    }

    function testVINExists() public {
        assertFalse(assetRegistry.vinExists("FAKE_VIN"));
        _ensureState(SetupState.RevenueTokensMinted);
        assertTrue(assetRegistry.vinExists(TEST_VIN));
    }

    // New: registry introspection and asset info branches
    function testRegistryIntrospectionAndAssetInfo() public {
        _ensureState(SetupState.RevenueTokensMinted);
        // Introspection
        assertEq(assetRegistry.getRegistryType(), "VehicleRegistry");
        assertEq(assetRegistry.getRegistryVersion(), 1);

        // Asset info and active status
        AssetLib.AssetInfo memory info = assetRegistry.getAssetInfo(scenario.assetId);
        assertEq(uint8(info.status), uint8(AssetLib.AssetStatus.Active));
        assertGt(info.createdAt, 0);
        assertGe(info.updatedAt, info.createdAt);
    }

    // Fuzz Tests

    function testFuzzMintRevenueTokens(uint256 supply) public {
        vm.assume(supply > 0 && supply <= 1e18);
        _deployContracts();
        _setupInitialRolesAndPartners();

        // Ensure partner1 has enough USDC and approves the treasury
        deal(address(usdc), partner1, type(uint256).max);
        vm.prank(partner1);
        usdc.approve(address(treasury), type(uint256).max);

        vm.prank(partner1);
        uint256 vehicleId = assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            )
        );

        vm.prank(partner1);
        uint256 revenueTokenId = assetRegistry.mintRevenueTokens(vehicleId, REVENUE_TOKEN_PRICE, supply);

        assertEq(roboshareTokens.balanceOf(partner1, revenueTokenId), supply);
    }

    // Lifecycle Test

    function testCompleteVehicleLifecycle() public {
        _ensureState(SetupState.RevenueTokensMinted);

        assertTrue(assetRegistry.assetExists(scenario.assetId));

        string memory newURI = "ipfs://QmYwAPJzv5CZsnAzt8auVTLpG1bG6dkprdFM5ocTyBCQb";
        vm.prank(partner1);
        assetRegistry.updateVehicleMetadata(scenario.assetId, newURI);

        (,,,,,, string memory metadataURI) = assetRegistry.getVehicleInfo(scenario.assetId);
        assertEq(metadataURI, newURI);
    }
}
