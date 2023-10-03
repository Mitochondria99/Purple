// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import 'src/TraderContract.sol';
import "src/LiquidityVault.sol";
import "src/PriceFeed.sol";
import "../mock/MockERC20.sol";

contract TraderContractTest is Test {
    TraderContract trader;
    LiquidityVault public liquidityVault;
    PriceFeed public priceFeed;
    MockERC20 public asset;

     function setUp() public {
       liquidityVault = new LiquidityVault(asset, "Liquidity Vault", "LV", address(trader));
        priceFeed = new PriceFeed();
        asset = new MockERC20("Token", "blc");
        trader = new TraderContract(address(liquidityVault), address(priceFeed), asset);
    }

    function testDepositCollateral() public {
        uint256 mintAmount = 1000;
        asset.mint(address(this), mintAmount);
        console.log("Balance after mint: %s", asset.balanceOf(address(this)));

        asset.approve(address(trader), mintAmount);
        console.log("Allowance after approve: %s", asset.allowance(address(this), address(trader)));

        uint256 validAmount = 100;
        trader.depositCollateral(validAmount);
        console.log("Balance after deposit: %s", asset.balanceOf(address(this)));
        uint256 collateralBalance = trader.collaterals(msg.sender);
        console.log("Collateral balance after deposit: %s", collateralBalance);
        assertEq(collateralBalance, validAmount);
        //assertEq(trader.collaterals(msg.sender), validAmount);

        uint256 invalidAmount = 0;
        if(invalidAmount > 0){
        vm.expectRevert();
        trader.depositCollateral(invalidAmount);
        }
        
    }

   function testIncreaseCollateral() public {
    uint256 mintAmount = 1000;
    asset.mint(address(this), mintAmount);
    console.log("Balance after mint: %s", asset.balanceOf(address(this)));

    asset.approve(address(trader), mintAmount);
    console.log("Allowance after approve: %s", asset.allowance(address(this), address(trader)));

    uint256 initialCollateral = trader.collaterals(msg.sender);
    console.log("Initial Collateral: %s", initialCollateral);
    console.log("Amount to increase: %s", 100);

    trader.increaseCollateral(100);
    uint256 newCollateral = trader.collaterals(msg.sender);
    console.log("New Collateral: %s", newCollateral);

    assertEq(newCollateral, initialCollateral + 100);
}

}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import 'src/TraderContract.sol';
import "src/LiquidityVault.sol";
import "src/PriceFeed.sol";
import "../mock/MockERC20.sol";

contract TraderContractTest is Test {
    TraderContract trader;
    LiquidityVault public liquidityVault;
    PriceFeed public priceFeed;
    MockERC20 public asset;

     function setUp() public {
       liquidityVault = new LiquidityVault(asset, "Liquidity Vault", "LV", address(trader));
        priceFeed = new PriceFeed();
        asset = new MockERC20("Token", "bvv");
        trader = new TraderContract(address(liquidityVault), address(priceFeed), asset);
    }

    function testDepositCollateral() public {
        uint256 mintAmount = 1000;
        asset.mint(address(this), mintAmount);
        console.log("Balance after mint: %s", asset.balanceOf(address(this)));

        asset.approve(address(trader), mintAmount);
        console.log("Allowance after approve: %s", asset.allowance(address(this), address(trader)));

        uint256 validAmount = 100;
        trader.depositCollateral(validAmount);
        console.log("Balance after deposit: %s", asset.balanceOf(address(this)));
        uint256 collateralBalance = trader.collaterals(msg.sender);
        console.log("Collateral balance after deposit: %s", collateralBalance);
        assertEq(collateralBalance, validAmount);
        //assertEq(trader.collaterals(msg.sender), validAmount);

        uint256 invalidAmount = 0;
        if(invalidAmount > 0){
        vm.expectRevert();
        trader.depositCollateral(invalidAmount);
        }
        
    }

   function testIncreaseCollateral() public {
    uint256 mintAmount = 1000;
    asset.mint(address(this), mintAmount);
    console.log("Balance after mint: %s", asset.balanceOf(address(this)));

    asset.approve(address(trader), mintAmount);
    console.log("Allowance after approve: %s", asset.allowance(address(this), address(trader)));

    uint256 initialCollateral = trader.collaterals(msg.sender);
    console.log("Initial Collateral: %s", initialCollateral);
    console.log("Amount to increase: %s", 100);

    trader.increaseCollateral(100);
    uint256 newCollateral = trader.collaterals(msg.sender);
    console.log("New Collateral: %s", newCollateral);

    assertEq(newCollateral, initialCollateral + 100);
}

}
