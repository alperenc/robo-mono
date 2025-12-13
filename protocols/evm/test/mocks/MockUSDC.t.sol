// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";
import { MockUSDC } from "../../contracts/mocks/MockUSDC.sol";

contract MockUSDCTest is Test {
    MockUSDC usdc;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        usdc = new MockUSDC();
    }

    function testMetadata() public view {
        assertEq(usdc.name(), "USD Coin");
        assertEq(usdc.symbol(), "USDC");
        assertEq(usdc.decimals(), 6);
    }

    function testMint() public {
        usdc.mint(alice, 1000e6);
        assertEq(usdc.balanceOf(alice), 1000e6);
        assertEq(usdc.totalSupply(), 1000e6);
    }

    function testBurn() public {
        usdc.mint(alice, 1000e6);
        usdc.burn(alice, 500e6);
        assertEq(usdc.balanceOf(alice), 500e6);
        assertEq(usdc.totalSupply(), 500e6);
    }

    function testBurnArbitrary() public {
        // Testing the specific property that anyone can burn for testing convenience
        usdc.mint(alice, 1000e6);
        vm.prank(bob);
        usdc.burn(alice, 1000e6);
        assertEq(usdc.balanceOf(alice), 0);
    }
}
