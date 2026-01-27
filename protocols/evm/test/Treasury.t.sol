// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { MockUSDC } from "../contracts/mocks/MockUSDC.sol";
import { RoboshareTokens } from "../contracts/RoboshareTokens.sol";
import { PartnerManager } from "../contracts/PartnerManager.sol";
import { RegistryRouter } from "../contracts/RegistryRouter.sol";
import { Treasury } from "../contracts/Treasury.sol";

contract TreasuryTest is BaseTest {
    function setUp() public {
        _ensureState(SetupState.ContractsDeployed);
    }

    // Initialization Tests

    function testInitialization() public view {
        // Check contract references
        assertEq(address(treasury.partnerManager()), address(partnerManager));
        assertEq(address(treasury.router()), address(router));
        assertEq(address(treasury.usdc()), address(usdc));

        // Check initial state
        assertEq(treasury.totalCollateralDeposited(), 0);

        // Check admin roles
        assertTrue(treasury.hasRole(treasury.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(treasury.hasRole(treasury.UPGRADER_ROLE(), admin));
        assertTrue(treasury.hasRole(treasury.TREASURER_ROLE(), admin));

        // Verify role hashes
        assertEq(treasury.UPGRADER_ROLE(), keccak256("UPGRADER_ROLE"), "Invalid UPGRADER_ROLE hash");
        assertEq(treasury.TREASURER_ROLE(), keccak256("TREASURER_ROLE"), "Invalid TREASURER_ROLE hash");
        assertEq(
            treasury.AUTHORIZED_CONTRACT_ROLE(),
            keccak256("AUTHORIZED_CONTRACT_ROLE"),
            "Invalid AUTHORIZED_CONTRACT_ROLE hash"
        );
        assertEq(
            treasury.AUTHORIZED_ROUTER_ROLE(),
            keccak256("AUTHORIZED_ROUTER_ROLE"),
            "Invalid AUTHORIZED_ROUTER_ROLE hash"
        );

        // Verify hierarchy (all managed by default admin)
        assertEq(treasury.getRoleAdmin(treasury.UPGRADER_ROLE()), treasury.DEFAULT_ADMIN_ROLE());
        assertEq(treasury.getRoleAdmin(treasury.TREASURER_ROLE()), treasury.DEFAULT_ADMIN_ROLE());
        assertEq(treasury.getRoleAdmin(treasury.AUTHORIZED_CONTRACT_ROLE()), treasury.DEFAULT_ADMIN_ROLE());
        assertEq(treasury.getRoleAdmin(treasury.AUTHORIZED_ROUTER_ROLE()), treasury.DEFAULT_ADMIN_ROLE());
    }

    function testInitializationZeroAdmin() public {
        Treasury newTreasury = new Treasury();
        vm.expectRevert(Treasury.ZeroAddress.selector);
        newTreasury.initialize(
            address(0),
            address(roboshareTokens),
            address(partnerManager),
            address(router),
            address(usdc),
            config.treasuryFeeRecipient
        );
    }

    function testInitializationZeroTokens() public {
        Treasury newTreasury = new Treasury();
        vm.expectRevert(Treasury.ZeroAddress.selector);
        newTreasury.initialize(
            admin, address(0), address(partnerManager), address(router), address(usdc), config.treasuryFeeRecipient
        );
    }

    function testInitializationZeroPartnerManager() public {
        Treasury newTreasury = new Treasury();
        vm.expectRevert(Treasury.ZeroAddress.selector);
        newTreasury.initialize(
            admin, address(roboshareTokens), address(0), address(router), address(usdc), config.treasuryFeeRecipient
        );
    }

    function testInitializationZeroRouter() public {
        Treasury newTreasury = new Treasury();
        vm.expectRevert(Treasury.ZeroAddress.selector);
        newTreasury.initialize(
            admin,
            address(roboshareTokens),
            address(partnerManager),
            address(0),
            address(usdc),
            config.treasuryFeeRecipient
        );
    }

    function testInitializationZeroUSDC() public {
        Treasury newTreasury = new Treasury();
        vm.expectRevert(Treasury.ZeroAddress.selector);
        newTreasury.initialize(
            admin,
            address(roboshareTokens),
            address(partnerManager),
            address(router),
            address(0),
            config.treasuryFeeRecipient
        );
    }

    function testInitializationZeroFeeRecipient() public {
        Treasury newTreasury = new Treasury();
        vm.expectRevert(Treasury.ZeroAddress.selector);
        newTreasury.initialize(
            admin, address(roboshareTokens), address(partnerManager), address(router), address(usdc), address(0)
        );
    }

    // Collateral Calculation Tests

    function testGetTotalCollateralRequirement() public view {
        uint256 requirement = treasury.getTotalCollateralRequirement(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
        (,,, uint256 expectedTotal) = _calculateExpectedCollateral(REVENUE_TOKEN_PRICE, REVENUE_TOKEN_SUPPLY);
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
        vm.expectRevert(Treasury.ZeroAddress.selector);
        vm.startPrank(admin);
        treasury.updatePartnerManager(address(0));
        vm.stopPrank();
    }

    function testUpdatePartnerManagerUnauthorizedCaller() public {
        PartnerManager newPartnerManager = new PartnerManager();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, treasury.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(unauthorized);
        treasury.updatePartnerManager(address(newPartnerManager));
    }

    function testUpdateRouter() public {
        RegistryRouter newRouter = new RegistryRouter();

        vm.startPrank(admin);
        treasury.updateRouter(address(newRouter));
        vm.stopPrank();

        assertEq(address(treasury.router()), address(newRouter));
    }

    function testUpdateRouterZeroAddress() public {
        vm.expectRevert(Treasury.ZeroAddress.selector);
        vm.startPrank(admin);
        treasury.updateRouter(address(0));
        vm.stopPrank();
    }

    function testUpdateRouterUnauthorizedCaller() public {
        RegistryRouter newRouter = new RegistryRouter();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, treasury.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(unauthorized);
        treasury.updateRouter(address(newRouter));
    }

    function testUpdateUSDC() public {
        MockUSDC newUsdc = new MockUSDC();

        vm.startPrank(admin);
        treasury.updateUSDC(address(newUsdc));
        vm.stopPrank();

        assertEq(address(treasury.usdc()), address(newUsdc));
    }

    function testUpdateUSDCZeroAddress() public {
        vm.expectRevert(Treasury.ZeroAddress.selector);
        vm.startPrank(admin);
        treasury.updateUSDC(address(0));
        vm.stopPrank();
    }

    function testUpdateUSDCUnauthorizedCaller() public {
        MockUSDC newUsdc = new MockUSDC();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, treasury.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(unauthorized);
        treasury.updateUSDC(address(newUsdc));
    }

    function testUpdateRoboshareTokens() public {
        RoboshareTokens newRoboshareTokens = new RoboshareTokens();

        vm.startPrank(admin);
        treasury.updateRoboshareTokens(address(newRoboshareTokens));
        vm.stopPrank();

        assertEq(address(treasury.roboshareTokens()), address(newRoboshareTokens));
    }

    function testUpdateRoboshareTokensZeroAddress() public {
        vm.expectRevert(Treasury.ZeroAddress.selector);
        vm.startPrank(admin);
        treasury.updateRoboshareTokens(address(0));
        vm.stopPrank();
    }

    function testUpdateRoboshareTokensUnauthorizedCaller() public {
        RoboshareTokens newRoboshareTokens = new RoboshareTokens();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, treasury.DEFAULT_ADMIN_ROLE()
            )
        );
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
        vm.expectRevert(Treasury.ZeroAddress.selector);
        treasury.updateTreasuryFeeRecipient(address(0));
        vm.stopPrank();
    }

    function testUpdateTreasuryFeeRecipientUnauthorizedCaller() public {
        address newRecipient = makeAddr("treasuryFee");

        vm.startPrank(unauthorized);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, treasury.DEFAULT_ADMIN_ROLE()
            )
        );
        treasury.updateTreasuryFeeRecipient(newRecipient);
        vm.stopPrank();
    }
}
