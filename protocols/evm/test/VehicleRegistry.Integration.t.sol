// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { AssetLib, VehicleLib, CollateralLib, ProtocolLib, EarningsLib } from "../contracts/Libraries.sol";
import { IAssetRegistry } from "../contracts/interfaces/IAssetRegistry.sol";
import { ITreasury } from "../contracts/interfaces/ITreasury.sol";
import { PartnerManager } from "../contracts/PartnerManager.sol";
import { VehicleRegistry } from "../contracts/VehicleRegistry.sol";

contract VehicleRegistryIntegrationTest is BaseTest {
    function setUp() public {
        _ensureState(SetupState.InitialAccountsSetup);
    }

    function testRetireAssetOutstandingTokens() public {
        _ensureState(SetupState.BuffersLocked);
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
        ) = _generateVehicleData(1);

        vm.expectEmit(true, true, false, true, address(assetRegistry));
        emit IAssetRegistry.AssetRegistered(1, partner1, ASSET_VALUE, AssetLib.AssetStatus.Pending);

        vm.expectEmit(true, true, false, true, address(assetRegistry));
        emit VehicleRegistry.VehicleRegistered(1, partner1, vin);

        vm.prank(partner1);
        uint256 newVehicleId = assetRegistry.registerAsset(
            abi.encode(vin, make, model, year, manufacturerId, optionCodes, metadataURI), ASSET_VALUE
        );

        assertEq(newVehicleId, 1);
        _assertVehicleState(newVehicleId, partner1, vin, true);
        assertEq(roboshareTokens.getNextTokenId(), 3);
    }

    function testRegisterMultipleVehicles() public {
        uint256[] memory p1Assets = _createMultipleTestVehicles(partner1, 1);
        uint256[] memory p2Assets = _createMultipleTestVehicles(partner2, 1);

        assertEq(p1Assets[0], 1);
        assertEq(p2Assets[0], 3);
        _assertVehicleState(p1Assets[0], partner1, "", true); // Skip exact VIN check
        _assertVehicleState(p2Assets[0], partner2, "", true);
        assertEq(roboshareTokens.getNextTokenId(), 5);
    }

    // Revenue Share Token Tests

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
        (uint256 assetId, uint256 revenueTokenId, uint256 tokenSupply, uint256 listingId) = assetRegistry.registerAssetMintAndList(
            vehicleData, ASSET_VALUE, REVENUE_TOKEN_PRICE, block.timestamp + 365 days, 10_000, 1_000, 30 days, true
        );
        vm.stopPrank();

        // Verify: Asset was registered and activated
        assertTrue(assetRegistry.assetExists(assetId));
        assertEq(uint8(assetRegistry.getAssetStatus(assetId)), uint8(AssetLib.AssetStatus.Active));

        // Verify: Revenue tokens were minted (but transferred to marketplace for escrow)
        assertEq(roboshareTokens.balanceOf(address(marketplace), revenueTokenId), tokenSupply);

        // Verify: Listing was created with full supply at face value
        _assertListingState(listingId, revenueTokenId, tokenSupply, REVENUE_TOKEN_PRICE, partner1, true, true);
    }

    function testMintRevenueTokensAndList() public {
        _ensureState(SetupState.InitialAccountsSetup);

        vm.startPrank(admin);
        router.setMarketplace(address(marketplace));
        marketplace.grantRole(marketplace.AUTHORIZED_CONTRACT_ROLE(), address(router));
        vm.stopPrank();

        vm.startPrank(partner1);
        uint256 assetId = assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            ),
            ASSET_VALUE
        );

        (uint256 revenueTokenId, uint256 tokenSupply, uint256 listingId) = assetRegistry.mintRevenueTokensAndList(
            assetId, REVENUE_TOKEN_PRICE, block.timestamp + 365 days, 10_000, 1_000, 30 days, true
        );
        vm.stopPrank();

        assertEq(uint8(assetRegistry.getAssetStatus(assetId)), uint8(AssetLib.AssetStatus.Active));
        assertEq(roboshareTokens.balanceOf(address(marketplace), revenueTokenId), tokenSupply);
        _assertListingState(listingId, revenueTokenId, tokenSupply, REVENUE_TOKEN_PRICE, partner1, true, true);
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

    // Access Control Tests

    function testRegisterAssetUnauthorizedPartner() public {
        vm.expectRevert(PartnerManager.UnauthorizedPartner.selector);
        vm.prank(unauthorized);
        assetRegistry.registerAsset(
            abi.encode(
                TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
            ),
            ASSET_VALUE
        );
    }

    function testUpdateMetadataUnauthorizedPartner() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.expectRevert(PartnerManager.UnauthorizedPartner.selector);
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
        ) = _generateVehicleData(3);
        vm.expectRevert(VehicleRegistry.VehicleAlreadyExists.selector);
        vm.prank(partner2);
        assetRegistry.registerAsset(
            abi.encode(TEST_VIN, make, model, year, manufacturerId, optionCodes, metadataURI), ASSET_VALUE
        );
    }

    function testUpdateMetadataVehicleDoesNotExist() public {
        vm.expectRevert(VehicleRegistry.VehicleDoesNotExist.selector);
        vm.prank(partner1);
        assetRegistry.updateVehicleMetadata(999, "ipfs://QmYwAPJzv5CZsnAzt8auVTLpG1bG6dkprdFM5ocTyBCQb");
    }

    function testPreviewMintRevenueTokensAssetNotFound() public {
        _ensureState(SetupState.InitialAccountsSetup);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetNotFound.selector, 999));
        assetRegistry.previewMintRevenueTokens(999, partner1, REVENUE_TOKEN_PRICE);
    }

    function testPreviewMintRevenueTokensUnauthorizedPartner() public {
        _ensureState(SetupState.AssetRegistered);
        vm.expectRevert(PartnerManager.UnauthorizedPartner.selector);
        assetRegistry.previewMintRevenueTokens(scenario.assetId, unauthorized, REVENUE_TOKEN_PRICE);
    }

    function testPreviewMintRevenueTokensNotAssetOwner() public {
        _ensureState(SetupState.AssetRegistered);
        vm.expectRevert(IAssetRegistry.NotAssetOwner.selector);
        assetRegistry.previewMintRevenueTokens(scenario.assetId, partner2, REVENUE_TOKEN_PRICE);
    }

    function testPreviewMintRevenueTokensAlreadyMinted() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.expectRevert(IAssetRegistry.RevenueTokensAlreadyMinted.selector);
        assetRegistry.previewMintRevenueTokens(scenario.assetId, partner1, REVENUE_TOKEN_PRICE);
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

    function testFuzzRegisterAssetAndMintTokens(uint256 assetValue, uint256 tokenPrice) public {
        // Constraints:
        // 1. tokenPrice > 0 (avoid div by zero)
        // 2. assetValue >= tokenPrice (to ensure supply >= 1)
        // 3. Cap assetValue at 1B USDC to avoid overflow/unrealistic scenarios
        vm.assume(tokenPrice > 0);
        vm.assume(assetValue >= tokenPrice && assetValue <= 1_000_000_000 * 1e6);

        _ensureState(SetupState.InitialAccountsSetup);

        // Setup: Configure marketplace on Router and grant role to Router
        vm.startPrank(admin);
        router.setMarketplace(address(marketplace));
        marketplace.grantRole(marketplace.AUTHORIZED_CONTRACT_ROLE(), address(router));
        vm.stopPrank();

        // Partner must approve marketplace for token transfers
        vm.startPrank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);

        uint256 maturityDate = block.timestamp + 365 days;

        bytes memory vehicleData = abi.encode(
            TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        (uint256 assetId, uint256 revenueTokenId, uint256 actualSupply, uint256 listingId) = assetRegistry.registerAssetMintAndList(
            vehicleData, assetValue, tokenPrice, maturityDate, 10_000, 1_000, 30 days, true
        );
        vm.stopPrank();

        assertEq(roboshareTokens.balanceOf(address(marketplace), revenueTokenId), actualSupply);
        assertEq(actualSupply, assetValue / tokenPrice, "Supply should be derived from asset value and price");
        assertTrue(listingId > 0);

        // Buffers are funded when listing ends
        CollateralLib.CollateralInfo memory info = treasury.getAssetCollateralInfo(assetId);
        assertEq(info.baseCollateral, 0);
        assertEq(info.isLocked, false);
    }

    function testFuzzRegisterAssetMintAndList(uint256 assetValue, uint256 tokenPrice) public {
        // Constraints:
        // 1. tokenPrice >= 1 USDC (1e6)
        // 2. assetValue >= tokenPrice (to ensure supply >= 1)
        // 3. Cap assetValue at 1B USDC to avoid overflow/unrealistic scenarios
        vm.assume(tokenPrice >= 1e6);
        vm.assume(assetValue >= tokenPrice && assetValue <= 1_000_000_000 * 1e6);

        _ensureState(SetupState.InitialAccountsSetup);

        // Setup: Configure marketplace on Router and grant role to Router
        vm.startPrank(admin);
        router.setMarketplace(address(marketplace));
        marketplace.grantRole(marketplace.AUTHORIZED_CONTRACT_ROLE(), address(router));
        vm.stopPrank();

        // Partner must approve marketplace for token transfers
        vm.startPrank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);

        // Use dynamic data
        bytes memory vehicleData = abi.encode(
            TEST_VIN, TEST_MAKE, TEST_MODEL, TEST_YEAR, TEST_MANUFACTURER_ID, TEST_OPTION_CODES, TEST_METADATA_URI
        );

        // Execute
        (, uint256 revenueTokenId, uint256 tokenSupply, uint256 listingId) = assetRegistry.registerAssetMintAndList(
            vehicleData, assetValue, tokenPrice, block.timestamp + 365 days, 10_000, 1_000, 30 days, true
        );
        vm.stopPrank();

        // Verify supply calculation
        uint256 expectedSupply = assetValue / tokenPrice;
        assertEq(tokenSupply, expectedSupply, "Supply should match calculated value");

        // Verify: Revenue tokens were minted and transferred to marketplace
        assertEq(roboshareTokens.balanceOf(address(marketplace), revenueTokenId), tokenSupply);

        // Verify: Listing was created with full supply
        _assertListingState(listingId, revenueTokenId, tokenSupply, tokenPrice, partner1, true, true);
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

    function testSetAssetStatus() public {
        _ensureState(SetupState.AssetRegistered);
        uint256 assetId = scenario.assetId;

        // Initial status is Pending
        assertEq(uint8(assetRegistry.getAssetStatus(assetId)), uint8(AssetLib.AssetStatus.Pending));

        // Valid transition: Pending -> Active (called by Router)
        vm.startPrank(address(router));
        assetRegistry.setAssetStatus(assetId, AssetLib.AssetStatus.Active);
        vm.stopPrank();

        assertEq(uint8(assetRegistry.getAssetStatus(assetId)), uint8(AssetLib.AssetStatus.Active));
    }

    function testSetAssetStatusUnauthorizedCaller() public {
        _ensureState(SetupState.AssetRegistered);
        uint256 assetId = scenario.assetId;

        // Invalid access: unauthorized caller
        vm.startPrank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, assetRegistry.ROUTER_ROLE()
            )
        );
        assetRegistry.setAssetStatus(assetId, AssetLib.AssetStatus.Pending);
        vm.stopPrank();
    }

    function testSetAssetStatusAssetNotFound() public {
        vm.startPrank(address(router));
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetNotFound.selector, 999));
        assetRegistry.setAssetStatus(999, AssetLib.AssetStatus.Active);
        vm.stopPrank();
    }

    // Retirement Tests

    function testRetireAssetAndBurnTokens() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        // Verify initial state (buyer holds purchased tokens; escrow may still hold remainder)
        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), 0);
        CollateralLib.CollateralInfo memory info = treasury.getAssetCollateralInfo(scenario.assetId);
        uint256 expectedCollateral = info.totalCollateral;
        _assertCollateralState(scenario.assetId, info.baseCollateral, expectedCollateral, true);

        // Acquire all tokens from buyers to allow retirement
        uint256 buyerBalance = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        vm.prank(buyer);
        roboshareTokens.safeTransferFrom(buyer, partner1, scenario.revenueTokenId, buyerBalance, "");

        // Partner retires asset
        vm.startPrank(partner1);

        // Expect AssetStatusUpdated from VehicleRegistry
        vm.expectEmit(true, true, true, true, address(assetRegistry));
        emit IAssetRegistry.AssetStatusUpdated(
            scenario.assetId, AssetLib.AssetStatus.Active, AssetLib.AssetStatus.Retired
        );

        // Expect CollateralReleased from Treasury
        vm.expectEmit(true, true, true, true, address(treasury));
        emit ITreasury.CollateralReleased(scenario.assetId, partner1, expectedCollateral);

        // Expect AssetRetired from VehicleRegistry
        vm.expectEmit(true, true, true, true, address(assetRegistry));
        emit IAssetRegistry.AssetRetired(scenario.assetId, partner1, totalSupply, expectedCollateral);

        assetRegistry.retireAssetAndBurnTokens(scenario.assetId);
        vm.stopPrank();

        // Verify tokens burned
        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), 0);
        assertEq(roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId), 0);

        // Verify status updated
        assertEq(uint8(assetRegistry.getAssetStatus(scenario.assetId)), uint8(AssetLib.AssetStatus.Retired));

        // Verify collateral released
        // Collateral should be unlocked (locked = false)
        assertFalse(treasury.getAssetCollateralInfo(scenario.assetId).isLocked);
    }

    function testRetireAssetAndBurnTokensNoPurchase() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);

        // Verify initial state (tokens escrowed in marketplace)
        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), 0);
        assertEq(roboshareTokens.balanceOf(address(marketplace), scenario.revenueTokenId), totalSupply);

        CollateralLib.CollateralInfo memory info = treasury.getAssetCollateralInfo(scenario.assetId);
        uint256 expectedCollateral = info.totalCollateral;
        _assertCollateralState(scenario.assetId, info.baseCollateral, expectedCollateral, false);

        vm.startPrank(partner1);

        // Expect AssetStatusUpdated from VehicleRegistry
        vm.expectEmit(true, true, true, true, address(assetRegistry));
        emit IAssetRegistry.AssetStatusUpdated(
            scenario.assetId, AssetLib.AssetStatus.Active, AssetLib.AssetStatus.Retired
        );

        // Expect AssetRetired from VehicleRegistry
        vm.expectEmit(true, true, true, true, address(assetRegistry));
        emit IAssetRegistry.AssetRetired(scenario.assetId, partner1, totalSupply, expectedCollateral);

        assetRegistry.retireAssetAndBurnTokens(scenario.assetId);
        vm.stopPrank();

        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), 0);
        assertEq(roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId), 0);
        assertEq(uint8(assetRegistry.getAssetStatus(scenario.assetId)), uint8(AssetLib.AssetStatus.Retired));
        assertFalse(treasury.getAssetCollateralInfo(scenario.assetId).isLocked);
    }

    function testRetireAssetAndBurnTokensEscrowOnlyBranch() public {
        _ensureState(SetupState.RevenueTokensMinted);

        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), 0);
        assertEq(roboshareTokens.balanceOf(address(marketplace), scenario.revenueTokenId), totalSupply);

        vm.prank(partner1);
        assetRegistry.retireAssetAndBurnTokens(scenario.assetId);

        assertEq(roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId), 0);
    }

    function testRetireAssetAndBurnTokensPartialHolding() public {
        _ensureState(SetupState.RevenueTokensListed);

        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(scenario.listingId, 100);
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(scenario.listingId, 100);
        vm.stopPrank();

        vm.prank(partner1);
        marketplace.endListing(scenario.listingId);

        vm.prank(buyer);
        marketplace.claimTokens(scenario.listingId);

        // Partner tries to retire
        vm.prank(partner1);
        vm.expectRevert(VehicleRegistry.OutstandingTokensHeldByOthers.selector);
        assetRegistry.retireAssetAndBurnTokens(scenario.assetId);
    }

    function testRetireAssetAndBurnTokensWithBuybackAndEscrow() public {
        _ensureState(SetupState.RevenueTokensMinted);

        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        uint256 purchaseAmount = totalSupply / 5;

        vm.startPrank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.createListing(
            scenario.revenueTokenId, totalSupply, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
        );
        vm.stopPrank();

        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(listingId, purchaseAmount);
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(listingId, purchaseAmount);
        vm.stopPrank();

        vm.prank(partner1);
        usdc.approve(address(treasury), type(uint256).max);

        vm.prank(partner1);
        marketplace.endListing(listingId);

        vm.prank(buyer);
        marketplace.claimTokens(listingId);

        uint256 soldSupply = roboshareTokens.getSoldSupply(scenario.revenueTokenId);
        assertEq(soldSupply, purchaseAmount);
        assertGt(roboshareTokens.balanceOf(address(marketplace), scenario.revenueTokenId), 0);

        // Buyer lists their tokens on secondary market
        vm.startPrank(buyer);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 buyerListingId = marketplace.createListing(
            scenario.revenueTokenId, purchaseAmount, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
        );
        vm.stopPrank();

        // Partner buys back all sold tokens
        (,, expectedPayment) = marketplace.calculatePurchaseCost(buyerListingId, purchaseAmount);
        vm.startPrank(partner1);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(buyerListingId, purchaseAmount);
        vm.stopPrank();

        // Buyer ends listing to release escrowed tokens to partner
        vm.prank(buyer);
        marketplace.endListing(buyerListingId);

        // Partner claims purchased tokens
        vm.prank(partner1);
        marketplace.claimTokens(buyerListingId);

        // Partner should now hold all sold tokens; escrow holds unsold tokens
        uint256 partnerBalance = roboshareTokens.balanceOf(partner1, scenario.revenueTokenId);
        uint256 escrowBalance = roboshareTokens.balanceOf(address(marketplace), scenario.revenueTokenId);
        assertEq(partnerBalance, purchaseAmount);
        assertEq(partnerBalance, soldSupply);
        assertEq(partnerBalance + escrowBalance, totalSupply);

        vm.prank(partner1);
        assetRegistry.retireAssetAndBurnTokens(scenario.assetId);

        assertEq(roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId), 0);
        assertEq(uint8(assetRegistry.getAssetStatus(scenario.assetId)), uint8(AssetLib.AssetStatus.Retired));
    }

    function testRetireAssetAndBurnTokensOutstandingTokensHeldByOthers() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // Buyer still holds sold tokens; partner holds none.
        vm.prank(partner1);
        vm.expectRevert(VehicleRegistry.OutstandingTokensHeldByOthers.selector);
        assetRegistry.retireAssetAndBurnTokens(scenario.assetId);
    }

    function testRetireAssetAndBurnTokensAllTokensHeldByPartner() public {
        _ensureState(SetupState.RevenueTokensMinted);

        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);

        vm.startPrank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.createListing(
            scenario.revenueTokenId, totalSupply, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
        );
        vm.stopPrank();

        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(listingId, totalSupply);
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(listingId, totalSupply);
        vm.stopPrank();

        vm.prank(partner1);
        usdc.approve(address(treasury), type(uint256).max);

        vm.prank(partner1);
        marketplace.endListing(listingId);

        vm.prank(buyer);
        marketplace.claimTokens(listingId);

        vm.prank(buyer);
        roboshareTokens.safeTransferFrom(buyer, partner1, scenario.revenueTokenId, totalSupply, "");

        vm.prank(partner1);
        assetRegistry.retireAssetAndBurnTokens(scenario.assetId);

        assertEq(roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId), 0);
    }

    function testBurnRevenueTokens() public {
        _ensureState(SetupState.RevenueTokensListed);
        uint256 initialSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        uint256 burnAmount = initialSupply / 2;

        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(scenario.listingId, burnAmount);
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(scenario.listingId, burnAmount);
        vm.stopPrank();

        vm.prank(partner1);
        marketplace.endListing(scenario.listingId);

        vm.prank(buyer);
        marketplace.claimTokens(scenario.listingId);

        vm.prank(buyer);
        roboshareTokens.safeTransferFrom(buyer, partner1, scenario.revenueTokenId, burnAmount, "");

        vm.prank(partner1);
        assetRegistry.burnRevenueTokens(scenario.assetId, burnAmount);

        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), 0);
        assertEq(roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId), initialSupply - burnAmount);
    }

    function testBurnRevenueTokensAssetNotFound() public {
        _ensureState(SetupState.InitialAccountsSetup);
        vm.prank(partner1);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetNotFound.selector, 999));
        assetRegistry.burnRevenueTokens(999, 100);
    }

    function testRetireAsset() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);

        // List full supply and sell to buyer
        vm.startPrank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.createListing(
            scenario.revenueTokenId, totalSupply, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
        );
        vm.stopPrank();

        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(listingId, totalSupply);
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(listingId, totalSupply);
        vm.stopPrank();

        vm.prank(partner1);
        usdc.approve(address(treasury), type(uint256).max);

        vm.prank(partner1);
        marketplace.endListing(listingId);

        vm.prank(buyer);
        marketplace.claimTokens(listingId);

        vm.prank(buyer);
        roboshareTokens.safeTransferFrom(buyer, partner1, scenario.revenueTokenId, totalSupply, "");

        // Burn all tokens first
        vm.prank(partner1);
        assetRegistry.burnRevenueTokens(scenario.assetId, totalSupply);

        // Now retire
        vm.prank(partner1);
        assetRegistry.retireAsset(scenario.assetId);

        assertEq(uint8(assetRegistry.getAssetStatus(scenario.assetId)), uint8(AssetLib.AssetStatus.Retired));
        assertFalse(treasury.getAssetCollateralInfo(scenario.assetId).isLocked);
    }

    function testRetireAssetAssetNotActive() public {
        _ensureState(SetupState.AssetRegistered);
        // Asset is registered but not active (Pending)

        vm.prank(partner1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAssetRegistry.AssetNotActive.selector, scenario.assetId, AssetLib.AssetStatus.Pending
            )
        );
        assetRegistry.retireAsset(scenario.assetId);
    }

    function testRetireAssetNotOwner() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.prank(partner2);
        vm.expectRevert(IAssetRegistry.NotAssetOwner.selector);
        assetRegistry.retireAsset(scenario.assetId);
    }

    function testRetireAssetAndBurnTokensAssetNotFound() public {
        _ensureState(SetupState.InitialAccountsSetup);
        vm.prank(partner1);
        vm.expectRevert(abi.encodeWithSelector(IAssetRegistry.AssetNotFound.selector, 999));
        assetRegistry.retireAssetAndBurnTokens(999);
    }

    function testRetireAssetNotAssetOwner() public {
        _ensureState(SetupState.RevenueTokensMinted);
        vm.prank(partner2);
        vm.expectRevert(IAssetRegistry.NotAssetOwner.selector);
        assetRegistry.retireAssetAndBurnTokens(scenario.assetId);
    }

    // Settlement Tests

    function testSettleAsset() public {
        _ensureState(SetupState.RevenueTokensClaimed);
        uint256 topUpAmount = TOP_UP_AMOUNT;

        // Partner approves top-up
        vm.prank(partner1);
        usdc.approve(address(treasury), topUpAmount);

        CollateralLib.CollateralInfo memory info = treasury.getAssetCollateralInfo(scenario.assetId);
        uint256 investorPool = info.baseCollateral + info.reservedForLiquidation;
        uint256 expectedSettlementAmount = investorPool + topUpAmount;
        uint256 investorSupply = roboshareTokens.balanceOf(buyer, scenario.revenueTokenId);
        uint256 expectedPerToken = expectedSettlementAmount / investorSupply;

        vm.prank(partner1);
        vm.expectEmit(true, true, false, true);
        emit IAssetRegistry.AssetSettled(scenario.assetId, partner1, expectedSettlementAmount, expectedPerToken);
        assetRegistry.settleAsset(scenario.assetId, topUpAmount);

        assertEq(uint8(assetRegistry.getAssetStatus(scenario.assetId)), uint8(AssetLib.AssetStatus.Retired));
    }

    function testLiquidateAssetMaturity() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        // Get maturity date from RoboshareTokens (now stored in TokenInfo)
        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(scenario.revenueTokenId);

        // Warp to maturity
        vm.warp(maturityDate + 1);

        uint256 expectedLiquidationAmount = _expectedLiquidationAfterMissedShortfall();
        assetRegistry.liquidateAsset(scenario.assetId);
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        uint256 expectedPerToken = totalSupply > 0 ? expectedLiquidationAmount / totalSupply : 0;

        (bool isSettled, uint256 settlementPerToken, uint256 totalSettlementPool) =
            treasury.assetSettlements(scenario.assetId);
        assertTrue(isSettled);
        assertEq(totalSettlementPool, expectedLiquidationAmount);
        assertEq(settlementPerToken, expectedPerToken);
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

    function testLiquidateAssetAfterMissedEarningsShortfall() public {
        _ensureState(SetupState.RevenueTokensClaimed);

        (,,,, uint256 lastEventTimestamp,,,,) = treasury.assetEarnings(scenario.assetId);
        uint256 maturityDate = roboshareTokens.getTokenMaturityDate(scenario.revenueTokenId);
        CollateralLib.CollateralInfo memory infoBefore = treasury.getAssetCollateralInfo(scenario.assetId);
        uint256 targetYieldBP = roboshareTokens.getTargetYieldBP(scenario.revenueTokenId);
        uint256 elapsedToDeplete = (infoBefore.earningsBuffer * ProtocolLib.YEARLY_INTERVAL * ProtocolLib.BP_PRECISION)
            / (infoBefore.initialBaseCollateral * targetYieldBP);
        uint256 warpTo = lastEventTimestamp + elapsedToDeplete + 1;
        require(warpTo < maturityDate, "Test assumes delinquency before maturity");
        vm.warp(warpTo);

        uint256 expectedLiquidationAmount = _expectedLiquidationAfterMissedShortfall();

        assetRegistry.liquidateAsset(scenario.assetId);

        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        uint256 expectedPerToken = totalSupply > 0 ? expectedLiquidationAmount / totalSupply : 0;

        (bool isSettled, uint256 settlementPerToken, uint256 totalSettlementPool) =
            treasury.assetSettlements(scenario.assetId);
        assertTrue(isSettled);
        assertEq(totalSettlementPool, expectedLiquidationAmount);
        assertEq(settlementPerToken, expectedPerToken);
        assertEq(uint8(assetRegistry.getAssetStatus(scenario.assetId)), uint8(AssetLib.AssetStatus.Expired));
    }

    function _expectedLiquidationAfterMissedShortfall() internal view returns (uint256) {
        CollateralLib.CollateralInfo memory infoBefore = treasury.getAssetCollateralInfo(scenario.assetId);
        (,,,, uint256 lastEventTimestamp,,,,) = treasury.assetEarnings(scenario.assetId);
        uint256 elapsed = block.timestamp - lastEventTimestamp;
        uint256 targetYieldBP = roboshareTokens.getTargetYieldBP(scenario.revenueTokenId);
        uint256 baseEarnings = EarningsLib.calculateEarnings(infoBefore.initialBaseCollateral, elapsed, targetYieldBP);
        uint256 reservedIncrease = baseEarnings < infoBefore.earningsBuffer ? baseEarnings : infoBefore.earningsBuffer;
        return infoBefore.baseCollateral + infoBefore.reservedForLiquidation + reservedIncrease;
    }
    // New Tests for Settlement and Liquidation Branches

    function testSettleAssetNotAssetOwner() public {
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

    function testClaimSettlementAssetNotFound() public {
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
        uint256 totalSupply = roboshareTokens.getRevenueTokenSupply(scenario.revenueTokenId);
        vm.startPrank(partner1);
        roboshareTokens.setApprovalForAll(address(marketplace), true);
        uint256 listingId = marketplace.createListing(
            scenario.revenueTokenId, totalSupply, REVENUE_TOKEN_PRICE, LISTING_DURATION, true
        );
        vm.stopPrank();

        (,, uint256 expectedPayment) = marketplace.calculatePurchaseCost(listingId, totalSupply);
        vm.startPrank(buyer);
        usdc.approve(address(marketplace), expectedPayment);
        marketplace.purchaseTokens(listingId, totalSupply);
        vm.stopPrank();

        vm.prank(partner1);
        usdc.approve(address(treasury), type(uint256).max);

        vm.prank(partner1);
        marketplace.endListing(listingId);

        vm.prank(buyer);
        marketplace.claimTokens(listingId);

        vm.prank(buyer);
        roboshareTokens.safeTransferFrom(buyer, partner1, scenario.revenueTokenId, totalSupply, "");

        vm.prank(partner1);
        assetRegistry.burnRevenueTokens(scenario.assetId, totalSupply);

        // Now call retireAssetAndBurnTokens with 0 supply
        // This exercises the `if (totalSupply > 0)` else branch
        vm.prank(partner1);
        assetRegistry.retireAssetAndBurnTokens(scenario.assetId);

        assertEq(uint8(assetRegistry.getAssetStatus(scenario.assetId)), uint8(AssetLib.AssetStatus.Retired));
    }
}
