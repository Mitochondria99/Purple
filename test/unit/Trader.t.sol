// SPDX-License-Identifier: MIT

// Need to connect to Mock price feed
// Getting a Division and modulo error
//
pragma solidity ^0.8.19;
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "forge-std/Test.sol";
import "src/Trader.sol";
import "src/LiquidityVault.sol";
import "src/PriceFeed.sol";
import "../mock/MockERC20.sol";

contract TraderContractTest is Test {

    address user2 = address(100);

    uint256 USERS_MINT = 100000 ether;

    address public alice = address(3000);
    TraderContract trader;
    LiquidityVault public liquidityVault;
    PriceFeed public priceFeed;
    //PriceFeedConsumer public priceFeedConsumer;
    MockERC20 public asset;

     function setUp() public {
       liquidityVault = new LiquidityVault(asset, "Liquidity Vault", "LV", address(trader));
       //priceFeedConsumer= new PriceFeedConsumer();
        priceFeed = new PriceFeed();
        asset = new MockERC20("Token", "blc");
        trader = new TraderContract(address(liquidityVault), address(priceFeed), asset);

        alice = address(1);

    }

    function testDepositCollateral() public {

        uint256 mintAmount = 1000;
        asset.mint(address(this), mintAmount);
        console.log("Balance after mint: %s", asset.balanceOf(address(this)));

        asset.approve(address(trader), mintAmount);
        console.log("Allowance after approve: %s", asset.allowance(address(this), address(trader)));

        uint256 validAmount = 100;
        
        trader.depositCollateral(validAmount);
        vm.startPrank(alice);
        console.log("Balance after deposit: %s", asset.balanceOf(address(this)));
    
        
        uint256 invalidAmount = 0;
        if(invalidAmount > 0){
        vm.expectRevert();
        trader.depositCollateral(invalidAmount);
         vm.stopPrank();
        }
        
    }

   function testIncreaseCollateral() public {
    uint256 mintAmount = 3000;
    asset.mint(address(this), mintAmount);
    console.log("Balance after mint: %s", asset.balanceOf(address(this)));

    // Transfer tokens to Alice's account
    asset.transfer(alice, mintAmount);
    console.log("Balance of Alice after transfer: %s", asset.balanceOf(alice));

    vm.startPrank(alice);
    asset.approve(address(trader), mintAmount);
    
    console.log("Allowance after approve: %s", asset.allowance(address(this), address(trader)));
    console.log("Balance of Alice before increaseCollateral: %s", asset.balanceOf(alice));

    trader.increaseCollateral(100);

    console.log("Balance of Alice after increaseCollateral: %s", asset.balanceOf(alice));
    console.log("Allowance of Alice after increaseCollateral: %s", asset.allowance(address(this), address(trader)));

    vm.stopPrank();
}

function testOpenPosition() public {
    uint256 mintAmount = 3000;
    asset.mint(address(this), mintAmount);
    console.log("Balance after mint: %s", asset.balanceOf(address(this)));

    // Transfer tokens to Alice's account
    asset.transfer(alice, mintAmount);
    console.log("Balance of Alice after transfer: %s", asset.balanceOf(alice));

    vm.startPrank(alice);
    asset.approve(address(trader), mintAmount);
    asset.approve(address(this), mintAmount);
    
    console.log("Allowance after approve: %s", asset.allowance(address(this), address(trader)));
    console.log("Collateral of Alice before openPosition: %s", trader.collaterals(alice));

    uint256 size = 100;
    TraderContract.PositionType positionType = TraderContract.PositionType.LONG; 
    uint256 positionId = trader.openPosition(size, positionType);

    console.log("Collateral of Alice after openPosition: %s", trader.collaterals(alice));
    console.log("Allowance of Alice after openPosition: %s", asset.allowance(address(this), address(trader)));

    // Check if a new position has been opened and the collateral decreased by size
    assertEq(trader.collaterals(alice), mintAmount - size);

    // Check if the position id returned by openPosition is correct
    assertEq(positionId, 1);

    // check if the pricefeed.getprice() function returns a non-zero value
   // uint256 currentprice = PriceFeedConsumer.getLatestPrice();

    vm.stopPrank();
}

}

