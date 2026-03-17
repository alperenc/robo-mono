// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { PartnerManager } from "../../contracts/PartnerManager.sol";
import { BaseTest } from "../base/BaseTest.t.sol";

contract PartnerManagerTest is BaseTest {
    address public partnerAdmin = makeAddr("partnerAdmin");
    address public partner3 = makeAddr("partner3");

    string constant NEW_PARTNER_NAME = "BMW Group";

    event PartnerAuthorized(address indexed partner, string name);
    event PartnerRevoked(address indexed partner);
    event PartnerNameUpdated(address indexed partner, string newName);

    function setUp() public {
        _ensureState(SetupState.InitialAccountsSetup);
        vm.startPrank(admin);
        partnerManager.grantRole(partnerManager.PARTNER_ADMIN_ROLE(), partnerAdmin);
        vm.stopPrank();
    }

    function testInitialization() public view {
        // Check roles (from BaseTest setup)
        assertTrue(partnerManager.hasRole(partnerManager.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(partnerManager.hasRole(partnerManager.PARTNER_ADMIN_ROLE(), admin));
        assertTrue(partnerManager.hasRole(partnerManager.UPGRADER_ROLE(), admin));
        assertTrue(partnerManager.hasRole(partnerManager.PARTNER_ADMIN_ROLE(), partnerAdmin));

        // Verify role hashes
        assertEq(
            partnerManager.PARTNER_ADMIN_ROLE(), keccak256("PARTNER_ADMIN_ROLE"), "Invalid PARTNER_ADMIN_ROLE hash"
        );
        assertEq(partnerManager.UPGRADER_ROLE(), keccak256("UPGRADER_ROLE"), "Invalid UPGRADER_ROLE hash");

        // Check initial state (BaseTest authorizes partner1/partner2 + admin)
        assertEq(partnerManager.getPartnerCount(), 3);
        assertTrue(partnerManager.isAuthorizedPartner(partner1));
        assertTrue(partnerManager.isAuthorizedPartner(partner2));
        assertFalse(partnerManager.isAuthorizedPartner(partnerAdmin));
        assertTrue(partnerManager.isAuthorizedPartner(admin));
    }

    function testInitializationZeroAdmin() public {
        PartnerManager newImpl = new PartnerManager();
        vm.expectRevert(PartnerManager.ZeroAddress.selector);
        new ERC1967Proxy(address(newImpl), abi.encodeWithSignature("initialize(address)", address(0)));
    }

    function testGrantPartnerAdminDoesNotAuthorizePartner() public {
        address newAdmin = makeAddr("partnerAdmin2");

        vm.startPrank(admin);
        partnerManager.grantRole(partnerManager.PARTNER_ADMIN_ROLE(), newAdmin);
        vm.stopPrank();

        assertFalse(partnerManager.isAuthorizedPartner(newAdmin));
    }

    function testAuthorizePartnerZeroAddress() public {
        vm.expectRevert(PartnerManager.ZeroAddress.selector);
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(address(0), NEW_PARTNER_NAME);
    }

    function testAuthorizePartner() public {
        uint256 futureTime = block.timestamp + 100;
        vm.warp(futureTime);

        vm.prank(partnerAdmin);
        vm.expectEmit(true, false, false, true);
        emit PartnerAuthorized(partner3, NEW_PARTNER_NAME);
        partnerManager.authorizePartner(partner3, NEW_PARTNER_NAME);

        assertTrue(partnerManager.isAuthorizedPartner(partner3));
        assertEq(partnerManager.getPartnerName(partner3), NEW_PARTNER_NAME);
        assertEq(partnerManager.getPartnerCount(), 4);
        assertEq(partnerManager.getPartnerRegistrationTime(partner3), futureTime);

        address[] memory partners = partnerManager.getAllPartners();
        assertEq(partners.length, 4);
    }

    function testRevokePartner() public {
        assertTrue(partnerManager.isAuthorizedPartner(partner1));
        assertEq(partnerManager.getPartnerCount(), 3);

        // Then revoke
        vm.prank(partnerAdmin);
        vm.expectEmit(true, false, false, false);
        emit PartnerRevoked(partner1);
        partnerManager.revokePartner(partner1);

        assertFalse(partnerManager.isAuthorizedPartner(partner1));
        assertEq(partnerManager.getPartnerName(partner1), "");
        assertEq(partnerManager.getPartnerRegistrationTime(partner1), 0);
        assertEq(partnerManager.getPartnerCount(), 2);

        address[] memory partners = partnerManager.getAllPartners();
        assertEq(partners.length, 2);
    }

    function testRevokePartnerFromMiddle() public {
        // Authorize a third partner to test revoking from the middle
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner3, NEW_PARTNER_NAME);
        assertEq(partnerManager.getPartnerCount(), 4);

        // Revoke middle partner (partner2)
        vm.prank(partnerAdmin);
        partnerManager.revokePartner(partner2);

        assertEq(partnerManager.getPartnerCount(), 3);
        assertFalse(partnerManager.isAuthorizedPartner(partner2));
        assertTrue(partnerManager.isAuthorizedPartner(partner1));
        assertTrue(partnerManager.isAuthorizedPartner(partner3));

        address[] memory partners = partnerManager.getAllPartners();
        assertEq(partners.length, 3);
        bool hasPartner1 = false;
        bool hasPartner3 = false;
        for (uint256 i = 0; i < partners.length; i++) {
            if (partners[i] == partner1) hasPartner1 = true;
            if (partners[i] == partner3) hasPartner3 = true;
        }
        assertTrue(hasPartner1);
        assertTrue(hasPartner3);
    }

    function testUpdateName() public {
        string memory newName = "Tesla Inc.";

        vm.expectEmit(true, false, false, true);
        emit PartnerNameUpdated(partner1, newName);

        vm.prank(partner1);
        partnerManager.updateName(newName);

        assertEq(partnerManager.getPartnerName(partner1), newName);
        assertTrue(partnerManager.isAuthorizedPartner(partner1));
    }

    function testGetPartnerInfo() public view {
        (string memory name, uint256 registrationTime, bool isAuthorized) = partnerManager.getPartnerInfo(partner1);

        assertEq(name, "Partner 1");
        assertGt(registrationTime, 0);
        assertTrue(isAuthorized);
    }

    // Access Control Tests

    function testAuthorizePartnerUnauthorizedCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                partnerManager.PARTNER_ADMIN_ROLE()
            )
        );
        vm.prank(unauthorized);
        partnerManager.authorizePartner(partner3, NEW_PARTNER_NAME);
    }

    function testRevokePartnerUnauthorizedCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                partnerManager.PARTNER_ADMIN_ROLE()
            )
        );
        vm.prank(unauthorized);
        partnerManager.revokePartner(partner1);
    }

    function testUpdateNameUnauthorizedPartner() public {
        vm.expectRevert(PartnerManager.UnauthorizedPartner.selector);
        vm.prank(partner3);
        partnerManager.updateName("New Name");
    }

    function testUpdateNameEmptyName() public {
        vm.expectRevert(PartnerManager.EmptyName.selector);
        vm.prank(partner1);
        partnerManager.updateName("");
    }

    function testChangeNameForUnauthorizedCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                partnerManager.PARTNER_ADMIN_ROLE()
            )
        );
        vm.prank(unauthorized);
        partnerManager.changeNameFor(partner1, "New Name");
    }

    // Error Cases

    function testAuthorizePartnerEmptyName() public {
        vm.expectRevert(PartnerManager.EmptyName.selector);
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner3, "");
    }

    function testAuthorizePartnerAlreadyAuthorized() public {
        vm.expectRevert(PartnerManager.AlreadyAuthorized.selector);
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);
    }

    function testRevokePartnerUnauthorizedPartner() public {
        vm.expectRevert(PartnerManager.UnauthorizedPartner.selector);
        vm.prank(partnerAdmin);
        partnerManager.revokePartner(partner3);
    }

    function testChangeNameForUnauthorizedPartner() public {
        vm.expectRevert(PartnerManager.UnauthorizedPartner.selector);
        vm.prank(partnerAdmin);
        partnerManager.changeNameFor(partner3, "New Name");
    }

    function testChangeNameForEmptyName() public {
        vm.expectRevert(PartnerManager.EmptyName.selector);
        vm.prank(partnerAdmin);
        partnerManager.changeNameFor(partner1, "");
    }

    // Fuzz Tests

    function testFuzzAuthorizePartner(address partner, string calldata name) public {
        vm.assume(partner != address(0));
        vm.assume(!partnerManager.isAuthorizedPartner(partner));
        vm.assume(bytes(name).length > 0 && bytes(name).length < 100);

        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner, name);

        assertTrue(partnerManager.isAuthorizedPartner(partner));
        assertEq(partnerManager.getPartnerName(partner), name);
    }

    function testFuzzMultiplePartners(uint8 numPartners) public {
        vm.assume(numPartners > 0 && numPartners <= 50);

        vm.startPrank(partnerAdmin);

        for (uint8 i = 0; i < numPartners; i++) {
            address partner = address(uint160(uint256(keccak256(abi.encodePacked("fuzzPartner", i)))));
            vm.assume(partner != address(0) && partner != partner1 && partner != partner2);
            string memory name = string(abi.encodePacked("Partner ", vm.toString(i)));
            if (!partnerManager.isAuthorizedPartner(partner)) {
                partnerManager.authorizePartner(partner, name);
            }
        }

        vm.stopPrank();

        assertGe(partnerManager.getPartnerCount(), numPartners);
    }

    function testUpgradeUnauthorizedCaller() public {
        PartnerManager newImpl = new PartnerManager();
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, partnerManager.UPGRADER_ROLE()
            )
        );
        vm.prank(unauthorized);
        partnerManager.upgradeToAndCall(address(newImpl), "");
    }
}
