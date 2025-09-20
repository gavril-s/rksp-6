// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// Minimal ERC20 interface for tests
interface IERC20Test {
    function approve(address spender, uint256 value) external returns (bool);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/// Minimal market interface
interface IMarketTest {
    function list(address token, uint256 amount, uint256 priceWei) external returns (uint256);
    function cancel(uint256 id) external;
    function buy(uint256 id) external payable;
}

/// Minimal swap interface
interface ISwapTest {
    function swap(
        address tokenA,
        address tokenB,
        address partyA,
        address partyB,
        uint256 amountA,
        uint256 amountB,
        uint64 deadline
    ) external;
}

/// @title Actor — helper to simulate distinct users (seller/buyer/parties)
contract Actor {
    receive() external payable {}

    // --- ERC20 helpers ---
    function approveToken(address token, address spender, uint256 amount) external returns (bool) {
        return IERC20Test(token).approve(spender, amount);
    }

    function callTransferFrom(address token, address from, address to, uint256 amount) external returns (bool ok) {
        (ok, ) = token.call(abi.encodeWithSignature("transferFrom(address,address,uint256)", from, to, amount));
    }

    // --- Market helpers ---
    function list(address market, address token, uint256 amount, uint256 priceWei) external returns (uint256) {
        return IMarketTest(market).list(token, amount, priceWei);
    }

    function cancel(address market, uint256 id) external {
        IMarketTest(market).cancel(id);
    }

    function buy(address market, uint256 id, uint256 priceWei) external payable {
        require(msg.value == priceWei, "bad value");
        IMarketTest(market).buy{value: priceWei}(id);
    }

    function tryBuy(address market, uint256 id, uint256 priceWei) external payable returns (bool ok) {
        // low-level call to capture revert
        (ok, ) = market.call{value: priceWei}(abi.encodeWithSignature("buy(uint256)", id));
    }

    // --- Swap helpers ---
    function callSwap(
        address swap,
        address tokenA,
        address tokenB,
        address partyA,
        address partyB,
        uint256 amountA,
        uint256 amountB,
        uint64 deadline
    ) external {
        ISwapTest(swap).swap(tokenA, tokenB, partyA, partyB, amountA, amountB, deadline);
    }

    function trySwap(
        address swap,
        address tokenA,
        address tokenB,
        address partyA,
        address partyB,
        uint256 amountA,
        uint256 amountB,
        uint64 deadline
    ) external returns (bool ok) {
        (ok, ) = swap.call(abi.encodeWithSignature(
            "swap(address,address,address,address,uint256,uint256,uint64)",
            tokenA, tokenB, partyA, partyB, amountA, amountB, deadline
        ));
    }

    // --- Views ---
    function selfBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function tokenBalance(address token) external view returns (uint256) {
        return IERC20Test(token).balanceOf(address(this));
    }

    // --- Owner-only test for SecurityToken.mint via non-owner (should revert) ---
    function tryMint(address token, address to, uint256 amount) external returns (bool ok) {
        (ok, ) = token.call(abi.encodeWithSignature("mint(address,uint256)", to, amount));
    }
}