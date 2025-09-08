// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/PartnerManager.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract PartnerManagerTest is Test {
    PartnerManager public partnerManager;
    PartnerManager public partnerImplementation;

    address public admin = makeAddr("admin");
    address public partnerAdmin = makeAddr("partnerAdmin");
    address public partner1 = makeAddr("partner1");
    address public partner2 = makeAddr("partner2");
    address public partner3 = makeAddr("partner3");
    address public unauthorized = makeAddr("unauthorized");

    bytes32 public constant PARTNER_ADMIN_ROLE = keccak256("PARTNER_ADMIN_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    string constant PARTNER1_NAME = "Tesla Motors";
    string constant PARTNER2_NAME = "Ford Motors";
    string constant PARTNER3_NAME = "BMW Group";

    event PartnerAuthorized(address indexed partner, string name);
    event PartnerRevoked(address indexed partner);
    event PartnerNameUpdated(address indexed partner, string newName);

    function setUp() public {
        // Deploy implementation
        partnerImplementation = new PartnerManager();

        // Deploy proxy
        bytes memory initData = abi.encodeWithSignature("initialize(address)", admin);
        ERC1967Proxy proxy = new ERC1967Proxy(address(partnerImplementation), initData);
        partnerManager = PartnerManager(address(proxy));

        // Grant roles
        vm.startPrank(admin);
        partnerManager.grantRole(PARTNER_ADMIN_ROLE, partnerAdmin);
        vm.stopPrank();
    }

    function testInitialization() public {
        // Check roles
        assertTrue(partnerManager.hasRole(partnerManager.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(partnerManager.hasRole(PARTNER_ADMIN_ROLE, admin));
        assertTrue(partnerManager.hasRole(UPGRADER_ROLE, admin));
        assertTrue(partnerManager.hasRole(PARTNER_ADMIN_ROLE, partnerAdmin));

        // Check initial state
        assertEq(partnerManager.getPartnerCount(), 0);
        assertFalse(partnerManager.isAuthorizedPartner(partner1));
    }

    function testAuthorizePartner() public {
        vm.expectEmit(true, true, false, true);
        emit PartnerAuthorized(partner1, PARTNER1_NAME);

        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);

        assertTrue(partnerManager.isAuthorizedPartner(partner1));
        assertEq(partnerManager.getPartnerName(partner1), PARTNER1_NAME);
        assertEq(partnerManager.getPartnerCount(), 1);
        assertGt(partnerManager.getPartnerRegistrationTime(partner1), 0);

        address[] memory partners = partnerManager.getAllPartners();
        assertEq(partners.length, 1);
        assertEq(partners[0], partner1);
    }

    function testAuthorizeMultiplePartners() public {
        vm.startPrank(partnerAdmin);

        partnerManager.authorizePartner(partner1, PARTNER1_NAME);
        partnerManager.authorizePartner(partner2, PARTNER2_NAME);
        partnerManager.authorizePartner(partner3, PARTNER3_NAME);

        vm.stopPrank();

        assertTrue(partnerManager.isAuthorizedPartner(partner1));
        assertTrue(partnerManager.isAuthorizedPartner(partner2));
        assertTrue(partnerManager.isAuthorizedPartner(partner3));

        assertEq(partnerManager.getPartnerCount(), 3);

        address[] memory partners = partnerManager.getAllPartners();
        assertEq(partners.length, 3);
    }

    function testRevokePartner() public {
        // First authorize
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);

        assertTrue(partnerManager.isAuthorizedPartner(partner1));
        assertEq(partnerManager.getPartnerCount(), 1);

        // Then revoke
        vm.expectEmit(true, true, false, true);
        emit PartnerRevoked(partner1);

        vm.prank(partnerAdmin);
        partnerManager.revokePartner(partner1);

        assertFalse(partnerManager.isAuthorizedPartner(partner1));
        assertEq(partnerManager.getPartnerName(partner1), "");
        assertEq(partnerManager.getPartnerRegistrationTime(partner1), 0);
        assertEq(partnerManager.getPartnerCount(), 0);

        address[] memory partners = partnerManager.getAllPartners();
        assertEq(partners.length, 0);
    }

    function testRevokePartnerFromMiddle() public {
        // Authorize three partners
        vm.startPrank(partnerAdmin);
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);
        partnerManager.authorizePartner(partner2, PARTNER2_NAME);
        partnerManager.authorizePartner(partner3, PARTNER3_NAME);
        vm.stopPrank();

        assertEq(partnerManager.getPartnerCount(), 3);

        // Revoke middle partner
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
        // First authorize
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);

        string memory newName = "Tesla Inc.";

        vm.expectEmit(true, true, false, true);
        emit PartnerNameUpdated(partner1, newName);

        vm.prank(partnerAdmin);
        partnerManager.updatePartnerName(partner1, newName);

        assertEq(partnerManager.getPartnerName(partner1), newName);
        assertTrue(partnerManager.isAuthorizedPartner(partner1));
    }

    function testGetPartnerInfo() public {
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);

        (string memory name, uint256 registrationTime, bool isAuthorized) = partnerManager.getPartnerInfo(partner1);

        assertEq(name, PARTNER1_NAME);
        assertGt(registrationTime, 0);
        assertTrue(isAuthorized);
    }

    // Access Control Tests

    function testUnauthorizedAuthorizePartnerFails() public {
        vm.expectRevert();
        vm.prank(unauthorized);
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);
    }

    function testUnauthorizedRevokePartnerFails() public {
        // First authorize
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);

        vm.expectRevert();
        vm.prank(unauthorized);
        partnerManager.revokePartner(partner1);
    }

    function testUnauthorizedUpdatePartnerNameFails() public {
        // First authorize
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);

        vm.expectRevert();
        vm.prank(unauthorized);
        partnerManager.updatePartnerName(partner1, "New Name");
    }

    // Error Cases

    function testAuthorizeZeroAddressFails() public {
        vm.expectRevert(PartnerManager.PartnerManager__ZeroAddress.selector);
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(address(0), PARTNER1_NAME);
    }

    function testAuthorizeEmptyNameFails() public {
        vm.expectRevert(PartnerManager.PartnerManager__EmptyName.selector);
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner1, "");
    }

    function testAuthorizeAlreadyAuthorizedFails() public {
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);

        vm.expectRevert(PartnerManager.PartnerManager__AlreadyAuthorized.selector);
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);
    }

    function testRevokeNotAuthorizedFails() public {
        vm.expectRevert(PartnerManager.PartnerManager__NotAuthorized.selector);
        vm.prank(partnerAdmin);
        partnerManager.revokePartner(partner1);
    }

    function testUpdateNameNotAuthorizedFails() public {
        vm.expectRevert(PartnerManager.PartnerManager__NotAuthorized.selector);
        vm.prank(partnerAdmin);
        partnerManager.updatePartnerName(partner1, "New Name");
    }

    function testUpdateEmptyNameFails() public {
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);

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
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);
        assertTrue(partnerManager.isAuthorizedPartner(partner1));

        // Admin can revoke roles
        vm.prank(admin);
        partnerManager.revokeRole(PARTNER_ADMIN_ROLE, newPartnerAdmin);
        assertFalse(partnerManager.hasRole(PARTNER_ADMIN_ROLE, newPartnerAdmin));
    }

    // Fuzz Tests

    function testFuzzAuthorizePartner(address partner, string calldata name) public {
        vm.assume(partner != address(0));
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
            address partner = makeAddr(string(abi.encodePacked("partner", i)));
            string memory name = string(abi.encodePacked("Partner ", vm.toString(i)));
            partnerManager.authorizePartner(partner, name);
        }

        vm.stopPrank();

        assertEq(partnerManager.getPartnerCount(), numPartners);
    }

    // Integration Tests

    function testPartnerLifecycle() public {
        // Authorize
        vm.prank(partnerAdmin);
        partnerManager.authorizePartner(partner1, PARTNER1_NAME);

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
