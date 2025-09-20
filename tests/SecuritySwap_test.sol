// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "remix_tests.sol";
import "../contracts/SecurityToken.sol";
import "../contracts/SecuritiesSwap.sol";
import "./TestActors.sol";

contract SecuritiesSwapTest {
    SecurityToken tokenA;
    SecurityToken tokenB;
    SecuritiesSwap swapper;
    Actor A;
    Actor B;

    uint256 constant DECIMALS = 18;

    function beforeAll() public {
        tokenA = new SecurityToken("Alpha", "ALP", uint8(DECIMALS), 0);
        tokenB = new SecurityToken("Beta",  "BET", uint8(DECIMALS), 0);
        swapper = new SecuritiesSwap();
        A = new Actor();
        B = new Actor();

        // Mint supplies to each party
        tokenA.mint(address(A), 1_000 * 10**DECIMALS);
        tokenB.mint(address(B), 2_000 * 10**DECIMALS);
    }

    function testHappyPathSwap() public {
        uint256 amountA = 100 * 10**DECIMALS; // A gives
        uint256 amountB = 200 * 10**DECIMALS; // B gives

        // Approvals
        bool ok1 = A.approveToken(address(tokenA), address(swapper), amountA);
        bool ok2 = B.approveToken(address(tokenB), address(swapper), amountB);
        Assert.ok(ok1 && ok2, "approvals failed");

        uint64 deadline = uint64(block.timestamp + 1 days);

        uint256 aBalA_before = tokenA.balanceOf(address(A));
        uint256 aBalB_before = tokenB.balanceOf(address(A));
        uint256 bBalA_before = tokenA.balanceOf(address(B));
        uint256 bBalB_before = tokenB.balanceOf(address(B));

        // Either party can call; let A initiate
        A.callSwap(
            address(swapper),
            address(tokenA),
            address(tokenB),
            address(A),
            address(B),
            amountA,
            amountB,
            deadline
        );

        // Post-swap balances
        Assert.equal(tokenA.balanceOf(address(A)), aBalA_before - amountA, "A tokenA down");
        Assert.equal(tokenB.balanceOf(address(A)), aBalB_before + amountB, "A tokenB up");
        Assert.equal(tokenA.balanceOf(address(B)), bBalA_before + amountA, "B tokenA up");
        Assert.equal(tokenB.balanceOf(address(B)), bBalB_before - amountB, "B tokenB down");
    }

    function testDeadlineExpiredReverts() public {
        // fresh approvals for a new small swap
        bool ok1 = A.approveToken(address(tokenA), address(swapper), 1 * 10**DECIMALS);
        bool ok2 = B.approveToken(address(tokenB), address(swapper), 1 * 10**DECIMALS);
        Assert.ok(ok1 && ok2, "approvals failed");

        uint64 past = uint64(block.timestamp - 1); // already expired
        bool ok = A.trySwap(
            address(swapper),
            address(tokenA),
            address(tokenB),
            address(A),
            address(B),
            1 * 10**DECIMALS,
            1 * 10**DECIMALS,
            past
        );
        Assert.ok(!ok, "swap should revert when deadline expired");
    }

    function testInsufficientAllowanceReverts() public {
        // A approves less than required
        bool ok1 = A.approveToken(address(tokenA), address(swapper), 5 * 10**DECIMALS);
        bool ok2 = B.approveToken(address(tokenB), address(swapper), 5 * 10**DECIMALS);
        Assert.ok(ok1 && ok2, "approvals failed");

        bool ok = B.trySwap(
            address(swapper),
            address(tokenA),
            address(tokenB),
            address(A),
            address(B),
            10 * 10**DECIMALS, // requires more than approved
            10 * 10**DECIMALS,
            uint64(block.timestamp + 1 days)
        );
        Assert.ok(!ok, "swap should revert with insufficient allowance");
    }
}