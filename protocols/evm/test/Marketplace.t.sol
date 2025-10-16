// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";

contract MarketplaceTest is BaseTest {
    function setUp() public {
        _ensureState(SetupState.ContractsDeployed);
    }

    // Initialization Tests

    function testInitialization() public view {
        // Check contract references
        assertEq(address(marketplace.roboshareTokens()), address(roboshareTokens));
        assertEq(address(marketplace.vehicleRegistry()), address(vehicleRegistry));
        assertEq(address(marketplace.partnerManager()), address(partnerManager));
        assertEq(address(marketplace.treasury()), address(treasury));
        assertEq(address(marketplace.usdcToken()), address(usdc));
        assertEq(marketplace.treasuryAddress(), config.treasuryFeeRecipient);

        // Check initial state
        assertEq(marketplace.getCurrentListingId(), 1);

        // Check roles
        assertTrue(marketplace.hasRole(marketplace.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(marketplace.hasRole(marketplace.UPGRADER_ROLE(), admin));
    }

    function testInitializationWithZeroAddresses() public {
        Marketplace newImpl = new Marketplace();

        vm.expectRevert(Marketplace__ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address,address)",
                address(0), // zero admin address
                address(roboshareTokens),
                address(vehicleRegistry),
                address(partnerManager),
                address(treasury),
                address(usdc),
                config.treasuryFeeRecipient
            )
        );
    }

    // Admin Function Tests

    function testSetTreasuryAddress() public {
        address newTreasury = makeAddr("newTreasury");

        vm.prank(admin);
        marketplace.setTreasuryAddress(newTreasury);

        assertEq(marketplace.treasuryAddress(), newTreasury);
    }

    function testSetTreasuryAddressUnauthorized() public {
        address newTreasury = makeAddr("newTreasury");

        vm.expectRevert();
        vm.prank(unauthorized);
        marketplace.setTreasuryAddress(newTreasury);
    }

    function testSetTreasuryAddressZeroAddress() public {
        vm.expectRevert(Marketplace__ZeroAddress.selector);
        vm.prank(admin);
        marketplace.setTreasuryAddress(address(0));
    }
}
