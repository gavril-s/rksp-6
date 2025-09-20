// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20Minimal {
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
}

/// @title SecuritiesSwap — атомарный обмен токенами между двумя держателями
/// @notice Обе стороны заранее делают approve на этот контракт; затем любой из них вызывает swap
contract SecuritiesSwap {
    // --- ReentrancyGuard (минимальная реализация) ---
    uint256 private _status = 1;
    modifier nonReentrant() {
        require(_status != 2, "REENTRANCY");
        _status = 2;
        _;
        _status = 1;
    }

    event Swapped(
        address indexed partyA,
        address indexed partyB,
        address indexed tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB
    );

    error DeadlineExpired();
    error NotParticipant();
    error InsufficientAllowance();
    error InsufficientBalance();

    /// @param tokenA адрес токена, который отдаёт partyA и получает partyB
    /// @param tokenB адрес токена, который отдаёт partyB и получает partyA
    /// @param partyA участник A
    /// @param partyB участник B
    /// @param amountA количество токена A (минимальные единицы), которое отдаёт A
    /// @param amountB количество токена B (минимальные единицы), которое отдаёт B
    /// @param deadline unix-время, после которого обмен невозможен (0 = без ограничения)
    function swap(
        address tokenA,
        address tokenB,
        address partyA,
        address partyB,
        uint256 amountA,
        uint256 amountB,
        uint64 deadline
    ) external nonReentrant {
        if (deadline != 0 && block.timestamp > deadline) revert DeadlineExpired();
        if (msg.sender != partyA && msg.sender != partyB) revert NotParticipant();

        IERC20Minimal ta = IERC20Minimal(tokenA);
        IERC20Minimal tb = IERC20Minimal(tokenB);

        // Проверки балансов и разрешений (gas-friendly, но достаточные для учебной модели)
        if (ta.allowance(partyA, address(this)) < amountA) revert InsufficientAllowance();
        if (tb.allowance(partyB, address(this)) < amountB) revert InsufficientAllowance();
        if (ta.balanceOf(partyA) < amountA) revert InsufficientBalance();
        if (tb.balanceOf(partyB) < amountB) revert InsufficientBalance();

        // 1) Переводим A -> B
        bool ok1 = ta.transferFrom(partyA, partyB, amountA);
        require(ok1, "TRANSFER_A_FAILED");

        // 2) Переводим B -> A
        bool ok2 = tb.transferFrom(partyB, partyA, amountB);
        require(ok2, "TRANSFER_B_FAILED");

        emit Swapped(partyA, partyB, tokenA, tokenB, amountA, amountB);
    }
}