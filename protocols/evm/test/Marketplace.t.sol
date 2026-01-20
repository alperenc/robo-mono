// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { MockUSDC } from "../contracts/mocks/MockUSDC.sol";
import { RoboshareTokens } from "../contracts/RoboshareTokens.sol";
import { PartnerManager } from "../contracts/PartnerManager.sol";
import { RegistryRouter } from "../contracts/RegistryRouter.sol";
import { Treasury } from "../contracts/Treasury.sol";
import { Marketplace } from "../contracts/Marketplace.sol";
contract MarketplaceTest is BaseTest {

    // Local constants for test values
    uint256 constant EXTENSION_DURATION_DAYS = 7;

    function setUp() public {
        _ensureState(SetupState.ContractsDeployed);
    }

    // Initialization Tests

    function testInitialization() public view {
        // Check contract references
        assertEq(address(marketplace.roboshareTokens()), address(roboshareTokens));
        assertEq(address(marketplace.partnerManager()), address(partnerManager));
        assertEq(address(marketplace.router()), address(router));
        assertEq(address(marketplace.treasury()), address(treasury));
        assertEq(address(marketplace.usdc()), address(usdc));

        // Check initial state
        assertEq(marketplace.getCurrentListingId(), 1);

        // Check roles
        assertTrue(marketplace.hasRole(marketplace.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(marketplace.hasRole(marketplace.UPGRADER_ROLE(), admin));
    }

    function testInitializationZeroAddresses() public {
        Marketplace newImpl = new Marketplace();

        vm.expectRevert(Marketplace.ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address)",
                address(0), // zero admin address
                address(roboshareTokens),
                address(partnerManager),
                address(router),
                address(treasury),
                address(usdc)
            )
        );
    }

    // Admin Functions Tests

    function testUpdatePartnerManager() public {
        PartnerManager newPartnerManager = new PartnerManager();

        vm.startPrank(admin);
        marketplace.updatePartnerManager(address(newPartnerManager));
        vm.stopPrank();

        assertEq(address(marketplace.partnerManager()), address(newPartnerManager));
    }

    function testUpdatePartnerManagerZeroAddress() public {
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        vm.startPrank(admin);
        marketplace.updatePartnerManager(address(0));
        vm.stopPrank();
    }

    function testUpdatePartnerManagerUnauthorized() public {
        PartnerManager newPartnerManager = new PartnerManager();

        vm.expectRevert();
        vm.prank(unauthorized);
        marketplace.updatePartnerManager(address(newPartnerManager));
    }

    function testUpdateRouter() public {
        RegistryRouter newRouter = new RegistryRouter();

        vm.startPrank(admin);
        marketplace.updateRouter(address(newRouter));
        vm.stopPrank();

        assertEq(address(marketplace.router()), address(newRouter));
    }

    function testUpdateRouterZeroAddress() public {
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        vm.startPrank(admin);
        marketplace.updateRouter(address(0));
        vm.stopPrank();
    }

    function testUpdateRouterUnauthorized() public {
        RegistryRouter newRouter = new RegistryRouter();

        vm.expectRevert();
        vm.prank(unauthorized);
        marketplace.updateRouter(address(newRouter));
    }

    function testUpdateUSDC() public {
        MockUSDC newUsdc = new MockUSDC();

        vm.startPrank(admin);
        marketplace.updateUSDC(address(newUsdc));
        vm.stopPrank();

        assertEq(address(marketplace.usdc()), address(newUsdc));
    }

    function testUpdateUSDCZeroAddress() public {
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        vm.startPrank(admin);
        marketplace.updateUSDC(address(0));
        vm.stopPrank();
    }

    function testUpdateUSDCUnauthorized() public {
        MockUSDC newUsdc = new MockUSDC();

        vm.expectRevert();
        vm.prank(unauthorized);
        marketplace.updateUSDC(address(newUsdc));
    }

    function testUpdateRoboshareTokens() public {
        RoboshareTokens newRoboshareTokens = new RoboshareTokens();

        vm.startPrank(admin);
        marketplace.updateRoboshareTokens(address(newRoboshareTokens));
        vm.stopPrank();

        assertEq(address(marketplace.roboshareTokens()), address(newRoboshareTokens));
    }

    function testUpdateRoboshareTokensZeroAddress() public {
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        vm.startPrank(admin);
        marketplace.updateRoboshareTokens(address(0));
        vm.stopPrank();
    }

    function testUpdateRoboshareTokensUnauthorized() public {
        RoboshareTokens newRoboshareTokens = new RoboshareTokens();

        vm.expectRevert();
        vm.prank(unauthorized);
        marketplace.updateRoboshareTokens(address(newRoboshareTokens));
    }

    function testUpdateTreasury() public {
        Treasury newTreasury = new Treasury();

        vm.startPrank(admin);
        marketplace.updateTreasury(address(newTreasury));
        vm.stopPrank();

        assertEq(address(marketplace.treasury()), address(newTreasury));
    }

    function testUpdateTreasuryZeroAddress() public {
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        vm.startPrank(admin);
        marketplace.updateTreasury(address(0));
        vm.stopPrank();
    }

    function testUpdateTreasuryUnauthorized() public {
        Treasury newTreasury = new Treasury();

        vm.expectRevert();
        vm.prank(unauthorized);
        marketplace.updateTreasury(address(newTreasury));
    }

    // ExtendListing Tests

    function testExtendListingSuccess() public {
        // Setup: Create a listing
        _ensureState(SetupState.AssetWithListing);

        Marketplace.Listing memory listingBefore = marketplace.getListing(scenario.listingId);
        uint256 additionalDuration = EXTENSION_DURATION_DAYS * 1 days;

        vm.prank(partner1);
        marketplace.extendListing(scenario.listingId, additionalDuration);

        Marketplace.Listing memory listingAfter = marketplace.getListing(scenario.listingId);
        assertEq(listingAfter.expiresAt, listingBefore.expiresAt + additionalDuration);
        assertTrue(listingAfter.isActive);
    }

    function testExtendListingNonExistent() public {
        _ensureState(SetupState.ContractsDeployed);

        uint256 nonExistentListingId = INVALID_LISTING_ID;

        vm.expectRevert(Marketplace.ListingNotFound.selector);
        vm.prank(partner1);
        marketplace.extendListing(nonExistentListingId, EXTENSION_DURATION_DAYS * 1 days);
    }

    function testExtendListingUnauthorized() public {
        _ensureState(SetupState.AssetWithListing);

        vm.expectRevert(Marketplace.NotTokenOwner.selector);
        vm.prank(unauthorized);
        marketplace.extendListing(scenario.listingId, EXTENSION_DURATION_DAYS * 1 days);
    }

    function testExtendListingInactive() public {
        _ensureState(SetupState.AssetWithListing);

        // Cancel the listing first
        vm.prank(partner1);
        marketplace.cancelListing(scenario.listingId);

        vm.expectRevert(Marketplace.ListingNotActive.selector);
        vm.prank(partner1);
        marketplace.extendListing(scenario.listingId, EXTENSION_DURATION_DAYS * 1 days);
    }

    function testExtendListingZeroDuration() public {
        _ensureState(SetupState.AssetWithListing);

        vm.expectRevert(Marketplace.InvalidDuration.selector);
        vm.prank(partner1);
        marketplace.extendListing(scenario.listingId, 0);
    }
}
