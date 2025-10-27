// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";

contract TreasuryUnitTest is BaseTest {
    function setUp() public {
        _ensureState(SetupState.ContractsDeployed);
    }

    // Initialization Tests

    function testInitialization() public view {
        // Check contract references
        assertEq(address(treasury.partnerManager()), address(partnerManager));
        assertEq(address(treasury.assetRegistry()), address(vehicleRegistry));
        assertEq(address(treasury.usdc()), address(usdc));

        // Check initial state
        assertEq(treasury.totalCollateralDeposited(), 0);

        // Check admin roles
        assertTrue(treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(treasury.hasRole(treasury.UPGRADER_ROLE(), admin));
        assertTrue(treasury.hasRole(treasury.TREASURER_ROLE(), admin));
    }

    function testInitializationWithZeroAddressesFails() public {
        Treasury newTreasury = new Treasury();

        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        newTreasury.initialize(
            address(0),
            address(partnerManager),
            address(vehicleRegistry),
            address(roboshareTokens),
            address(usdc),
            config.treasuryFeeRecipient
        );
    }

    // Collateral Calculation Tests

    function testGetCollateralRequirement() public view {
        uint256 requirement = treasury.getCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        (,,, uint256 expectedTotal) = calculateExpectedCollateral(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        assertEq(requirement, expectedTotal);
    }

    // Admin Functions Tests

    function testUpdatePartnerManager() public {
        PartnerManager newPartnerManager = new PartnerManager();

        vm.startPrank(admin);
        treasury.updatePartnerManager(address(newPartnerManager));
        vm.stopPrank();

        assertEq(address(treasury.partnerManager()), address(newPartnerManager));
    }

    function testUpdatePartnerManagerZeroAddressFails() public {
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        vm.startPrank(admin);
        treasury.updatePartnerManager(address(0));
        vm.stopPrank();
    }

    function testUpdatePartnerManagerUnauthorizedFails() public {
        PartnerManager newPartnerManager = new PartnerManager();

        vm.expectRevert();
        vm.prank(unauthorized);
        treasury.updatePartnerManager(address(newPartnerManager));
    }

    function testUpdateAssetRegistry() public {
        VehicleRegistry newRegistry = new VehicleRegistry();

        vm.startPrank(admin);
        treasury.updateAssetRegistry(address(newRegistry));
        vm.stopPrank();

        assertEq(address(treasury.assetRegistry()), address(newRegistry));
    }

    function testUpdateUSDC() public {
        ERC20Mock newUSDC = new ERC20Mock();

        vm.startPrank(admin);
        treasury.updateUSDC(address(newUSDC));
        vm.stopPrank();

        assertEq(address(treasury.usdc()), address(newUSDC));
    }

    function testSetRoboshareTokens() public {
        RoboshareTokens newRoboshareTokens = new RoboshareTokens();

        vm.startPrank(admin);
        treasury.setRoboshareTokens(address(newRoboshareTokens));
        vm.stopPrank();

        assertEq(address(treasury.roboshareTokens()), address(newRoboshareTokens));
    }

    function testSetRoboshareTokensUnauthorizedFails() public {
        RoboshareTokens newRoboshareTokens = new RoboshareTokens();

        vm.expectRevert();
        vm.prank(unauthorized);
        treasury.setRoboshareTokens(address(newRoboshareTokens));
    }

    function testSetRoboshareTokensZeroAddressFails() public {
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        vm.startPrank(admin);
        treasury.setRoboshareTokens(address(0));
        vm.stopPrank();
    }
}
