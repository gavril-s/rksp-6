// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "remix_tests.sol";
import "./SecurityToken.sol";
import "./SecuritiesMarket.sol";
import "./TestActors.sol";

contract SecuritiesMarketTest {
    SecurityToken token;
    SecuritiesMarket market;
    Actor seller;
    Actor buyer;

    uint256 constant DECIMALS = 18;

    // Allow this test contract to fund actors
    receive() external payable {}

    function beforeAll() public {
        token = new SecurityToken("Security", "SEC", uint8(DECIMALS), 0);
        market = new SecuritiesMarket();
        seller = new Actor();
        buyer  = new Actor();

        // Mint tokens to seller (test contract is owner)
        token.mint(address(seller), 1_000 * 10**DECIMALS);
    }

    function testListAndBuyFlow() public {
        uint256 amount = 200 * 10**DECIMALS;
        uint256 price  = 1 ether;

        // Seller approves market & lists
        bool okAppr = seller.approveToken(address(token), address(market), amount);
        Assert.ok(okAppr, "approve failed");

        uint256 id = seller.list(address(market), address(token), amount, price);
        Assert.ok(id > 0, "listing id should be > 0");

        // Check listing state & escrow
        (address s, address t, uint256 amt, uint256 p, bool active) = market.listings(id);
        Assert.equal(s, address(seller), "seller mismatch");
        Assert.equal(t, address(token), "token mismatch");
        Assert.equal(amt, amount, "amount mismatch");
        Assert.equal(p, price, "price mismatch");
        Assert.ok(active, "listing should be active");
        Assert.equal(token.balanceOf(address(market)), amount, "market should hold escrowed tokens");

        // Fund buyer and purchase
        (bool sent, ) = address(buyer).call{value: price}("");
        Assert.ok(sent, "funding buyer failed");

        uint256 sellerEthBefore = seller.selfBalance();
        uint256 buyerTokBefore  = token.balanceOf(address(buyer));

        buyer.buy{value: price}(address(market), id, price);

        // Post-conditions
        (, , , , bool activeAfter) = market.listings(id);
        Assert.ok(!activeAfter, "listing must be inactive after buy");

        Assert.equal(token.balanceOf(address(buyer)), buyerTokBefore + amount, "buyer must receive tokens");

        uint256 sellerEthAfter = seller.selfBalance();
        Assert.equal(sellerEthAfter, sellerEthBefore + price, "seller must receive ETH");
    }

    function testBuyWithWrongEthReverts() public {
        uint256 amount = 50 * 10**DECIMALS;
        uint256 price  = 1.5 ether;

        // prepare new listing
        bool okAppr = seller.approveToken(address(token), address(market), amount);
        Assert.ok(okAppr, "approve failed");
        uint256 id = seller.list(address(market), address(token), amount, price);

        // Fund buyer with only 1 ether
        (bool sent, ) = address(buyer).call{value: 1 ether}("");
        Assert.ok(sent, "fund buyer failed");

        bool ok = buyer.tryBuy{value: 1 ether}(address(market), id, 1 ether);
        Assert.ok(!ok, "buy should revert when ETH is wrong");

        // cancel and ensure tokens return to seller
        seller.cancel(address(market), id);
        Assert.equal(token.balanceOf(address(seller)), (1_000 - 200)*10**DECIMALS + 50*10**DECIMALS, "seller should get tokens back after cancel");
    }
}