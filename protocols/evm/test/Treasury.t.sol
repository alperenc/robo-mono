// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";

contract TreasuryTest is BaseTest {
    function setUp() public {
        _ensureState(SetupState.ContractsDeployed);
    }

    // Initialization Tests

    function testInitialization() public view {
        // Check contract references
        assertEq(address(treasury.partnerManager()), address(partnerManager));
        assertEq(address(treasury.assetRegistry()), address(assetRegistry));
        assertEq(address(treasury.usdc()), address(usdc));

        // Check initial state
        assertEq(treasury.totalCollateralDeposited(), 0);

        // Check admin roles
        assertTrue(treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(treasury.hasRole(treasury.UPGRADER_ROLE(), admin));
        assertTrue(treasury.hasRole(treasury.TREASURER_ROLE(), admin));
    }

    function testInitializationZeroAddresses() public {
        Treasury newTreasury = new Treasury();

        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        newTreasury.initialize(
            address(0),
            address(partnerManager),
            address(assetRegistry),
            address(roboshareTokens),
            address(usdc),
            config.treasuryFeeRecipient
        );
    }

    // Collateral Calculation Tests

    function testGetTotalCollateralRequirement() public view {
        uint256 requirement = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
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

    function testUpdatePartnerManagerZeroAddress() public {
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        vm.startPrank(admin);
        treasury.updatePartnerManager(address(0));
        vm.stopPrank();
    }

    function testUpdatePartnerManagerUnauthorized() public {
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

    function testUpdateAssetRegistryZeroAddress() public {
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        vm.startPrank(admin);
        treasury.updateAssetRegistry(address(0));
        vm.stopPrank();
    }

    function testUpdateAssetRegistryUnauthorized() public {
        VehicleRegistry newRegistry = new VehicleRegistry();

        vm.expectRevert();
        vm.prank(unauthorized);
        treasury.updateAssetRegistry(address(newRegistry));
    }

    function testUpdateUSDC() public {
        ERC20Mock newUSDC = new ERC20Mock();

        vm.startPrank(admin);
        treasury.updateUSDC(address(newUSDC));
        vm.stopPrank();

        assertEq(address(treasury.usdc()), address(newUSDC));
    }

    function testUpdateUSDCZeroAddress() public {
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        vm.startPrank(admin);
        treasury.updateUSDC(address(0));
        vm.stopPrank();
    }

    function testUpdateUSDCUnauthorized() public {
        ERC20Mock newUSDC = new ERC20Mock();

        vm.expectRevert();
        vm.prank(unauthorized);
        treasury.updateUSDC(address(newUSDC));
    }

    function testUpdateRoboshareTokens() public {
        RoboshareTokens newRoboshareTokens = new RoboshareTokens();

        vm.startPrank(admin);
        treasury.updateRoboshareTokens(address(newRoboshareTokens));
        vm.stopPrank();

        assertEq(address(treasury.roboshareTokens()), address(newRoboshareTokens));
    }

    function testUpdateRoboshareTokensZeroAddress() public {
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        vm.startPrank(admin);
        treasury.updateRoboshareTokens(address(0));
        vm.stopPrank();
    }

    function testUpdateRoboshareTokensUnauthorized() public {
        RoboshareTokens newRoboshareTokens = new RoboshareTokens();

        vm.expectRevert();
        vm.prank(unauthorized);
        treasury.updateRoboshareTokens(address(newRoboshareTokens));
    }

    function testUpdateTreasuryFeeRecipient() public {
        address newRecipient = makeAddr("treasuryFee");

        vm.startPrank(admin);
        treasury.updateTreasuryFeeRecipient(newRecipient);
        vm.stopPrank();
    }

    function testUpdateTreasuryFeeRecipientZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert(Treasury__ZeroAddressNotAllowed.selector);
        treasury.updateTreasuryFeeRecipient(address(0));
        vm.stopPrank();
    }

    function testUpdateTreasuryFeeRecipientUnauthorized() public {
        address newRecipient = makeAddr("treasuryFee");

        vm.startPrank(unauthorized);
        vm.expectRevert();
        treasury.updateTreasuryFeeRecipient(newRecipient);
        vm.stopPrank();
    }
}
