//check authorization test video
// consider priceFeed

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../../src/LiquidityVault.sol";
import "src/Trader.sol";
import "../mock/MockERC20.sol";

contract LiquidityVaultTest is Test {
     TraderContract trader;
    LiquidityVault vault;
    MockERC20 public asset;
    //address alice;
    address bob;
    address public alice = address(1);

    function setUp() public {
       asset = new MockERC20("Token", "blc");
        vault = new LiquidityVault(asset, "Liquidity Vault", "LV", address(trader));
        alice = makeAddr("alice");
        bob = makeAddr("bob");
    }

   function testDeposit() public {
    
}
}