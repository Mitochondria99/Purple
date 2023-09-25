//check authorization test video
// consider priceFeed

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src//LiquidityVault.sol";
import "./mock/MockERC20.sol";

contract LiquidityVaultTest is Test {
    LiquidityVault vault;
    MockERC20 mockToken;
    address alice;
    address bob;

    function setUp() public {
        mockToken = new MockERC20("FakeToken", "FT");
        vault = new LiquidityVault(mockToken, "VaultToken", "VT");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
    }
}
