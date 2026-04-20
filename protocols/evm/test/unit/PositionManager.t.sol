// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Test } from "forge-std/Test.sol";
import { IPositionManager } from "../../contracts/interfaces/IPositionManager.sol";
import { PositionManager } from "../../contracts/PositionManager.sol";

contract PositionManagerTest is Test {
    PositionManager public positionManager;

    address public admin = makeAddr("admin");
    address public registryRouter = makeAddr("registryRouter");
    address public roboshareTokens = makeAddr("roboshareTokens");
    address public partnerManager = makeAddr("partnerManager");
    address public marketplace = makeAddr("marketplace");
    address public treasury = makeAddr("treasury");
    address public usdc = makeAddr("usdc");
    address public unauthorized = makeAddr("unauthorized");

    bytes32 private constant PRIMARY_REASON = keccak256("primary");
    bytes32 private constant LISTING_REASON = keccak256("listing");
    bytes32 private constant REDEEM_REASON = keccak256("redeem");
    bytes32 private constant SETTLE_REASON = keccak256("settle");
    bytes32 private constant CLAIM_REASON = keccak256("claim");

    event PositionMutated(
        uint256 indexed assetId,
        uint256 indexed tokenId,
        address indexed account,
        uint256 amount,
        uint256 auxValue,
        IPositionManager.PositionMutationType mutationType,
        bytes32 reason
    );

    event PositionLockUpdated(
        uint256 indexed assetId, uint256 indexed tokenId, address indexed account, uint256 lockUntil, bytes32 reason
    );

    event RedemptionEpochUpdated(
        uint256 indexed tokenId, uint256 indexed epochId, uint256 redeemableSupply, bytes32 reason
    );

    event SettlementConfigured(
        uint256 indexed assetId,
        uint256 indexed epochId,
        uint256 settlementAmount,
        uint256 settlementPerToken,
        bytes32 reason
    );

    event SettlementClaimRecorded(
        uint256 indexed assetId,
        uint256 indexed tokenId,
        address indexed account,
        uint256 burnAmount,
        uint256 payout,
        bytes32 reason
    );

    function setUp() public {
        positionManager = _deployPositionManager(
            admin, registryRouter, roboshareTokens, partnerManager, marketplace, treasury, usdc
        );
    }

    function testInitialization() public view {
        assertEq(positionManager.registryRouter(), registryRouter);
        assertEq(positionManager.roboshareTokens(), roboshareTokens);
        assertEq(positionManager.partnerManager(), partnerManager);
        assertEq(positionManager.marketplace(), marketplace);
        assertEq(positionManager.treasury(), treasury);
        assertEq(positionManager.usdc(), usdc);

        assertEq(positionManager.UPGRADER_ROLE(), keccak256("UPGRADER_ROLE"));
        assertEq(positionManager.POSITION_ADMIN_ROLE(), keccak256("POSITION_ADMIN_ROLE"));
        assertEq(positionManager.AUTHORIZED_ROUTER_ROLE(), keccak256("AUTHORIZED_ROUTER_ROLE"));
        assertEq(positionManager.AUTHORIZED_MARKETPLACE_ROLE(), keccak256("AUTHORIZED_MARKETPLACE_ROLE"));
        assertEq(positionManager.AUTHORIZED_TREASURY_ROLE(), keccak256("AUTHORIZED_TREASURY_ROLE"));

        assertTrue(positionManager.hasRole(positionManager.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(positionManager.hasRole(positionManager.UPGRADER_ROLE(), admin));
        assertTrue(positionManager.hasRole(positionManager.POSITION_ADMIN_ROLE(), admin));
        assertTrue(positionManager.hasRole(positionManager.AUTHORIZED_ROUTER_ROLE(), registryRouter));
        assertTrue(positionManager.hasRole(positionManager.AUTHORIZED_MARKETPLACE_ROLE(), marketplace));
        assertTrue(positionManager.hasRole(positionManager.AUTHORIZED_TREASURY_ROLE(), treasury));

        assertEq(
            positionManager.getRoleAdmin(positionManager.AUTHORIZED_ROUTER_ROLE()),
            positionManager.POSITION_ADMIN_ROLE()
        );
        assertEq(
            positionManager.getRoleAdmin(positionManager.AUTHORIZED_MARKETPLACE_ROLE()),
            positionManager.POSITION_ADMIN_ROLE()
        );
        assertEq(
            positionManager.getRoleAdmin(positionManager.AUTHORIZED_TREASURY_ROLE()),
            positionManager.POSITION_ADMIN_ROLE()
        );
    }

    function testInitializationZeroAddress() public {
        PositionManager implementation = new PositionManager();

        vm.expectRevert(IPositionManager.ZeroAddress.selector);
        new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(
                PositionManager.initialize,
                (admin, registryRouter, roboshareTokens, partnerManager, address(0), treasury, usdc)
            )
        );
    }

    function testPositionAdminCanRotateDependencyRoles() public {
        address newRouter = makeAddr("newRouter");
        address newMarketplace = makeAddr("newMarketplace");
        address newTreasury = makeAddr("newTreasury");

        vm.startPrank(admin);
        positionManager.updateRegistryRouter(newRouter);
        positionManager.updateMarketplace(newMarketplace);
        positionManager.updateTreasury(newTreasury);
        vm.stopPrank();

        assertEq(positionManager.registryRouter(), newRouter);
        assertEq(positionManager.marketplace(), newMarketplace);
        assertEq(positionManager.treasury(), newTreasury);

        assertFalse(positionManager.hasRole(positionManager.AUTHORIZED_ROUTER_ROLE(), registryRouter));
        assertFalse(positionManager.hasRole(positionManager.AUTHORIZED_MARKETPLACE_ROLE(), marketplace));
        assertFalse(positionManager.hasRole(positionManager.AUTHORIZED_TREASURY_ROLE(), treasury));
        assertTrue(positionManager.hasRole(positionManager.AUTHORIZED_ROUTER_ROLE(), newRouter));
        assertTrue(positionManager.hasRole(positionManager.AUTHORIZED_MARKETPLACE_ROLE(), newMarketplace));
        assertTrue(positionManager.hasRole(positionManager.AUTHORIZED_TREASURY_ROLE(), newTreasury));
    }

    function testUpdateMarketplaceZeroAddress() public {
        vm.expectRevert(IPositionManager.ZeroAddress.selector);
        vm.prank(admin);
        positionManager.updateMarketplace(address(0));
    }

    function testUpdateMarketplaceUnauthorizedCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                positionManager.POSITION_ADMIN_ROLE()
            )
        );
        vm.prank(unauthorized);
        positionManager.updateMarketplace(makeAddr("newMarketplace"));
    }

    function testAuthorizedMarketplaceCanRecordPositionMutation() public {
        IPositionManager.PositionMutation memory mutation = IPositionManager.PositionMutation({
            assetId: 1,
            tokenId: 2,
            account: makeAddr("holder"),
            amount: 3,
            auxValue: 4,
            mutationType: IPositionManager.PositionMutationType.Mint,
            reason: PRIMARY_REASON
        });

        vm.expectEmit(true, true, true, true, address(positionManager));
        emit PositionMutated(
            mutation.assetId,
            mutation.tokenId,
            mutation.account,
            mutation.amount,
            mutation.auxValue,
            mutation.mutationType,
            mutation.reason
        );

        vm.prank(marketplace);
        positionManager.recordPositionMutation(mutation);
    }

    function testUnauthorizedCallerCannotRecordPositionMutation() public {
        IPositionManager.PositionMutation memory mutation = IPositionManager.PositionMutation({
            assetId: 1,
            tokenId: 2,
            account: makeAddr("holder"),
            amount: 3,
            auxValue: 4,
            mutationType: IPositionManager.PositionMutationType.Mint,
            reason: PRIMARY_REASON
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorized,
                positionManager.AUTHORIZED_MARKETPLACE_ROLE()
            )
        );
        vm.prank(unauthorized);
        positionManager.recordPositionMutation(mutation);
    }

    function testAuthorizedRouterCanRecordPositionLock() public {
        vm.expectEmit(true, true, true, true, address(positionManager));
        emit PositionLockUpdated(1, 2, makeAddr("holder"), block.timestamp + 1 days, LISTING_REASON);

        vm.prank(registryRouter);
        positionManager.recordPositionLock(1, 2, makeAddr("holder"), block.timestamp + 1 days, LISTING_REASON);
    }

    function testAuthorizedTreasuryCanRecordRedemptionAndSettlementEvents() public {
        vm.startPrank(treasury);

        vm.expectEmit(true, true, false, true, address(positionManager));
        emit RedemptionEpochUpdated(2, 1, 100, REDEEM_REASON);
        positionManager.recordRedemptionEpoch(2, 1, 100, REDEEM_REASON);

        vm.expectEmit(true, true, false, true, address(positionManager));
        emit SettlementConfigured(1, 1, 1000, 10, SETTLE_REASON);
        positionManager.recordSettlement(1, 1, 1000, 10, SETTLE_REASON);

        vm.expectEmit(true, true, true, true, address(positionManager));
        emit SettlementClaimRecorded(1, 2, makeAddr("holder"), 20, 200, CLAIM_REASON);
        positionManager.recordSettlementClaim(1, 2, makeAddr("holder"), 20, 200, CLAIM_REASON);

        vm.stopPrank();
    }

    function testUpgradeAuthorizedCaller() public {
        PositionManager newImplementation = new PositionManager();

        vm.prank(admin);
        positionManager.upgradeToAndCall(address(newImplementation), "");
    }

    function testUpgradeUnauthorizedCaller() public {
        PositionManager newImplementation = new PositionManager();

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, unauthorized, positionManager.UPGRADER_ROLE()
            )
        );
        vm.prank(unauthorized);
        positionManager.upgradeToAndCall(address(newImplementation), "");
    }

    function _deployPositionManager(
        address _admin,
        address _registryRouter,
        address _roboshareTokens,
        address _partnerManager,
        address _marketplace,
        address _treasury,
        address _usdc
    ) internal returns (PositionManager) {
        PositionManager implementation = new PositionManager();
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeCall(
                PositionManager.initialize,
                (_admin, _registryRouter, _roboshareTokens, _partnerManager, _marketplace, _treasury, _usdc)
            )
        );

        return PositionManager(address(proxy));
    }
}
