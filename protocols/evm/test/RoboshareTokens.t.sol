// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/RoboshareTokens.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract RoboshareTokensTest is Test {
    RoboshareTokens public tokens;
    RoboshareTokens public tokenImplementation;

    address public admin = makeAddr("admin");
    address public minter = makeAddr("minter");
    address public burner = makeAddr("burner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public unauthorized = makeAddr("unauthorized");

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    event BatchTokensMinted(address indexed to, uint256[] ids, uint256[] amounts);
    event TokensBurned(address indexed from, uint256 id, uint256 amount);

    function setUp() public {
        // Deploy implementation
        tokenImplementation = new RoboshareTokens();

        // Deploy proxy
        bytes memory initData = abi.encodeWithSignature("initialize(address)", admin);
        ERC1967Proxy proxy = new ERC1967Proxy(address(tokenImplementation), initData);
        tokens = RoboshareTokens(address(proxy));

        // Grant roles
        vm.startPrank(admin);
        tokens.grantRole(MINTER_ROLE, minter);
        tokens.grantRole(BURNER_ROLE, burner);
        vm.stopPrank();
    }

    function testInitialization() public {
        // Check roles
        assertTrue(tokens.hasRole(tokens.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(tokens.hasRole(MINTER_ROLE, admin));
        assertTrue(tokens.hasRole(BURNER_ROLE, admin));
        assertTrue(tokens.hasRole(UPGRADER_ROLE, admin));

        // Check token counter starts at 1
        assertEq(tokens.getNextTokenId(), 1);

        // Check interface support
        assertTrue(tokens.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(tokens.supportsInterface(type(IAccessControl).interfaceId));
    }

    function testMintSingleToken() public {
        uint256 tokenId = 1;
        uint256 amount = 100;
        bytes memory data = "";

        vm.prank(minter);
        tokens.mint(user1, tokenId, amount, data);

        assertEq(tokens.balanceOf(user1, tokenId), amount);
    }

    function testMintBatchTokens() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        amounts[0] = 100;
        amounts[1] = 200;
        bytes memory data = "";

        vm.expectEmit(true, true, false, true);
        emit BatchTokensMinted(user1, ids, amounts);

        vm.prank(minter);
        tokens.mintBatch(user1, ids, amounts, data);

        assertEq(tokens.balanceOf(user1, 1), 100);
        assertEq(tokens.balanceOf(user1, 2), 200);
    }

    function testBurnSingleToken() public {
        // Setup: mint tokens first
        uint256 tokenId = 1;
        uint256 amount = 100;

        vm.prank(minter);
        tokens.mint(user1, tokenId, amount, "");

        // Test burn
        vm.expectEmit(true, true, false, true);
        emit TokensBurned(user1, tokenId, 50);

        vm.prank(burner);
        tokens.burn(user1, tokenId, 50);

        assertEq(tokens.balanceOf(user1, tokenId), 50);
    }

    function testBurnBatchTokens() public {
        // Setup: mint tokens first
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        amounts[0] = 100;
        amounts[1] = 200;

        vm.prank(minter);
        tokens.mintBatch(user1, ids, amounts, "");

        // Test burn batch
        uint256[] memory burnAmounts = new uint256[](2);
        burnAmounts[0] = 30;
        burnAmounts[1] = 50;

        vm.expectEmit(true, true, false, true);
        emit TokensBurned(user1, 1, 30);

        vm.prank(burner);
        tokens.burnBatch(user1, ids, burnAmounts);

        assertEq(tokens.balanceOf(user1, 1), 70);
        assertEq(tokens.balanceOf(user1, 2), 150);
    }

    function testTokenIdManagement() public {
        assertEq(tokens.getNextTokenId(), 1);

        vm.prank(minter);
        uint256 nextId = tokens.getAndIncrementTokenId();
        assertEq(nextId, 1);
        assertEq(tokens.getNextTokenId(), 2);

        vm.prank(minter);
        uint256 nextId2 = tokens.getAndIncrementTokenId();
        assertEq(nextId2, 2);
        assertEq(tokens.getNextTokenId(), 3);
    }

    function testSetURI() public {
        string memory newURI = "https://api.roboshare.com/tokens/{id}.json";

        vm.prank(admin);
        tokens.setURI(newURI);

        assertEq(tokens.uri(1), newURI);
    }

    function testTransfers() public {
        // Setup: mint tokens to user1
        uint256 tokenId = 1;
        uint256 amount = 100;

        vm.prank(minter);
        tokens.mint(user1, tokenId, amount, "");

        // Transfer from user1 to user2
        vm.prank(user1);
        tokens.safeTransferFrom(user1, user2, tokenId, 30, "");

        assertEq(tokens.balanceOf(user1, tokenId), 70);
        assertEq(tokens.balanceOf(user2, tokenId), 30);
    }

    function testBatchTransfers() public {
        // Setup: mint multiple tokens to user1
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        amounts[0] = 100;
        amounts[1] = 200;

        vm.prank(minter);
        tokens.mintBatch(user1, ids, amounts, "");

        // Batch transfer
        uint256[] memory transferAmounts = new uint256[](2);
        transferAmounts[0] = 30;
        transferAmounts[1] = 50;

        vm.prank(user1);
        tokens.safeBatchTransferFrom(user1, user2, ids, transferAmounts, "");

        assertEq(tokens.balanceOf(user1, 1), 70);
        assertEq(tokens.balanceOf(user1, 2), 150);
        assertEq(tokens.balanceOf(user2, 1), 30);
        assertEq(tokens.balanceOf(user2, 2), 50);
    }

    // Access Control Tests

    function testUnauthorizedMintFails() public {
        vm.expectRevert();
        vm.prank(unauthorized);
        tokens.mint(user1, 1, 100, "");
    }

    function testUnauthorizedBurnFails() public {
        // Setup: mint token first
        vm.prank(minter);
        tokens.mint(user1, 1, 100, "");

        vm.expectRevert();
        vm.prank(unauthorized);
        tokens.burn(user1, 1, 50);
    }

    function testUnauthorizedSetURIFails() public {
        vm.expectRevert();
        vm.prank(unauthorized);
        tokens.setURI("unauthorized-uri");
    }

    function testUnauthorizedTokenIdIncrementFails() public {
        vm.expectRevert();
        vm.prank(unauthorized);
        tokens.getAndIncrementTokenId();
    }

    function testRoleManagement() public {
        // Admin can grant roles
        vm.prank(admin);
        tokens.grantRole(MINTER_ROLE, user1);
        assertTrue(tokens.hasRole(MINTER_ROLE, user1));

        // Admin can revoke roles
        vm.prank(admin);
        tokens.revokeRole(MINTER_ROLE, user1);
        assertFalse(tokens.hasRole(MINTER_ROLE, user1));
    }

    // Fuzz Tests

    function testFuzzMint(address to, uint256 tokenId, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0 && amount < type(uint128).max);
        vm.assume(tokenId > 0 && tokenId < type(uint64).max);

        vm.prank(minter);
        tokens.mint(to, tokenId, amount, "");

        assertEq(tokens.balanceOf(to, tokenId), amount);
    }

    function testFuzzBurn(uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(mintAmount > 0 && mintAmount < type(uint128).max);
        vm.assume(burnAmount <= mintAmount);

        uint256 tokenId = 1;

        // Mint first
        vm.prank(minter);
        tokens.mint(user1, tokenId, mintAmount, "");

        // Then burn
        vm.prank(burner);
        tokens.burn(user1, tokenId, burnAmount);

        assertEq(tokens.balanceOf(user1, tokenId), mintAmount - burnAmount);
    }

    function testFuzzTransfer(uint256 mintAmount, uint256 transferAmount) public {
        vm.assume(mintAmount > 0 && mintAmount < type(uint128).max);
        vm.assume(transferAmount <= mintAmount);

        uint256 tokenId = 1;

        // Mint to user1
        vm.prank(minter);
        tokens.mint(user1, tokenId, mintAmount, "");

        // Transfer to user2
        vm.prank(user1);
        tokens.safeTransferFrom(user1, user2, tokenId, transferAmount, "");

        assertEq(tokens.balanceOf(user1, tokenId), mintAmount - transferAmount);
        assertEq(tokens.balanceOf(user2, tokenId), transferAmount);
    }

    // Edge Cases

    function testMintZeroAmount() public {
        // ERC1155 allows minting 0 amount by default
        vm.prank(minter);
        tokens.mint(user1, 1, 0, "");

        assertEq(tokens.balanceOf(user1, 1), 0);
    }

    function testBurnMoreThanBalance() public {
        vm.prank(minter);
        tokens.mint(user1, 1, 100, "");

        vm.expectRevert();
        vm.prank(burner);
        tokens.burn(user1, 1, 150);
    }

    function testTransferMoreThanBalance() public {
        vm.prank(minter);
        tokens.mint(user1, 1, 100, "");

        vm.expectRevert();
        vm.prank(user1);
        tokens.safeTransferFrom(user1, user2, 1, 150, "");
    }
}
