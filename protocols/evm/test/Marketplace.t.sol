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
        assertEq(address(marketplace.partnerManager()), address(partnerManager));
        assertEq(address(marketplace.router()), address(router));
        assertEq(address(marketplace.treasury()), address(treasury));
        assertEq(address(marketplace.usdcToken()), address(usdc));
        assertEq(marketplace.treasuryFeeRecipient(), config.treasuryFeeRecipient);

        // Check initial state
        assertEq(marketplace.getCurrentListingId(), 1);

        // Check roles
        assertTrue(marketplace.hasRole(marketplace.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(marketplace.hasRole(marketplace.UPGRADER_ROLE(), admin));
    }

    function testInitializationZeroAddresses() public {
        Marketplace newImpl = new Marketplace();

        vm.expectRevert(Marketplace__ZeroAddress.selector);
        new ERC1967Proxy(
            address(newImpl),
            abi.encodeWithSignature(
                "initialize(address,address,address,address,address,address,address)",
                address(0), // zero admin address
                address(roboshareTokens),
                address(partnerManager),
                address(router),
                address(treasury),
                address(usdc),
                config.treasuryFeeRecipient
            )
        );
    }

    // Admin Function Tests

    function testSetTreasuryFeeRecipient() public {
        address newTreasury = makeAddr("newTreasury");

        vm.prank(admin);
        marketplace.setTreasuryFeeRecipient(newTreasury);

        assertEq(marketplace.treasuryFeeRecipient(), newTreasury);
    }

    function testSetTreasuryFeeRecipientUnauthorized() public {
        address newTreasury = makeAddr("newTreasury");

        vm.expectRevert();
        vm.prank(unauthorized);
        marketplace.setTreasuryFeeRecipient(newTreasury);
    }

    function testSetTreasuryFeeRecipientZeroAddress() public {
        vm.expectRevert(Marketplace__ZeroAddress.selector);
        vm.prank(admin);
        marketplace.setTreasuryFeeRecipient(address(0));
    }
}
