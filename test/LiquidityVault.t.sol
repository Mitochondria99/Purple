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

    function test_Deposit() public {
        uint256 depositAmount = 100 ether;
        mockToken.mint(address(this), depositAmount);
        mockToken.transfer(alice, depositAmount);

        vm.prank(alice);
        mockToken.transferFrom(address(this), address(vault), depositAmount);
        vault.deposit(depositAmount);
        //  assertEq(vault.balanceOf(alice) > 0, "Alice receive vault tokens");
    }

    function test_Withdraw() public {
        uint256 depositAmount = 100 ether;
        uint256 withdrawShares = 50 ether; // Assuming 1:1 conversion for simplicity

        mockToken.mint(address(this), depositAmount);
        mockToken.transfer(bob, depositAmount);

        vm.prank(bob);
        mockToken.transferFrom(address(this), address(vault), depositAmount);
        vault.deposit(depositAmount);
        uint256 bobStartingBalance = mockToken.balanceOf(bob);
        vault.withdraw(withdrawShares);
        assertEq(
            mockToken.balanceOf(bob) > bobStartingBalance,
            "Bob should have more MockToken after withdrawal"
        );
    }

    function test_Release() public {
        uint256 reserveAmount = 50 ether;
        vault.authorizedAddresses(address(this)) = true;
        vault.reserve(reserveAmount);

        uint256 initialReservedLiquidity = vault.reservedLiquidity();
        vault.release(reserveAmount);
        assertEq(
            vault.reservedLiquidity() < initialReservedLiquidity,
            "Reserved liquidity should decrease after release"
        );
    }

    function test_Reserve() public {
        uint256 reserveAmount = 50 ether;
        vault.authorizedAddresses(address(this)) = true;
        uint256 initialReservedLiquidity = vault.reservedLiquidity();
        vault.reserve(reserveAmount);
        assertEq(
            vault.reservedLiquidity() > initialReservedLiquidity,
            "Reserved liquidity should increase after reserve"
        );
    }
}
