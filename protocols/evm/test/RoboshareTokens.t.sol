// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BaseTest } from "./BaseTest.t.sol";
import { TokenLib } from "../contracts/Libraries.sol";
import { RoboshareTokens } from "../contracts/RoboshareTokens.sol";

contract RoboshareTokensTest is BaseTest {
    address public minter;
    address public burner;
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    function setUp() public {
        _ensureState(SetupState.ContractsDeployed);
        minter = admin; // Admin has minter role by default
        burner = admin; // Admin has burner role by default
    }

    function testInitialization() public view {
        assertTrue(roboshareTokens.hasRole(roboshareTokens.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(roboshareTokens.hasRole(roboshareTokens.UPGRADER_ROLE(), admin));
        assertTrue(roboshareTokens.hasRole(roboshareTokens.MINTER_ROLE(), admin));
        assertTrue(roboshareTokens.hasRole(roboshareTokens.MINTER_ROLE(), minter));

        // Verify role hashes
        assertEq(roboshareTokens.MINTER_ROLE(), keccak256("MINTER_ROLE"), "Invalid MINTER_ROLE hash");
        assertEq(roboshareTokens.BURNER_ROLE(), keccak256("BURNER_ROLE"), "Invalid BURNER_ROLE hash");
        assertEq(roboshareTokens.URI_SETTER_ROLE(), keccak256("URI_SETTER_ROLE"), "Invalid URI_SETTER_ROLE hash");
        assertEq(roboshareTokens.UPGRADER_ROLE(), keccak256("UPGRADER_ROLE"), "Invalid UPGRADER_ROLE hash");
    }

    function testInitializationZeroAdmin() public {
        RoboshareTokens newImpl = new RoboshareTokens();
        vm.expectRevert(RoboshareTokens.ZeroAddress.selector);
        new ERC1967Proxy(address(newImpl), abi.encodeWithSignature("initialize(address)", address(0)));
    }

    function testMintSingleToken() public {
        uint256 tokenId = 101; // Use a high number to avoid collision
        uint256 amount = 100;
        bytes memory data = "";

        vm.prank(minter);
        roboshareTokens.mint(user1, tokenId, amount, data);

        assertEq(roboshareTokens.balanceOf(user1, tokenId), amount);
    }

    function testMintBatchTokens() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 101; // Asset token
        ids[1] = 102; // Revenue token
        amounts[0] = 1;
        amounts[1] = 200;
        bytes memory data = "";

        vm.expectEmit(true, true, true, false);
        emit RoboshareTokens.RevenueTokenPositionsUpdated(ids[1], address(0), user1, amounts[1]);

        vm.prank(minter);
        roboshareTokens.mintBatch(user1, ids, amounts, data);

        assertEq(roboshareTokens.balanceOf(user1, 101), 1);
        assertEq(roboshareTokens.balanceOf(user1, 102), 200);
    }

    function testBurnSingleToken() public {
        // Setup: mint tokens first
        uint256 tokenId = 101;
        uint256 amount = 100;

        vm.prank(minter);
        roboshareTokens.mint(user1, tokenId, amount, "");

        // Test burn
        vm.prank(burner);
        roboshareTokens.burn(user1, tokenId, 50);

        assertEq(roboshareTokens.balanceOf(user1, tokenId), 50);
    }

    function testBurnBatchTokens() public {
        // Setup: mint tokens first
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 101;
        ids[1] = 102;
        amounts[0] = 100;
        amounts[1] = 200;

        vm.prank(minter);
        roboshareTokens.mintBatch(user1, ids, amounts, "");

        // Test burn batch
        uint256[] memory burnAmounts = new uint256[](2);
        burnAmounts[0] = 30;
        burnAmounts[1] = 50;

        vm.prank(burner);
        roboshareTokens.burnBatch(user1, ids, burnAmounts);

        assertEq(roboshareTokens.balanceOf(user1, 101), 70);
        assertEq(roboshareTokens.balanceOf(user1, 102), 150);
    }

    function testSetURI() public {
        string memory newURI = "https://api.roboshare.com/tokens/{id}.json";

        vm.prank(admin);
        roboshareTokens.setURI(newURI);

        assertEq(roboshareTokens.uri(1), newURI);
    }

    function testTransfers() public {
        // Setup: mint tokens to user1
        uint256 tokenId = 101;
        uint256 amount = 100;

        vm.prank(minter);
        roboshareTokens.mint(user1, tokenId, amount, "");

        // Transfer from user1 to user2
        vm.prank(user1);
        roboshareTokens.safeTransferFrom(user1, user2, tokenId, 30, "");

        assertEq(roboshareTokens.balanceOf(user1, tokenId), 70);
        assertEq(roboshareTokens.balanceOf(user2, tokenId), 30);
    }

    function testBatchTransfers() public {
        // Setup: mint multiple tokens to user1
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 101;
        ids[1] = 102;
        amounts[0] = 100;
        amounts[1] = 200;

        vm.prank(minter);
        roboshareTokens.mintBatch(user1, ids, amounts, "");

        // Batch transfer
        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 30;
        transferAmounts[1] = 50;

        vm.prank(user1);
        roboshareTokens.safeBatchTransferFrom(user1, user2, ids, transferAmounts, "");

        assertEq(roboshareTokens.balanceOf(user1, 101), 70);
        assertEq(roboshareTokens.balanceOf(user1, 102), 150);
        assertEq(roboshareTokens.balanceOf(user2, 101), 30);
        assertEq(roboshareTokens.balanceOf(user2, 102), 50);
    }

    // Access Control Tests

    function testMintUnauthorizedCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, roboshareTokens.MINTER_ROLE()
            )
        );
        vm.prank(unauthorized);
        roboshareTokens.mint(user1, 1, 100, "");
    }

    function testBurnUnauthorizedCaller() public {
        // Setup: mint token first
        vm.prank(minter);
        roboshareTokens.mint(user1, 1, 100, "");

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, roboshareTokens.BURNER_ROLE()
            )
        );
        vm.prank(unauthorized);
        roboshareTokens.burn(user1, 1, 50);
    }

    function testSetURIUnauthorizedCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                roboshareTokens.URI_SETTER_ROLE()
            )
        );
        vm.prank(unauthorized);
        roboshareTokens.setURI("ipfs://new-uri");
    }

    function testGetUserPositionsAndBalance() public {
        _ensureState(SetupState.RevenueTokensMinted);
        TokenLib.TokenPosition[] memory positions = roboshareTokens.getUserPositions(scenario.revenueTokenId, partner1);
        assertGt(positions.length, 0);
        assertEq(roboshareTokens.balanceOf(partner1, scenario.revenueTokenId), scenario.revenueTokenSupply);
    }

    function testSupportsInterface() public view {
        // ERC1155 and ERC165 should be supported, random interface should not
        assertTrue(roboshareTokens.supportsInterface(0xd9b67a26));
        assertTrue(roboshareTokens.supportsInterface(0x01ffc9a7));
        assertFalse(roboshareTokens.supportsInterface(0xffffffff));
    }

    // Fuzz Tests

    function testFuzzMint(address to, uint256 tokenId, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0 && amount < type(uint128).max);
        vm.assume(tokenId > 100 && tokenId < type(uint64).max); // Avoid collisions
        // Exclude contracts that might not implement ERC1155Receiver
        vm.assume(to.code.length == 0);

        vm.prank(minter);
        roboshareTokens.mint(to, tokenId, amount, "");

        assertEq(roboshareTokens.balanceOf(to, tokenId), amount);
    }

    function testFuzzBurn(uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(mintAmount > 0 && mintAmount < type(uint128).max);
        vm.assume(burnAmount <= mintAmount);

        uint256 tokenId = 101;

        // Mint first
        vm.prank(minter);
        roboshareTokens.mint(user1, tokenId, mintAmount, "");

        // Then burn
        vm.prank(burner);
        roboshareTokens.burn(user1, tokenId, burnAmount);

        assertEq(roboshareTokens.balanceOf(user1, tokenId), mintAmount - burnAmount);
    }

    function testFuzzTransfer(uint256 mintAmount, uint256 transferAmount) public {
        vm.assume(mintAmount > 0 && mintAmount < type(uint128).max);
        vm.assume(transferAmount <= mintAmount);

        uint256 tokenId = 101;

        // Mint to user1
        vm.prank(minter);
        roboshareTokens.mint(user1, tokenId, mintAmount, "");

        // Transfer to user2
        vm.prank(user1);
        roboshareTokens.safeTransferFrom(user1, user2, tokenId, transferAmount, "");

        assertEq(roboshareTokens.balanceOf(user1, tokenId), mintAmount - transferAmount);
        assertEq(roboshareTokens.balanceOf(user2, tokenId), transferAmount);
    }

    // Edge Cases

    function testMintZeroAmount() public {
        // ERC1155 allows minting 0 amount by default
        vm.prank(minter);
        roboshareTokens.mint(user1, 1, 0, "");

        assertEq(roboshareTokens.balanceOf(user1, 1), 0);
    }

    function testBurnMoreThanBalance() public {
        vm.prank(minter);
        roboshareTokens.mint(user1, 1, 100, "");

        vm.expectRevert();
        vm.prank(burner);
        roboshareTokens.burn(user1, 1, 150);
    }

    function testTransferMoreThanBalance() public {
        vm.prank(minter);
        roboshareTokens.mint(user1, 1, 100, "");

        vm.expectRevert();
        vm.prank(user1);
        roboshareTokens.safeTransferFrom(user1, user2, 1, 150, "");
    }

    function testGetUserPositionsNotRevenueToken() public {
        _ensureState(SetupState.RevenueTokensMinted); // Creates assetId (odd) and revenueTokenId (even)

        // Attempt to get positions for the vehicle NFT ID, which is not a revenue token
        vm.expectRevert(RoboshareTokens.NotRevenueToken.selector);
        roboshareTokens.getUserPositions(scenario.assetId, partner1);
    }

    function testSetRevenueTokenInfoNotRevenueToken() public {
        uint256 assetId = 101; // An odd number, not a revenue token
        uint256 price = 1e6;
        uint256 supply = 1000;

        vm.prank(minter);
        vm.expectRevert(RoboshareTokens.NotRevenueToken.selector);
        roboshareTokens.setRevenueTokenInfo(assetId, price, supply, block.timestamp + 365 days);
    }

    function testSetRevenueTokenInfoAlreadySet() public {
        uint256 revenueTokenId = 102; // An even number, a revenue token
        uint256 price = 1e6;
        uint256 supply = 1000;

        vm.prank(minter);
        roboshareTokens.setRevenueTokenInfo(revenueTokenId, price, supply, block.timestamp + 365 days);

        vm.startPrank(minter);
        vm.expectRevert(RoboshareTokens.RevenueTokenInfoAlreadySet.selector);
        roboshareTokens.setRevenueTokenInfo(revenueTokenId, price, supply, block.timestamp + 365 days);
        vm.stopPrank();
    }

    function testGetTokenPriceNotRevenueToken() public {
        uint256 assetId = 101; // An odd number, not a revenue token

        vm.expectRevert(RoboshareTokens.NotRevenueToken.selector);
        roboshareTokens.getTokenPrice(assetId);
    }

    function testGetSalesPenaltyNotRevenueToken() public {
        uint256 assetId = 101; // An odd number, not a revenue token
        vm.expectRevert(RoboshareTokens.NotRevenueToken.selector);
        roboshareTokens.getSalesPenalty(user1, assetId, 100);
    }

    function testGetSalesPenaltyHoldingPeriod() public {
        _ensureState(SetupState.RevenueTokensMinted);
        uint256 tokenId = scenario.revenueTokenId;
        uint256 amount = 100;

        // Transfer tokens to user1 (who does not own the asset)
        vm.prank(partner1);
        roboshareTokens.safeTransferFrom(partner1, user1, tokenId, amount, "");

        // Immediately after receiving, there should be a penalty for user1
        uint256 penalty = roboshareTokens.getSalesPenalty(user1, tokenId, amount);
        assertGt(penalty, 0, "Should have penalty immediately after acquisition");

        // Warp past holding period (30 days + 1)
        _warpPastHoldingPeriod();

        // Penalty should now be 0
        penalty = roboshareTokens.getSalesPenalty(user1, tokenId, amount);
        assertEq(penalty, 0, "Penalty should be zero after holding period");
    }

    // ID Conversion Tests

    function testGetAssetIdFromTokenId() public view {
        // Happy path: registered or unregistered (logic is dumb)
        uint256 tokenId = 1002;
        uint256 expectedAssetId = 1001;
        assertEq(roboshareTokens.getAssetIdFromTokenId(tokenId), expectedAssetId);
    }

    function testGetAssetIdFromTokenIdInvalid() public {
        // ID 0 -> InvalidRevenueTokenId
        vm.expectRevert(TokenLib.InvalidRevenueTokenId.selector);
        roboshareTokens.getAssetIdFromTokenId(0);

        // Odd ID -> InvalidRevenueTokenId
        vm.expectRevert(TokenLib.InvalidRevenueTokenId.selector);
        roboshareTokens.getAssetIdFromTokenId(1001);
    }

    function testGetTokenIdFromAssetId() public view {
        // Happy path: registered or unregistered (logic is dumb)
        uint256 assetId = 1001;
        uint256 expectedTokenId = 1002;
        assertEq(roboshareTokens.getTokenIdFromAssetId(assetId), expectedTokenId);
    }

    function testGetTokenIdFromAssetIdInvalid() public {
        // ID 0 -> InvalidAssetId
        vm.expectRevert(TokenLib.InvalidAssetId.selector);
        roboshareTokens.getTokenIdFromAssetId(0);

        // Even ID -> InvalidAssetId
        vm.expectRevert(TokenLib.InvalidAssetId.selector);
        roboshareTokens.getTokenIdFromAssetId(1002);
    }
}
