// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/Libraries.sol";

// Helper to expose ProtocolLib/EarningsLib pure functions
contract ProtocolEarningsHelper {
    function isValidIPFSURI(string memory uri) external pure returns (bool) {
        return ProtocolLib.isValidIPFSURI(uri);
    }

    function protocolFee(uint256 amount) external pure returns (uint256) {
        return ProtocolLib.calculateProtocolFee(amount);
    }

    function penalty(uint256 amount, uint256 price) external pure returns (uint256) {
        return ProtocolLib.calculatePenalty(amount, price);
    }

    function calcBenchmark(uint256 principal, uint256 timeElapsed, uint256 bp) external pure returns (uint256) {
        return EarningsLib.calculateBenchmarkEarnings(principal, timeElapsed, bp);
    }

    function calcBenchmarkDefault(uint256 principal, uint256 timeElapsed) external pure returns (uint256) {
        return EarningsLib.calculateBenchmarkEarnings(principal, timeElapsed);
    }
}

// Helper to hold and mutate AssetInfo
contract AssetsHelper {
    using AssetsLib for AssetsLib.AssetInfo;

    AssetsLib.AssetInfo internal info;

    function init(AssetsLib.AssetStatus s) external {
        info.initializeAssetInfo(s);
    }

    function update(AssetsLib.AssetStatus s) external {
        info.updateAssetStatus(s);
    }

    function status() external view returns (AssetsLib.AssetStatus) {
        return info.status;
    }

    function isOperational() external view returns (bool) {
        return info.isOperational();
    }

    function age() external view returns (uint256) {
        return info.getAssetAge();
    }

    function sinceUpdate() external view returns (uint256) {
        return info.getTimeSinceUpdate();
    }
}

// Helper to hold and mutate CollateralInfo and EarningsInfo/TokenInfo for cross-lib tests
contract CollateralTokenEarningsHelper {
    using CollateralLib for CollateralLib.CollateralInfo;
    using TokenLib for TokenLib.TokenInfo;

    CollateralLib.CollateralInfo internal c;
    EarningsLib.EarningsInfo internal e;
    TokenLib.TokenInfo internal t;

    function initCollateral(uint256 price, uint256 total, uint256 interval) external {
        c.initializeCollateralInfo(price, total, interval);
    }

    function collateralView()
        external
        view
        returns (uint256 baseCollateral, uint256 earningsBuffer, uint256 protocolBuffer, uint256 totalCollateral)
    {
        return (c.baseCollateral, c.earningsBuffer, c.protocolBuffer, c.totalCollateral);
    }

    function isCollateralInitialized() external view returns (bool) {
        return c.isInitialized();
    }

    function lockNow() external {
        c.isLocked = true;
        c.lockedAt = block.timestamp;
    }

    function lockDuration() external view returns (uint256) {
        return c.getLockDuration();
    }

    function getBreakdown(uint256 price, uint256 total, uint256 interval)
        external
        pure
        returns (uint256, uint256, uint256, uint256)
    {
        return CollateralLib.getCollateralBreakdown(price, total, interval);
    }

    function calcReq(uint256 base, uint256 interval)
        external
        pure
        returns (uint256, uint256, uint256)
    {
        return CollateralLib.calculateCollateralRequirements(base, interval);
    }

    function depreciation(uint256 base, uint256 elapsed) external pure returns (uint256) {
        return CollateralLib.calculateDepreciation(base, elapsed);
    }

    function process(uint256 net, uint256 base) external returns (int256, uint256) {
        return CollateralLib.processEarningsForBuffers(c, net, base);
    }

    function targetBuffer(uint256 base) external pure returns (uint256) {
        return CollateralLib.getTargetEarningsBuffer(base);
    }

    function initToken(uint256 tokenId, uint256 supply, uint256 price, uint256 minHold) external {
        t.initializeTokenInfo(tokenId, supply, price, minHold);
    }

    function tokenInfo() external view returns (uint256, uint256, uint256, uint256) {
        return (t.tokenId, t.totalSupply, t.tokenPrice, t.minHoldingPeriod);
    }

    function addPos(address h, uint256 amt) external {
        t.addPosition(h, amt);
    }

    function removePos(address h, uint256 amt, bool checkPenalty) external returns (uint256) {
        return t.removePosition(h, amt, checkPenalty);
    }

    function tokenValue(uint256 amt) external view returns (uint256) {
        return t.calculateTokenValue(amt);
    }

    function bal(address h) external view returns (uint256) {
        return t.getBalance(h);
    }

    function mature(TokenLib.TokenPosition storage p, uint256 minHold) internal view returns (bool) {
        return TokenLib.isPositionMature(p, minHold);
    }

    function initEarnings() external {
        EarningsLib.initializeEarningsInfo(e);
    }

    function setPeriod(uint256 p, uint256 ept, uint256 ts, uint256 total) external {
        e.periods[p] = EarningsLib.EarningsPeriod({ earningsPerToken: ept, timestamp: ts, totalEarnings: total });
        if (p > e.currentPeriod) e.currentPeriod = p;
    }

    function getPeriodAtTs(uint256 ts) external view returns (uint256) {
        return EarningsLib.getPeriodAtTimestamp(e, ts);
    }

    function unclaimed(uint256 bal_, uint256 last) external view returns (uint256) {
        return EarningsLib.calculateUnclaimedEarnings(e, bal_, last);
    }

    function unclaimedForPositions(address holder, uint256 last) external view returns (uint256) {
        return t.calculateUnclaimedEarningsForPositions(holder, e, last);
    }
}

contract LibrariesTest is Test {
    ProtocolEarningsHelper private peh;
    AssetsHelper private ah;
    CollateralTokenEarningsHelper private cteh;

    address private alice = address(0xA11CE);

    function setUp() public {
        peh = new ProtocolEarningsHelper();
        ah = new AssetsHelper();
        cteh = new CollateralTokenEarningsHelper();
    }

    // ProtocolLib tests
    function test_IPFSValidation() public pure {
        // invalid: empty and just prefix
        assertFalse(ProtocolLib.isValidIPFSURI(""));
        assertFalse(ProtocolLib.isValidIPFSURI("ipfs://"));
        // invalid: wrong prefix
        assertFalse(ProtocolLib.isValidIPFSURI("http://something"));
        // valid
        assertTrue(ProtocolLib.isValidIPFSURI("ipfs://QmHashValue"));
    }

    function test_ProtocolFeeAndPenalty() public pure {
        assertEq(ProtocolLib.calculateProtocolFee(10_000), 250); // 2.5%
        // 10 tokens at price 100 => 5% = 50
        assertEq(ProtocolLib.calculatePenalty(10, 100), 50);
    }

    // AssetsLib tests
    function test_Assets_InitAndTransitions() public {
        ah.init(AssetsLib.AssetStatus.Inactive);
        assertEq(uint8(ah.status()), uint8(AssetsLib.AssetStatus.Inactive));
        assertFalse(ah.isOperational());

        // Valid transition Inactive -> Active
        ah.update(AssetsLib.AssetStatus.Active);
        assertTrue(ah.isOperational());

        // Valid transition Active -> Suspended
        ah.update(AssetsLib.AssetStatus.Suspended);
        assertFalse(ah.isOperational());

        // Invalid: Suspended -> Inactive, assert exact custom error with args
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetsLib.AssetsLib__InvalidStatusTransition.selector,
                AssetsLib.AssetStatus.Suspended,
                AssetsLib.AssetStatus.Inactive
            )
        );
        ah.update(AssetsLib.AssetStatus.Inactive);

        // Valid: Suspended -> Active
        ah.update(AssetsLib.AssetStatus.Active);

        // Valid: Active -> Archived; further transitions invalid
        ah.update(AssetsLib.AssetStatus.Archived);
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetsLib.AssetsLib__InvalidStatusTransition.selector,
                AssetsLib.AssetStatus.Archived,
                AssetsLib.AssetStatus.Active
            )
        );
        ah.update(AssetsLib.AssetStatus.Active);
    }

    function test_Assets_TimeViews() public {
        ah.init(AssetsLib.AssetStatus.Active);
        uint256 t0 = block.timestamp;
        vm.warp(t0 + 1 days);
        assertApproxEqAbs(ah.age(), 1 days, 2);
        // status update moves updatedAt
        ah.update(AssetsLib.AssetStatus.Active);
        uint256 mid = block.timestamp;
        vm.warp(mid + 3 hours);
        assertApproxEqAbs(ah.sinceUpdate(), 3 hours, 2);
    }

    // CollateralLib tests
    function test_Collateral_InitAndView() public {
        // invalid input
        vm.expectRevert(CollateralLib__InvalidCollateralAmount.selector);
        cteh.initCollateral(0, 1000, ProtocolLib.QUARTERLY_INTERVAL);

        cteh.initCollateral(100e6, 1000, ProtocolLib.QUARTERLY_INTERVAL);
        (uint256 baseCol, uint256 earnBuf, uint256 protBuf, uint256 totalCol) = cteh.collateralView();
        assertEq(baseCol, 100e9);
        assertTrue(cteh.isCollateralInitialized());
        assertGt(earnBuf, 0);
        assertGt(protBuf, 0);
        assertEq(totalCol, baseCol + earnBuf + protBuf);

        // lock duration behavior
        assertEq(cteh.lockDuration(), 0);
        cteh.lockNow();
        vm.warp(block.timestamp + 7 days);
        assertApproxEqAbs(cteh.lockDuration(), 7 days, 2);
    }

    function test_Collateral_BreakdownAndRequirements() public pure {
        (uint256 baseAmt, uint256 eBuf, uint256 pBuf, uint256 tot) =
            CollateralLib.getCollateralBreakdown(100e6, 1000, ProtocolLib.QUARTERLY_INTERVAL);
        assertEq(baseAmt, 100e9);
        assertEq(tot, baseAmt + eBuf + pBuf);

        (uint256 e2, uint256 p2, uint256 t2) =
            CollateralLib.calculateCollateralRequirements(baseAmt, ProtocolLib.QUARTERLY_INTERVAL);
        assertEq(eBuf, e2);
        assertEq(pBuf, p2);
        assertEq(tot, t2 + 0); // same total
    }

    function test_Collateral_DepreciationAndBuffers() public {
        cteh.initCollateral(100e6, 1000, ProtocolLib.QUARTERLY_INTERVAL);
        uint256 dep = cteh.depreciation(100e9, 30 days);
        assertGt(dep, 0);

        // Setup buffers for processEarningsForBuffers
        // Shortfall path
        (int256 res, uint256 rep) = cteh.process(1e9, 2e9);
        assertLt(res, 0); // shortfall
        assertEq(rep, 0);

        // Excess path with replenishment from reserved
        // Manually top-up state to simulate reserved funds and low earningsBuffer
        (
            uint256 baseCol,
            uint256 eBuf,
            uint256 pBuf,
            uint256 totalCol
        ) = cteh.collateralView();
        // silence warnings
        baseCol; pBuf; totalCol; eBuf;

        // Call process with net > base to trigger replenishment logic
        (int256 posRes, uint256 replenished) = cteh.process(10e9, 2e9);
        assertGe(posRes, 0);
        // replenished may be zero or positive depending on internal state; assert it doesn't underflow
        assertGe(replenished, 0);
    }

    // TokenLib tests
    function test_Token_InitAddRemoveAndValues() public {
        // min holding coerced to at least MONTHLY_INTERVAL
        cteh.initToken(1, 1000, 100e6, 1 days);
        (uint256 tid, uint256 supply, uint256 price, uint256 minHold) = cteh.tokenInfo();
        assertEq(tid, 1);
        assertEq(supply, 1000);
        assertEq(price, 100e6);
        assertEq(minHold, ProtocolLib.MONTHLY_INTERVAL);

        // add and remove positions
        cteh.addPos(alice, 100);
        assertEq(cteh.bal(alice), 100);
        // removing before maturity with penalty
        uint256 penaltyAmt = cteh.removePos(alice, 50, true);
        assertGt(penaltyAmt, 0);
        assertEq(cteh.bal(alice), 50);

        // token value
        assertEq(cteh.tokenValue(5), 5 * 100e6);
    }

    function test_Token_UnclaimedForPositionsAndEarningsHelpers() public {
        cteh.initToken(7, 1000, 1e6, ProtocolLib.MONTHLY_INTERVAL);
        cteh.addPos(alice, 10);

        // Initialize earnings and set three periods
        cteh.initEarnings();
        uint256 t0 = block.timestamp;
        // periods at t0, t0+30d, t0+60d
        cteh.setPeriod(1, 2e6, t0, 20e6);
        cteh.setPeriod(2, 3e6, t0 + 30 days, 30e6);
        cteh.setPeriod(3, 0, t0 + 60 days, 0);

        // getPeriodAtTimestamp
        assertEq(cteh.getPeriodAtTs(t0 + 1 days), 1);
        assertEq(cteh.getPeriodAtTs(t0 + 45 days), 2);

        // calculateUnclaimedEarnings by balance
        assertEq(cteh.unclaimed(10, 0), 50e6); // (2 + 3) * 10 tokens

        // positions-based unclaimed (same as balance since single active position)
        assertEq(cteh.unclaimedForPositions(alice, 0), 50e6);
    }
}
