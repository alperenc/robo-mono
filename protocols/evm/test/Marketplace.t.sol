// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { MockUSDC } from "../contracts/mocks/MockUSDC.sol";
import { RoboshareTokens } from "../contracts/RoboshareTokens.sol";
import { PartnerManager } from "../contracts/PartnerManager.sol";
import { RegistryRouter } from "../contracts/RegistryRouter.sol";
import { Treasury } from "../contracts/Treasury.sol";
import { Marketplace } from "../contracts/Marketplace.sol";

contract MarketplaceTest is BaseTest {
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

        // Verify role hashes
        assertEq(marketplace.UPGRADER_ROLE(), keccak256("UPGRADER_ROLE"), "Invalid UPGRADER_ROLE hash");
        assertEq(
            marketplace.AUTHORIZED_CONTRACT_ROLE(),
            keccak256("AUTHORIZED_CONTRACT_ROLE"),
            "Invalid AUTHORIZED_CONTRACT_ROLE hash"
        );
    }

    function testInitializationZeroAdmin() public {
        Marketplace newImpl = new Marketplace();
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address)",
                address(0),
                address(roboshareTokens),
                address(partnerManager),
                address(router),
                address(treasury),
                address(usdc)
            )
        );
    }

    function testInitializationZeroTokens() public {
        Marketplace newImpl = new Marketplace();
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address)",
                admin,
                address(0),
                address(partnerManager),
                address(router),
                address(treasury),
                address(usdc)
            )
        );
    }

    function testInitializationZeroPartnerManager() public {
        Marketplace newImpl = new Marketplace();
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address)",
                admin,
                address(roboshareTokens),
                address(0),
                address(router),
                address(treasury),
                address(usdc)
            )
        );
    }

    function testInitializationZeroRouter() public {
        Marketplace newImpl = new Marketplace();
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address)",
                admin,
                address(roboshareTokens),
                address(partnerManager),
                address(0),
                address(treasury),
                address(usdc)
            )
        );
    }

    function testInitializationZeroTreasury() public {
        Marketplace newImpl = new Marketplace();
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address)",
                admin,
                address(roboshareTokens),
                address(partnerManager),
                address(router),
                address(0),
                address(usdc)
            )
        );
    }

    function testInitializationZeroUSDC() public {
        Marketplace newImpl = new Marketplace();
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address)",
                admin,
                address(roboshareTokens),
                address(partnerManager),
                address(router),
                address(treasury),
                address(0)
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

    function testUpdatePartnerManagerUnauthorizedCaller() public {
        PartnerManager newPartnerManager = new PartnerManager();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, marketplace.DEFAULT_ADMIN_ROLE()
            )
        );
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

    function testUpdateRouterUnauthorizedCaller() public {
        RegistryRouter newRouter = new RegistryRouter();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, marketplace.DEFAULT_ADMIN_ROLE()
            )
        );
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

    function testUpdateUSDCUnauthorizedCaller() public {
        MockUSDC newUsdc = new MockUSDC();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, marketplace.DEFAULT_ADMIN_ROLE()
            )
        );
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

    function testUpdateRoboshareTokensUnauthorizedCaller() public {
        RoboshareTokens newRoboshareTokens = new RoboshareTokens();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, marketplace.DEFAULT_ADMIN_ROLE()
            )
        );
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

    function testUpdateTreasuryUnauthorizedCaller() public {
        Treasury newTreasury = new Treasury();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, marketplace.DEFAULT_ADMIN_ROLE()
            )
        );
        vm.prank(unauthorized);
        marketplace.updateTreasury(address(newTreasury));
    }
}
