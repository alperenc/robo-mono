// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { BaseTest } from "./BaseTest.t.sol";
import { PartnerManager } from "../contracts/PartnerManager.sol";

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

        // Check initial state (BaseTest authorizes partner1 and partner2)
        assertEq(partnerManager.getPartnerCount(), 2);
        assertTrue(partnerManager.isAuthorizedPartner(partner1));
        assertTrue(partnerManager.isAuthorizedPartner(partner2));
    }

    function testAuthorizePartner() public {
        uint256 futureTime = block.timestamp + 100;
        warpAndSaveTime(futureTime);

        vm.prank(partnerAdmin);
        vm.expectEmit(true, false, false, true);
        emit PartnerAuthorized(partner3, NEW_PARTNER_NAME);
        partnerManager.authorizePartner(partner3, NEW_PARTNER_NAME);

        assertTrue(partnerManager.isAuthorizedPartner(partner3));
        assertEq(partnerManager.getPartnerName(partner3), NEW_PARTNER_NAME);
        assertEq(partnerManager.getPartnerCount(), 3);
        assertEq(partnerManager.getPartnerRegistrationTime(partner3), futureTime);

        address[] memory partners = partnerManager.getAllPartners();
        assertEq(partners.length, 3);
    }

    function testRevokePartner() public {
        assertTrue(partnerManager.isAuthorizedPartner(partner1));
        assertEq(partnerManager.getPartnerCount(), 2);

        // Then revoke
        vm.prank(partnerAdmin);
        vm.expectEmit(true, false, false, false);
        emit PartnerRevoked(partner1);
        partnerManager.revokePartner(partner1);

        assertFalse(partnerManager.isAuthorizedPartner(partner1));
        assertEq(partnerManager.getPartnerName(partner1), "");
        assertEq(partnerManager.getPartnerRegistrationTime(partner1), 0);
        assertEq(partnerManager.getPartnerCount(), 1);

        address[] memory partners = partnerManager.getAllPartners();
        assertEq(partners.length, 1);
        assertEq(partners[0], partner2);
    }

    function testRevokePartnerFromMiddle() public {
        // Authorize a third partner to test revoking from the middle
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner3, NEW_PARTNER_NAME);
        assertEq(partnerManager.getPartnerCount(), 3);

        // Revoke middle partner (partner2)
        vm.prank(partnerAdmin);
        partnerManager.revokePartner(partner2);

        assertEq(partnerManager.getPartnerCount(), 2);
        assertFalse(partnerManager.isAuthorizedPartner(partner2));
        assertTrue(partnerManager.isAuthorizedPartner(partner1));
        assertTrue(partnerManager.isAuthorizedPartner(partner3));

        address[] memory partners = partnerManager.getAllPartners();
        assertEq(partners.length, 2);
        // Array should contain partner1 and partner3 (order may vary due to swap-and-pop)
        assertTrue(
            (partners[0] == partner1 && partners[1] == partner3) || (partners[0] == partner3 && partners[1] == partner1)
        );
    }

    function testUpdatePartnerName() public {
        string memory newName = "Tesla Inc.";

        vm.expectEmit(true, false, false, true);
        emit PartnerNameUpdated(partner1, newName);

        vm.prank(partnerAdmin);
        partnerManager.updatePartnerName(partner1, newName);

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

    function testAuthorizePartnerUnauthorized() public {
        vm.expectRevert();
        vm.prank(unauthorized);
        partnerManager.authorizePartner(partner3, NEW_PARTNER_NAME);
    }

    function testRevokePartnerUnauthorized() public {
        vm.expectRevert();
        vm.prank(unauthorized);
        partnerManager.revokePartner(partner1);
    }

    function testUpdatePartnerNameUnauthorized() public {
        vm.expectRevert();
        vm.prank(unauthorized);
        partnerManager.updatePartnerName(partner1, "New Name");
    }

    // Error Cases

    function testAuthorizePartnerZeroAddress() public {
        vm.expectRevert(PartnerManager.ZeroAddress.selector);
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(address(0), NEW_PARTNER_NAME);
    }

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

    function testRevokePartnerNotAuthorized() public {
        vm.expectRevert(PartnerManager.NotAuthorized.selector);
        vm.prank(partnerAdmin);
        partnerManager.revokePartner(partner3);
    }

    function testUpdatePartnerNameNotAuthorized() public {
        vm.expectRevert(PartnerManager.NotAuthorized.selector);
        vm.prank(partnerAdmin);
        partnerManager.updatePartnerName(partner3, "New Name");
    }

    function testUpdatePartnerNameEmptyName() public {
        vm.expectRevert(PartnerManager.EmptyName.selector);
        vm.prank(partnerAdmin);
        partnerManager.updatePartnerName(partner1, "");
    }

    // Role Management Tests

    function testRoleManagement() public {
        address newPartnerAdmin = makeAddr("newPartnerAdmin");

        // Admin can grant roles
        vm.startPrank(admin);
        partnerManager.grantRole(partnerManager.PARTNER_ADMIN_ROLE(), newPartnerAdmin);
        assertTrue(partnerManager.hasRole(partnerManager.PARTNER_ADMIN_ROLE(), newPartnerAdmin));
        vm.stopPrank();

        // New partner admin can authorize partners
        vm.startPrank(newPartnerAdmin);
        partnerManager.authorizePartner(partner3, NEW_PARTNER_NAME);
        assertTrue(partnerManager.isAuthorizedPartner(partner3));
        vm.stopPrank();

        // Admin can revoke roles
        vm.startPrank(admin);
        partnerManager.revokeRole(partnerManager.PARTNER_ADMIN_ROLE(), newPartnerAdmin);
        assertFalse(partnerManager.hasRole(partnerManager.PARTNER_ADMIN_ROLE(), newPartnerAdmin));
        vm.stopPrank();
    }

    // Fuzz Tests

    function testFuzzAuthorizePartner(address partner, string calldata name) public {
        vm.assume(partner != address(0));
        vm.assume(partner != partner1 && partner != partner2); // Avoid collision with existing partners
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

    // Integration Tests

    function testPartnerLifecycle() public {
        // partner1 is already authorized in setUp
        assertTrue(partnerManager.isAuthorizedPartner(partner1));
        uint256 originalTime = partnerManager.getPartnerRegistrationTime(partner1);

        // Update name
        vm.prank(partnerAdmin);
        partnerManager.updatePartnerName(partner1, "Tesla Inc.");

        assertEq(partnerManager.getPartnerName(partner1), "Tesla Inc.");
        assertEq(partnerManager.getPartnerRegistrationTime(partner1), originalTime);

        // Revoke
        vm.prank(partnerAdmin);
        partnerManager.revokePartner(partner1);

        assertFalse(partnerManager.isAuthorizedPartner(partner1));
        assertEq(partnerManager.getPartnerName(partner1), "");
        assertEq(partnerManager.getPartnerRegistrationTime(partner1), 0);
    }
}
