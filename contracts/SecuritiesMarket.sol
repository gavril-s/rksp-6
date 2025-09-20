// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Минимальный интерфейс ERC20, достаточный для маркетплейса
interface IERC20 {
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

/// @title SecuritiesMarket — простой маркетплейс лотов за ETH с эскроу токенов
/// @dev Продавец депонирует токены (transferFrom), покупатель платит ETH; сделка атомарна
contract SecuritiesMarket {
    // --- ReentrancyGuard (минимальная реализация) ---
    uint256 private _status;
    modifier nonReentrant() {
        require(_status != 2, "REENTRANCY");
        _status = 2;
        _;
        _status = 1;
    }

    constructor() {
        _status = 1;
    }

    struct Listing {
        address seller;      // владелец лота
        address token;       // адрес ERC20 (SecurityToken)
        uint256 amount;      // количество токенов (в минимальных единицах)
        uint256 priceWei;    // общая цена лота в wei (фикс)
        bool active;         // признак активности
    }

    uint256 public nextId;
    mapping(uint256 => Listing) public listings;

    // --- События ---
    event Listed(uint256 indexed id, address indexed seller, address indexed token, uint256 amount, uint256 priceWei);
    event Cancelled(uint256 indexed id);
    event Purchased(uint256 indexed id, address indexed buyer);

    // --- Ошибки ---
    error NotSeller();
    error NotActive();
    error WrongEth();
    error TransferFailed();
    error ZeroAmount();
    error ZeroPrice();

    /// @notice Создать лот: токены переводятся на контракт (нужен approve на amount)
    function list(address token, uint256 amount, uint256 priceWei) external nonReentrant returns (uint256 id) {
        if (amount == 0) revert ZeroAmount();
        if (priceWei == 0) revert ZeroPrice();

        // Перевод токенов в эскроу
        bool ok = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!ok) revert TransferFailed();

        id = ++nextId;
        listings[id] = Listing({
            seller: msg.sender,
            token: token,
            amount: amount,
            priceWei: priceWei,
            active: true
        });

        emit Listed(id, msg.sender, token, amount, priceWei);
    }

    /// @notice Снять лот с продажи и вернуть токены продавцу
    function cancel(uint256 id) external nonReentrant {
        Listing storage L = listings[id];
        if (!L.active) revert NotActive();
        if (msg.sender != L.seller) revert NotSeller();

        L.active = false;

        bool ok = IERC20(L.token).transfer(L.seller, L.amount);
        if (!ok) revert TransferFailed();

        emit Cancelled(id);
    }

    /// @notice Купить активный лот, оплатив точную сумму ETH
    function buy(uint256 id) external payable nonReentrant {
        Listing storage L = listings[id];
        if (!L.active) revert NotActive();
        if (msg.value != L.priceWei) revert WrongEth();

        L.active = false; // эффект до взаимодействий

        // 1) Отправляем токены покупателю (если revert — вся транзакция откатится)
        bool okToken = IERC20(L.token).transfer(msg.sender, L.amount);
        if (!okToken) revert TransferFailed();

        // 2) Переводим ETH продавцу
        (bool okEth, ) = L.seller.call{value: L.priceWei}("");
        require(okEth, "ETH_TRANSFER_FAILED");

        emit Purchased(id, msg.sender);
    }
}