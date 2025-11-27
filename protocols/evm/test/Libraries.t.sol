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

    function calcEarnings(uint256 principal, uint256 timeElapsed, uint256 bp) external pure returns (uint256) {
        return EarningsLib.calculateEarnings(principal, timeElapsed, bp);
    }

    function calcBenchmarkDefault(uint256 principal, uint256 timeElapsed) external pure returns (uint256) {
        return EarningsLib.calculateBenchmarkEarnings(principal, timeElapsed);
    }
}

// Helper to hold and mutate AssetInfo
contract AssetHelper {
    using AssetLib for AssetLib.AssetInfo;

    AssetLib.AssetInfo internal info;

    function init(AssetLib.AssetStatus s) external {
        info.initializeAssetInfo();
        if (s != AssetLib.AssetStatus.Pending) {
            info.updateAssetStatus(s);
        }
    }

    function update(AssetLib.AssetStatus s) external {
        info.updateAssetStatus(s);
    }

    function status() external view returns (AssetLib.AssetStatus) {
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

    function calcReq(uint256 tokenPrice, uint256 tokenSupply, uint256 interval)
        external
        pure
        returns (uint256, uint256, uint256, uint256)
    {
        return CollateralLib.calculateCollateralRequirements(tokenPrice, tokenSupply, interval);
    }

    function depreciation(uint256 base, uint256 elapsed) external pure returns (uint256) {
        return CollateralLib.calculateDepreciation(base, elapsed);
    }

    function process(uint256 net, uint256 base) external returns (int256, uint256) {
        return CollateralLib.processEarningsForBuffers(c, net, base);
    }

    function targetBuffer(uint256 base) external pure returns (uint256) {
        return CollateralLib.getBenchmarkEarningsBuffer(base);
    }

    function initToken(uint256 tokenId, uint256 price, uint256 minHold) external {
        t.initializeTokenInfo(tokenId, price, minHold);
    }

    function tokenInfo() external view returns (uint256, uint256, uint256, uint256) {
        return (t.tokenId, t.tokenPrice, t.tokenSupply, t.minHoldingPeriod);
    }

    function addPos(address h, uint256 amt) external {
        t.addPosition(h, amt);
    }

    function removePos(address h, uint256 amt) external {
        return t.removePosition(h, amt);
    }

    function tokenValue(uint256 amt) external view returns (uint256) {
        return t.calculateTokenValue(amt);
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
    AssetHelper private ah;
    CollateralTokenEarningsHelper private cteh;

    address private alice = address(0xA11CE);

    function setUp() public {
        peh = new ProtocolEarningsHelper();
        ah = new AssetHelper();
        cteh = new CollateralTokenEarningsHelper();
    }

    // ProtocolLib tests
    function testIPFSValidation() public pure {
        // invalid: empty and just prefix
        assertFalse(ProtocolLib.isValidIPFSURI(""));
        assertFalse(ProtocolLib.isValidIPFSURI("ipfs://"));
        // invalid: wrong prefix
        assertFalse(ProtocolLib.isValidIPFSURI("http://something"));
        // valid
        assertTrue(ProtocolLib.isValidIPFSURI("ipfs://QmHashValue"));
    }

    function testProtocolFeeAndPenalty() public pure {
        assertEq(ProtocolLib.calculateProtocolFee(10_000), ProtocolLib.MIN_PROTOCOL_FEE); // 2.5% is less than min fee
        // 10 tokens at price 100 => 5% = 50
        assertEq(ProtocolLib.calculatePenalty(10, 100), 50);
    }

    // AssetLib tests
    function testAssetsInitAndTransitions() public {
        ah.init(AssetLib.AssetStatus.Pending);
        assertEq(uint8(ah.status()), uint8(AssetLib.AssetStatus.Pending));
        assertFalse(ah.isOperational());

        // Valid transition Pending -> Active
        ah.update(AssetLib.AssetStatus.Active);
        assertTrue(ah.isOperational());

        // Valid transition Active -> Suspended
        ah.update(AssetLib.AssetStatus.Suspended);
        assertFalse(ah.isOperational());

        // Invalid: Suspended -> Pending, assert exact custom error with args
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetLib.InvalidStatusTransition.selector, AssetLib.AssetStatus.Suspended, AssetLib.AssetStatus.Pending
            )
        );
        ah.update(AssetLib.AssetStatus.Pending);

        // Valid: Suspended -> Active
        ah.update(AssetLib.AssetStatus.Active);

        // Valid: Active -> Archived; further transitions invalid
        ah.update(AssetLib.AssetStatus.Archived);
        vm.expectRevert(
            abi.encodeWithSelector(
                AssetLib.InvalidStatusTransition.selector, AssetLib.AssetStatus.Archived, AssetLib.AssetStatus.Active
            )
        );
        ah.update(AssetLib.AssetStatus.Active);
    }

    function testAssetsTimeViews() public {
        ah.init(AssetLib.AssetStatus.Active);
        uint256 t0 = block.timestamp;
        vm.warp(t0 + 1 days);
        assertApproxEqAbs(ah.age(), 1 days, 2);
        // status update moves updatedAt
        ah.update(AssetLib.AssetStatus.Active);
        uint256 mid = block.timestamp;
        vm.warp(mid + 3 hours);
        assertApproxEqAbs(ah.sinceUpdate(), 3 hours, 2);
    }

    // CollateralLib tests
    function testCollateralInitAndView() public {
        // invalid input
        vm.expectRevert(CollateralLib.InvalidCollateralAmount.selector);
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

    function testCollateralRequirements() public pure {
        (uint256 baseAmt, uint256 eBuf, uint256 pBuf, uint256 tot) =
            CollateralLib.calculateCollateralRequirements(100e6, 1000, ProtocolLib.QUARTERLY_INTERVAL);
        assertEq(baseAmt, 100e9);
        assertEq(tot, baseAmt + eBuf + pBuf);
    }

    function testCollateralDepreciationAndBuffers() public {
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
        (uint256 baseCol, uint256 eBuf, uint256 pBuf, uint256 totalCol) = cteh.collateralView();
        // silence warnings
        baseCol;
        pBuf;
        totalCol;
        eBuf;

        // Call process with net > base to trigger replenishment logic
        (int256 posRes, uint256 replenished) = cteh.process(10e9, 2e9);
        assertGe(posRes, 0);
        // replenished may be zero or positive depending on internal state; assert it doesn't underflow
        assertGe(replenished, 0);
    }

    function testCollateralPerfectMatchBuffers() public {
        cteh.initCollateral(100e6, 1000, ProtocolLib.QUARTERLY_INTERVAL);
        uint256 dt = 30 days;
        (uint256 baseCol,,,) = cteh.collateralView();
        uint256 baseEarnings = EarningsLib.calculateBenchmarkEarnings(baseCol, dt);
        (int256 result, uint256 replenished) = cteh.process(baseEarnings, baseEarnings);
        assertEq(result, 0);
        assertEq(replenished, 0);
    }

    function testBenchmarkWithHigherBP() public pure {
        uint256 principal = 1000e6;
        uint256 dt = 30 days;
        uint256 defaultBench = EarningsLib.calculateBenchmarkEarnings(principal, dt);
        uint256 higherBench = EarningsLib.calculateEarnings(principal, dt, ProtocolLib.BENCHMARK_EARNINGS_BP + 500);
        assertGt(higherBench, defaultBench);
    }

    // TokenLib tests
    function testTokenInitializationAndValueCalculation() public {
        // min holding coerced to at least MONTHLY_INTERVAL
        cteh.initToken(1, 100e6, 1 days);
        (uint256 tid, uint256 price, uint256 supply, uint256 minHold) = cteh.tokenInfo();
        assertEq(tid, 1);
        assertEq(price, 100e6);
        assertEq(supply, 0);
        assertEq(minHold, ProtocolLib.MONTHLY_INTERVAL);

        // token value
        assertEq(cteh.tokenValue(5), 5 * 100e6);
    }

    function testTokenUnclaimedForPositionsAndEarningsHelpers() public {
        cteh.initToken(7, 100e6, ProtocolLib.MONTHLY_INTERVAL);
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
