// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "remix_tests.sol";
import "../contracts/SecurityToken.sol";
import "../contracts/SecuritiesMarket.sol";
import "./TestActors.sol";

contract SecuritiesMarketTest {
    SecurityToken token;
    SecuritiesMarket market;
    Actor seller;
    Actor buyer;

    uint256 constant DECIMALS = 18;

    // Allow this test contract to receive ETH from the runner
    receive() external payable {}

    function beforeAll() public {
        token = new SecurityToken("Security", "SEC", uint8(DECIMALS), 0);
        market = new SecuritiesMarket();
        seller = new Actor();
        buyer  = new Actor();

        // Mint tokens to seller (this test contract is token owner)
        token.mint(address(seller), 1_000 * 10**DECIMALS);
    }

    /// #value: 3000000000000000000   (3 ether)
    function testListAndBuyFlow() public payable {
        uint256 amount = 200 * 10**DECIMALS;
        uint256 price  = 1 ether;

        // Sanity: ensure this test function actually got ETH from the directive
        Assert.ok(address(this).balance >= price, "test has no ETH");

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

        // Fund buyer from THIS test contract
        (bool sent, ) = payable(address(buyer)).call{value: price}("");
        Assert.ok(sent, "funding buyer failed");
        Assert.equal(buyer.selfBalance(), price, "buyer not funded correctly");

        uint256 sellerEthBefore = seller.selfBalance();
        uint256 buyerTokBefore  = token.balanceOf(address(buyer));

        // Buyer pays from its own balance
        buyer.buy(address(market), id, price);

        // Post-conditions
        (, , , , bool activeAfter) = market.listings(id);
        Assert.ok(!activeAfter, "listing must be inactive after buy");
        Assert.equal(token.balanceOf(address(buyer)), buyerTokBefore + amount, "buyer must receive tokens");

        uint256 sellerEthAfter = seller.selfBalance();
        Assert.equal(sellerEthAfter, sellerEthBefore + price, "seller must receive ETH");
    }

    /// #value: 2000000000000000000   (2 ether)
    function testBuyWithWrongEthReverts() public payable {
        uint256 amount = 50 * 10**DECIMALS;
        uint256 price  = 1.5 ether;

        Assert.ok(address(this).balance >= 1 ether, "test has no ETH");

        // prepare new listing
        bool okAppr = seller.approveToken(address(token), address(market), amount);
        Assert.ok(okAppr, "approve failed");
        uint256 id = seller.list(address(market), address(token), amount, price);

        // Fund buyer with only 1 ether
        (bool sent2, ) = payable(address(buyer)).call{value: 1 ether}("");
        Assert.ok(sent2, "fund buyer failed");
        Assert.equal(buyer.selfBalance(), 1 ether, "buyer funding mismatch");

        // attempt buy with wrong ETH → should revert (ok == false)
        bool ok = buyer.tryBuy(address(market), id, 1 ether);
        Assert.ok(!ok, "buy should revert when ETH is wrong");

        // cancel and ensure tokens return to seller
        seller.cancel(address(market), id);
        Assert.equal(
            token.balanceOf(address(seller)),
            800 * 10**DECIMALS,  // 1000 - 200 sold in first test; after cancel returns to 800
            "seller should get tokens back after cancel"
        );
    }
}