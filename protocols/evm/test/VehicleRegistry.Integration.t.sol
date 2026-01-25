// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseTest } from "./BaseTest.t.sol";
import { AssetLib, VehicleLib } from "../contracts/Libraries.sol";
import { IAssetRegistry } from "../contracts/interfaces/IAssetRegistry.sol";
import { ITreasury } from "../contracts/interfaces/ITreasury.sol";
import { PartnerManager } from "../contracts/PartnerManager.sol";
import { VehicleRegistry } from "../contracts/VehicleRegistry.sol";

contract VehicleRegistryIntegrationTest is BaseTest {
    function setUp() public {
        _ensureState(SetupState.InitialAccountsSetup);
    }

    function testRetireAssetOutstandingTokens() public {
        _ensureState(SetupState.RevenueTokensMinted);
        // Don't burn tokens
        vm.prank(partner1);
        // Expect Treasury error now
        vm.expectRevert(ITreasury.OutstandingRevenueTokens.selector);
        assetRegistry.retireAsset(scenario.assetId);
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
        _ensureState(SetupState.InitialAccountsSetup);

        // Ensure partner1 approves the treasury
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
        uint256 maturityDate = block.timestamp + 365 days;

        vm.prank(partner1);
        (uint256 newAssetId, uint256 newRevenueTokenId) = assetRegistry.registerAssetAndMintTokens(
            abi.encode(vin, make, model, year, manufacturerId, optionCodes, metadataURI),
            REVENUE_TOKEN_PRICE,
            REVENUE_TOKEN_SUPPLY,
            maturityDate
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

    function testRegisterAssetMintAndList() public {
        _ensureState(SetupState.InitialAccountsSetup);

        // Setup: Configure marketplace on Router and grant role to Router
        vm.startPrank(admin);
        router.setMarketplace(address(marketplace));
        marketplace.grantRole(marketplace.AUTHORIZED_CONTRACT_ROLE(), address(router));
        vm.stopPrank();

        // Partner must approve marketplace for token transfers
        vm.startPrank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);

        // Prepare collateral
        uint256 requiredCollateral = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        usdc.approve(address(treasury), requiredCollateral);

        // Use a different VIN for this test
        bytes memory vehicleData = abi.encode(
            "UNIQUE123456789", // Different VIN
            TEST_MAKE,
            TEST_MODEL,
            TEST_YEAR,
            TEST_MANUFACTURER_ID,
            TEST_OPTION_CODES,
            TEST_METADATA_URI
        );

        // Execute: Register, mint, and list in one transaction!
        (uint256 assetId, uint256 revenueTokenId, uint256 listingId) = assetRegistry.registerAssetMintAndList(
            vehicleData, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY, block.timestamp + 365 days, 30 days, true
        );
        vm.stopPrank();

        // Verify: Asset was registered and activated
        assertTrue(assetRegistry.assetExists(assetId));
        assertEq(uint8(assetRegistry.getAssetStatus(assetId)), uint8(AssetLib.AssetStatus.Active));

        // Verify: Revenue tokens were minted (but transferred to marketplace for escrow)
        assertEq(roboshareTokens.balanceOf(address(marketplace), revenueTokenId), REVENUE_TOKEN_SUPPLY);

        // Verify: Listing was created with full supply at face value
        assertListingState(listingId, revenueTokenId, REVENUE_TOKEN_SUPPLY, REVENUE_TOKEN_PRICE, partner1, true, true);
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
        vm.expectRevert(VehicleLib.InvalidMetadataURI.selector);
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
        vm.expectRevert(PartnerManager.NotAuthorized.selector);
        vm.prank(unauthorized);
        assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            )
        );
    }

    function testMintRevenueTokensUnauthorizedPartner() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.expectRevert(PartnerManager.NotAuthorized.selector);
        vm.prank(unauthorized);
        assetRegistry.mintRevenueTokens(
            scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY, block.timestamp + 365 days
        );
    }

    function testUpdateMetadataUnauthorizedPartner() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.expectRevert(PartnerManager.NotAuthorized.selector);
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
        vm.expectRevert(VehicleRegistry.VehicleAlreadyExists.selector);
        vm.prank(partner2);
        assetRegistry.registerAsset(abi.encode(TEST_VIN, make, model, year, manufacturerId, optionCodes, metadataURI));
    }

    function testMintRevenueTokensNonexistentVehicle() public {
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetNotFound.selector, 999));
        vm.prank(partner1);
        assetRegistry.mintRevenueTokens(999, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY, block.timestamp + 365 days);
    }

    function testMintRevenueTokensAlreadyMinted() public {
        _ensureState(SetupState.RevenueTokensMinted);

        vm.prank(partner1);
        vm.expectRevert(VehicleRegistry.RevenueTokensAlreadyMinted.selector);
        assetRegistry.mintRevenueTokens(
            scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY, block.timestamp + 365 days
        );
    }

    function testUpdateMetadataNonexistentVehicle() public {
        vm.expectRevert(VehicleRegistry.VehicleDoesNotExist.selector);
        vm.prank(partner1);
        assetRegistry.updateVehicleMetadata(999, "ipfs://QmYwAPJzv5CZsnAzt8auVTLpG1bG6dkprdFM5ocTyBCQb");
    }

    function testMintRevenueTokensNotAssetOwner() public {
        _ensureState(SetupState.AssetRegistered); // Asset is registered by partner1

        // partner2 is authorized but does not own the asset
        vm.prank(partner2);
        vm.expectRevert(IAssetRegistry.NotAssetOwner.selector);
        assetRegistry.mintRevenueTokens(
            scenario.assetId, REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY, block.timestamp + 365 days
        );
    }

    function testGetAssetIdFromTokenIdError() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Test revenueTokenId == 0
        vm.expectRevert(VehicleRegistry.InvalidRevenueTokenId.selector);
        assetRegistry.getAssetIdFromTokenId(0);

        // Test revenueTokenId % 2 != 0 (odd revenue token ID)
        vm.expectRevert(VehicleRegistry.InvalidRevenueTokenId.selector);
        assetRegistry.getAssetIdFromTokenId(1); // 1 is an odd ID

        // Test revenueTokenId >= _tokenIdCounter (non-existent revenue token ID)
        vm.expectRevert(VehicleRegistry.InvalidRevenueTokenId.selector);
        assetRegistry.getAssetIdFromTokenId(999999);

        // Test with non-existent but valid parity ID
        vm.expectRevert(VehicleRegistry.InvalidRevenueTokenId.selector);
        assetRegistry.getAssetIdFromTokenId(100);
    }

    function testGetTokenIdFromAssetIdError() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Test assetId == 0
        vm.expectRevert(VehicleRegistry.InvalidVehicleId.selector);
        assetRegistry.getTokenIdFromAssetId(0);

        // Test assetId >= nextTokenId
        vm.expectRevert(VehicleRegistry.InvalidVehicleId.selector);
        assetRegistry.getTokenIdFromAssetId(999999);

        // Test with revenue token ID (not an asset ID)
        vm.expectRevert(VehicleRegistry.InvalidVehicleId.selector);
        assetRegistry.getTokenIdFromAssetId(101);
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
        _setupInitialRolesAndAccounts();

        // Ensure partner1 has enough USDC and approves the treasury
        deal(address(usdc), partner1, type(uint256).max);
        vm.prank(partner1);
        usdc.approve(address(treasury), type(uint256).max);
        uint256 maturityDate = block.timestamp + 365 days;

        vm.prank(partner1);
        uint256 vehicleId = assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            )
        );

        vm.prank(partner1);
        uint256 revenueTokenId = assetRegistry.mintRevenueTokens(vehicleId, REVENUE_TOKEN_PRICE, supply, maturityDate);

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
    // Retirement Tests

    function testRetireAssetAndBurnTokens() public {
        _ensureState(SetupState.RevenueTokensMinted);
        // Verify initial state
        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), REVENUE_TOKEN_SUPPLY);
        uint256 expectedCollateral = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        assertCollateralState(scenario.assetId, 100000e6, expectedCollateral, true);

        // Partner retires asset
        vm.prank(partner1);
        vm.expectEmit(true, true, false, true);
        emit IAssetRegistry.AssetRetired(scenario.assetId, partner1, REVENUE_TOKEN_SUPPLY, expectedCollateral);
        assetRegistry.retireAssetAndBurnTokens(scenario.assetId);

        // Verify tokens burned
        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), 0);
        assertEq(roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId), 0);

        // Verify status updated
        assertEq(uint8(assetRegistry.getAssetStatus(scenario.assetId)), uint8(AssetLib.AssetStatus.Retired));

        // Verify collateral released
        // Collateral should be unlocked (locked = false)
        (,, bool locked,,) = treasury.getAssetCollateralInfo(scenario.assetId);
        assertFalse(locked);
    }

    function testRetireAssetAndBurnTokensPartialHolding() public {
        _ensureState(SetupState.RevenueTokensMinted);
        // Partner sells some tokens
        vm.prank(partner1);
        roboshareTokens.safeTransferFrom(partner1, buyer, scenario.revenueTokenId, 100, "");

        // Partner tries to retire
        vm.prank(partner1);
        vm.expectRevert(VehicleRegistry.OutstandingTokensHeldByOthers.selector);
        assetRegistry.retireAssetAndBurnTokens(scenario.assetId);
    }

    function testBurnRevenueTokens() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 burnAmount = 500;

        vm.prank(partner1);
        assetRegistry.burnRevenueTokens(scenario.assetId, burnAmount);

        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), REVENUE_TOKEN_SUPPLY - burnAmount);
        assertEq(roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId), REVENUE_TOKEN_SUPPLY - burnAmount);
    }

    function testRetireAsset() public {
        _ensureState(SetupState.RevenueTokensMinted);
        // Burn all tokens first
        vm.prank(partner1);
        assetRegistry.burnRevenueTokens(scenario.assetId, REVENUE_TOKEN_SUPPLY);

        // Now retire
        vm.prank(partner1);
        assetRegistry.retireAsset(scenario.assetId);

        assertEq(uint8(assetRegistry.getAssetStatus(scenario.assetId)), uint8(AssetLib.AssetStatus.Retired));
        (,, bool locked,,) = treasury.getAssetCollateralInfo(scenario.assetId);
        assertFalse(locked);
    }

    function testRetireAssetNotOwner() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.prank(partner2);
        vm.expectRevert(IAssetRegistry.NotAssetOwner.selector);
        assetRegistry.retireAssetAndBurnTokens(scenario.assetId);
    }

    // Settlement Tests

    function testSettleAsset() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 topUpAmount = 1000e6;

        // Partner approves top-up
        deal(address(usdc), partner1, topUpAmount);
        vm.prank(partner1);
        usdc.approve(address(treasury), topUpAmount);

        // Calculate expected settlement amounts
        (uint256 base, uint256 earningsBuffer,,) =
            calculateExpectedCollateral(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        uint256 investorPool = base + earningsBuffer;
        uint256 expectedSettlementAmount = investorPool + topUpAmount;
        uint256 expectedPerToken = expectedSettlementAmount / REVENUE_TOKEN_SUPPLY;

        vm.prank(partner1);
        vm.expectEmit(true, true, false, true);
        emit IAssetRegistry.AssetSettled(scenario.assetId, partner1, expectedSettlementAmount, expectedPerToken);
        assetRegistry.settleAsset(scenario.assetId, topUpAmount);

        assertEq(uint8(assetRegistry.getAssetStatus(scenario.assetId)), uint8(AssetLib.AssetStatus.Retired));
    }

    function testLiquidateAssetMaturity() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Get maturity date from RoboshareTokens (now stored in TokenInfo)
        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(scenario.revenueTokenId);

        // Warp to maturity
        vm.warp(maturityDate + 1);

        // Calculate expected liquidation amounts (Investor Pool = Base + Earnings Buffer)
        (uint256 base,,,) = calculateExpectedCollateral(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);

        // In the new logic, if matured, earningsBuffer is separated from investorPool.
        // In executeLiquidation, the partnerRefund (earningsBuffer) is ignored/lost if it exists.
        // So investors only get Base + Reserved.
        uint256 expectedLiquidationAmount = base;
        uint256 expectedPerToken = expectedLiquidationAmount / REVENUE_TOKEN_SUPPLY;

        vm.expectEmit(true, true, false, true);
        emit IAssetRegistry.AssetExpired(scenario.assetId, expectedLiquidationAmount, expectedPerToken);

        assetRegistry.liquidateAsset(scenario.assetId);

        assertEq(uint8(assetRegistry.getAssetStatus(scenario.assetId)), uint8(AssetLib.AssetStatus.Expired));
    }

    function testLiquidateAssetNotEligible() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Try to liquidate before maturity and while solvent
        vm.expectRevert(
            abi.encodeWithSelector(IAssetRegistry.AssetNotEligibleForLiquidation.selector, scenario.assetId)
        );
        assetRegistry.liquidateAsset(scenario.assetId);
    }
    // New Tests for Settlement and Liquidation Branches

    function testSettleAssetNotOwner() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.prank(partner2); // partner2 is authorized but not owner
        vm.expectRevert(IAssetRegistry.NotAssetOwner.selector);
        assetRegistry.settleAsset(scenario.assetId, 0);
    }

    function testSettleAssetNotActive() public {
        _ensureState(SetupState.AssetRegistered); // Status is Pending
        vm.prank(partner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAssetRegistry.AssetNotActive.selector, scenario.assetId, AssetLib.AssetStatus.Pending
            )
        );
        assetRegistry.settleAsset(scenario.assetId, 0);
    }

    function testLiquidateAssetNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetNotFound.selector, 999));
        assetRegistry.liquidateAsset(999);
    }

    function testLiquidateAssetAlreadySettled() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Settle the asset first
        vm.prank(partner1);
        assetRegistry.settleAsset(scenario.assetId, 0);

        // Try to liquidate an already settled asset
        vm.expectRevert(
            abi.encodeWithSelector(
                IAssetRegistry.AssetAlreadySettled.selector, scenario.assetId, AssetLib.AssetStatus.Retired
            )
        );
        assetRegistry.liquidateAsset(scenario.assetId);
    }

    function testClaimSettlementNotFound() public {
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetNotFound.selector, 999));
        vm.prank(partner1);
        assetRegistry.claimSettlement(999, false);
    }

    function testClaimSettlementNotSettled() public {
        _ensureState(SetupState.RevenueTokensMinted); // Asset is Active, not Retired or Expired
        vm.prank(partner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAssetRegistry.AssetNotSettled.selector, scenario.assetId, AssetLib.AssetStatus.Active
            )
        );
        assetRegistry.claimSettlement(scenario.assetId, false);
    }

    function testClaimSettlementNoTokens() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Liquidate the asset to make it eligible for claiming
        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(scenario.revenueTokenId);
        vm.warp(maturityDate + 1);
        assetRegistry.liquidateAsset(scenario.assetId);

        // Try to claim settlement as an address with no tokens for this asset

        vm.prank(unauthorized);

        vm.expectRevert(
            abi.encodeWithSelector(IAssetRegistry.InsufficientTokenBalance.selector, scenario.revenueTokenId, 1, 0)
        );

        assetRegistry.claimSettlement(scenario.assetId, false);
    }

    // Branch Coverage Improvement Tests

    function testRetireAssetAndBurnTokensZeroSupply() public {
        _ensureState(SetupState.RevenueTokensMinted);

        // Burn all tokens first using the public burn function
        vm.prank(partner1);
        assetRegistry.burnRevenueTokens(scenario.assetId, REVENUE_TOKEN_SUPPLY);

        // Now call retireAssetAndBurnTokens with 0 supply
        // This exercises the `if (totalSupply > 0)` else branch
        vm.prank(partner1);
        assetRegistry.retireAssetAndBurnTokens(scenario.assetId);

        assertEq(uint8(assetRegistry.getAssetStatus(scenario.assetId)), uint8(AssetLib.AssetStatus.Retired));
    }

    function testIsAuthorizedForAssetNoBalance() public {
        _ensureState(SetupState.AssetRegistered); // Partner1 owns asset

        // Partner2 is authorized (via SetupState) but does not own the asset
        assertTrue(partnerManager.isAuthorizedPartner(partner2));
        assertFalse(assetRegistry.isAuthorizedForAsset(partner2, scenario.assetId));
    }
}
