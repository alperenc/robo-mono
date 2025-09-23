// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";

contract PartnerManagerTest is BaseTest {
    address public partnerAdmin = makeAddr("partnerAdmin");
    address public partner3 = makeAddr("partner3");

    bytes32 public constant PARTNER_ADMIN_ROLE = keccak256("PARTNER_ADMIN_ROLE");

    string constant NEW_PARTNER_NAME = "BMW Group";

    event PartnerAuthorized(address indexed partner, string name);
    event PartnerRevoked(address indexed partner);
    event PartnerNameUpdated(address indexed partner, string newName);

    function setUp() public {
        _ensureState(SetupState.ContractsDeployed);
        vm.startPrank(admin);
        partnerManager.grantRole(PARTNER_ADMIN_ROLE, partnerAdmin);
        vm.stopPrank();
    }

    function testInitialization() public view {
        // Check roles (from BaseTest setup)
        assertTrue(partnerManager.hasRole(partnerManager.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(partnerManager.hasRole(PARTNER_ADMIN_ROLE, admin));
        assertTrue(partnerManager.hasRole(keccak256("UPGRADER_ROLE"), admin));
        assertTrue(partnerManager.hasRole(PARTNER_ADMIN_ROLE, partnerAdmin));

        // Check initial state (BaseTest authorizes partner1 and partner2)
        assertEq(partnerManager.getPartnerCount(), 2);
        assertTrue(partnerManager.isAuthorizedPartner(partner1));
        assertTrue(partnerManager.isAuthorizedPartner(partner2));
    }

    function testAuthorizePartner() public {
        vm.expectEmit(true, true, false, true);
        emit PartnerAuthorized(partner3, NEW_PARTNER_NAME);

        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner3, NEW_PARTNER_NAME);

        assertTrue(partnerManager.isAuthorizedPartner(partner3));
        assertEq(partnerManager.getPartnerName(partner3), NEW_PARTNER_NAME);
        assertEq(partnerManager.getPartnerCount(), 3);
        assertGt(partnerManager.getPartnerRegistrationTime(partner3), 0);

        address[] memory partners = partnerManager.getAllPartners();
        assertEq(partners.length, 3);
    }

    function testRevokePartner() public {
        assertTrue(partnerManager.isAuthorizedPartner(partner1));
        assertEq(partnerManager.getPartnerCount(), 2);

        // Then revoke
        vm.expectEmit(true, true, false, true);
        emit PartnerRevoked(partner1);

        vm.prank(partnerAdmin);
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

        vm.expectEmit(true, true, false, true);
        emit PartnerNameUpdated(partner1, newName);

        vm.prank(partnerAdmin);
        partnerManager.updatePartnerName(partner1, newName);

        assertEq(partnerManager.getPartnerName(partner1), newName);
        assertTrue(partnerManager.isAuthorizedPartner(partner1));
    }

    function testGetPartnerInfo() public {
        (string memory name, uint256 registrationTime, bool isAuthorized) = partnerManager.getPartnerInfo(partner1);

        assertEq(name, PARTNER1_NAME);
        assertGt(registrationTime, 0);
        assertTrue(isAuthorized);
    }

    // Access Control Tests

    function testUnauthorizedAuthorizePartnerFails() public {
        vm.expectRevert();
        vm.prank(unauthorized);
        partnerManager.authorizePartner(partner3, NEW_PARTNER_NAME);
    }

    function testUnauthorizedRevokePartnerFails() public {
        vm.expectRevert();
        vm.prank(unauthorized);
        partnerManager.revokePartner(partner1);
    }

    function testUnauthorizedUpdatePartnerNameFails() public {
        vm.expectRevert();
        vm.prank(unauthorized);
        partnerManager.updatePartnerName(partner1, "New Name");
    }

    // Error Cases

    function testAuthorizeZeroAddressFails() public {
        vm.expectRevert(PartnerManager.PartnerManager__ZeroAddress.selector);
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(address(0), NEW_PARTNER_NAME);
    }

    function testAuthorizeEmptyNameFails() public {
        vm.expectRevert(PartnerManager.PartnerManager__EmptyName.selector);
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner3, "");
    }

    function testAuthorizeAlreadyAuthorizedFails() public {
        vm.expectRevert(PartnerManager.PartnerManager__AlreadyAuthorized.selector);
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);
    }

    function testRevokeNotAuthorizedFails() public {
        vm.expectRevert(PartnerManager.PartnerManager__NotAuthorized.selector);
        vm.prank(partnerAdmin);
        partnerManager.revokePartner(partner3);
    }

    function testUpdateNameNotAuthorizedFails() public {
        vm.expectRevert(PartnerManager.PartnerManager__NotAuthorized.selector);
        vm.prank(partnerAdmin);
        partnerManager.updatePartnerName(partner3, "New Name");
    }

    function testUpdateEmptyNameFails() public {
        vm.expectRevert(PartnerManager.PartnerManager__EmptyName.selector);
        vm.prank(partnerAdmin);
        partnerManager.updatePartnerName(partner1, "");
    }

    // Role Management Tests

    function testRoleManagement() public {
        address newPartnerAdmin = makeAddr("newPartnerAdmin");

        // Admin can grant roles
        vm.prank(admin);
        partnerManager.grantRole(PARTNER_ADMIN_ROLE, newPartnerAdmin);
        assertTrue(partnerManager.hasRole(PARTNER_ADMIN_ROLE, newPartnerAdmin));

        // New partner admin can authorize partners
        vm.prank(newPartnerAdmin);
        partnerManager.authorizePartner(partner3, NEW_PARTNER_NAME);
        assertTrue(partnerManager.isAuthorizedPartner(partner3));

        // Admin can revoke roles
        vm.prank(admin);
        partnerManager.revokeRole(PARTNER_ADMIN_ROLE, newPartnerAdmin);
        assertFalse(partnerManager.hasRole(PARTNER_ADMIN_ROLE, newPartnerAdmin));
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
            if(!partnerManager.isAuthorizedPartner(partner)){
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