// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./BaseTest.t.sol";

contract RoboshareTokensTest is BaseTest {
    address public minter;
    address public burner;
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    event BatchTokensMinted(address indexed to, uint256[] ids, uint256[] amounts);
    event TokensBurned(address indexed from, uint256 id, uint256 amount);

    function setUp() public {
        _ensureState(SetupState.ContractsDeployed);
        minter = address(vehicleRegistry);
        burner = admin; // Admin has burner role by default
    }

    function testInitialization() public view {
        // Check roles
        assertTrue(roboshareTokens.hasRole(roboshareTokens.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(roboshareTokens.hasRole(MINTER_ROLE, admin));
        assertTrue(roboshareTokens.hasRole(BURNER_ROLE, admin));
        assertTrue(roboshareTokens.hasRole(keccak256("UPGRADER_ROLE"), admin));

        // Check token counter starts at 1
        assertEq(roboshareTokens.getNextTokenId(), 1);

        // Check interface support
        assertTrue(roboshareTokens.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(roboshareTokens.supportsInterface(type(IAccessControl).interfaceId));
    }

    function testMintSingleToken() public {
        uint256 tokenId = 101; // Use a high number to avoid collision
        uint256 amount = 100;
        bytes memory data = "";

        vm.prank(admin); // Admin has minter role
        roboshareTokens.mint(user1, tokenId, amount, data);

        assertEq(roboshareTokens.balanceOf(user1, tokenId), amount);
    }

    function testMintBatchTokens() public {
        uint256[] memory ids = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        ids[0] = 101;
        ids[1] = 102;
        amounts[0] = 100;
        amounts[1] = 200;
        bytes memory data = "";

        vm.expectEmit(true, true, false, true);
        emit BatchTokensMinted(user1, ids, amounts);

        vm.prank(admin); // Admin has minter role
        roboshareTokens.mintBatch(user1, ids, amounts, data);

        assertEq(roboshareTokens.balanceOf(user1, 101), 100);
        assertEq(roboshareTokens.balanceOf(user1, 102), 200);
    }

    function testBurnSingleToken() public {
        // Setup: mint tokens first
        uint256 tokenId = 101;
        uint256 amount = 100;

        vm.prank(admin);
        roboshareTokens.mint(user1, tokenId, amount, "");

        // Test burn
        vm.expectEmit(true, true, false, true);
        emit TokensBurned(user1, tokenId, 50);

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

        vm.prank(admin);
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

    function testTokenIdManagement() public {
        assertEq(roboshareTokens.getNextTokenId(), 1);

        vm.prank(admin);
        uint256 nextId = roboshareTokens.getAndIncrementTokenId();
        assertEq(nextId, 1);
        assertEq(roboshareTokens.getNextTokenId(), 2);

        vm.prank(admin);
        uint256 nextId2 = roboshareTokens.getAndIncrementTokenId();
        assertEq(nextId2, 2);
        assertEq(roboshareTokens.getNextTokenId(), 3);
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

        vm.prank(admin);
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

        vm.prank(admin);
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

    function testUnauthorizedMintFails() public {
        vm.expectRevert();
        vm.prank(unauthorized);
        roboshareTokens.mint(user1, 1, 100, "");
    }

    function testUnauthorizedBurnFails() public {
        // Setup: mint token first
        vm.prank(admin);
        roboshareTokens.mint(user1, 1, 100, "");

        vm.expectRevert();
        vm.prank(unauthorized);
        roboshareTokens.burn(user1, 1, 50);
    }

    function testUnauthorizedSetURIFails() public {
        vm.expectRevert();
        vm.prank(unauthorized);
        roboshareTokens.setURI("unauthorized-uri");
    }

    function testUnauthorizedTokenIdIncrementFails() public {
        vm.expectRevert();
        vm.prank(unauthorized);
        roboshareTokens.getAndIncrementTokenId();
    }

    function testRoleManagement() public {
        // Admin can grant roles
        vm.prank(admin);
        roboshareTokens.grantRole(MINTER_ROLE, user1);
        assertTrue(roboshareTokens.hasRole(MINTER_ROLE, user1));

        // Admin can revoke roles
        vm.prank(admin);
        roboshareTokens.revokeRole(MINTER_ROLE, user1);
        assertFalse(roboshareTokens.hasRole(MINTER_ROLE, user1));
    }

    // Fuzz Tests

    function testFuzzMint(address to, uint256 tokenId, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0 && amount < type(uint128).max);
        vm.assume(tokenId > 100 && tokenId < type(uint64).max); // Avoid collisions
        // Exclude contracts that might not implement ERC1155Receiver
        vm.assume(to.code.length == 0);

        vm.prank(admin);
        roboshareTokens.mint(to, tokenId, amount, "");

        assertEq(roboshareTokens.balanceOf(to, tokenId), amount);
    }

    function testFuzzBurn(uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(mintAmount > 0 && mintAmount < type(uint128).max);
        vm.assume(burnAmount <= mintAmount);

        uint256 tokenId = 101;

        // Mint first
        vm.prank(admin);
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
        vm.prank(admin);
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
        vm.prank(admin);
        roboshareTokens.mint(user1, 1, 0, "");

        assertEq(roboshareTokens.balanceOf(user1, 1), 0);
    }

    function testBurnMoreThanBalance() public {
        vm.prank(admin);
        roboshareTokens.mint(user1, 1, 100, "");

        vm.expectRevert();
        vm.prank(burner);
        roboshareTokens.burn(user1, 1, 150);
    }

    function testTransferMoreThanBalance() public {
        vm.prank(admin);
        roboshareTokens.mint(user1, 1, 100, "");

        vm.expectRevert();
        vm.prank(user1);
        roboshareTokens.safeTransferFrom(user1, user2, 1, 150, "");
    }
}
