// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "remix_tests.sol"; // Remix asserts
import "./SecurityToken.sol";
import "./TestActors.sol";

contract SecurityTokenTest {
    SecurityToken token;
    Actor a1;
    Actor a2;

    uint256 constant DECIMALS = 18;
    uint256 constant INITIAL = 1_000 * 10**DECIMALS;

    function beforeAll() public {
        token = new SecurityToken("Security", "SEC", uint8(DECIMALS), INITIAL);
        a1 = new Actor();
        a2 = new Actor();
    }

    function testInitialState() public {
        Assert.equal(token.name(), "Security", "name mismatch");
        Assert.equal(token.symbol(), "SEC", "symbol mismatch");
        Assert.equal(uint256(token.decimals()), DECIMALS, "decimals mismatch");
        Assert.equal(token.totalSupply(), INITIAL, "total supply mismatch");
        Assert.equal(token.balanceOf(address(this)), INITIAL, "owner should hold initial supply");
        Assert.equal(token.owner(), address(this), "owner should be test contract");
    }

    function testTransfer() public {
        uint256 amount = 100 * 10**DECIMALS;
        uint256 balBeforeSender = token.balanceOf(address(this));
        bool ok = token.transfer(address(a1), amount);
        Assert.ok(ok, "transfer failed");
        Assert.equal(token.balanceOf(address(a1)), amount, "a1 should receive tokens");
        Assert.equal(token.balanceOf(address(this)), balBeforeSender - amount, "sender balance decreased");
    }

    function testApproveAndTransferFrom() public {
        uint256 amount = 50 * 10**DECIMALS;
        bool ok1 = token.approve(address(a1), amount);
        Assert.ok(ok1, "approve failed");

        // a1 pulls tokens from this contract and sends to a2
        bool ok2 = a1.callTransferFrom(address(token), address(this), address(a2), amount);
        Assert.ok(ok2, "transferFrom call failed");

        Assert.equal(token.balanceOf(address(a2)), amount, "a2 should receive tokens");
    }

    function testOnlyOwnerMintRevertsForNonOwner() public {
        // a1 (non-owner) attempts to mint — must fail
        bool ok = a1.tryMint(address(token), address(a1), 1);
        Assert.ok(!ok, "non-owner mint should revert");
    }

    function testOwnerCanMint() public {
        uint256 addSupply = 123 * 10**DECIMALS;
        uint256 tsBefore = token.totalSupply();
        token.mint(address(a1), addSupply);
        Assert.equal(token.totalSupply(), tsBefore + addSupply, "totalSupply must increase");
        Assert.equal(token.balanceOf(address(a1)), (100 + 123) * 10**DECIMALS, "a1 balance incorrect after mint"); // 100 from earlier + 123 now
    }
}