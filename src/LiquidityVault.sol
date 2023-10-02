//check ERC4626 thoroughly
// ReserveLiquidity issue to be corrected

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ITrader {
    function totalOpenInterest() external view returns (uint256);

    function maxUtilizationPercentage() external view returns (uint256);
}

contract LiquidityVault is ERC4626, Ownable {
    IERC20 private _asset;
    ITrader private trader;

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(
        IERC20 assetToken,
        string memory name,
        string memory symbol,
        address traderAddress
    ) ERC4626(assetToken) ERC20(name, symbol) {
        _asset = assetToken;
        trader = ITrader(traderAddress);
    }

    function setTraderAddress(address newTraderAddress) external onlyOwner {
        trader = ITrader(newTraderAddress);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Deposit amount should be > 0");
        _asset.transferFrom(msg.sender, address(this), amount);
        uint256 sharesToMint = previewDeposit(amount);
        _mint(msg.sender, sharesToMint);
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 shares) external {
        require(shares > 0, "Withdrawal shares should be > 0");
        require(balanceOf(msg.sender) >= shares, "Insufficient shares");

        uint256 assetsToReturn = previewWithdraw(shares);

        // Utilization check
        uint256 openInterest = trader.totalOpenInterest();
        require(
            (openInterest * 100) / (totalAssets() - assetsToReturn) <=
                trader.maxUtilizationPercentage(),
            "Exceeds max utilization"
        );

        _burn(msg.sender, shares);
        _asset.transfer(msg.sender, assetsToReturn);
        emit Withdrawn(msg.sender, assetsToReturn);
    }

    function totalAssets() public view override returns (uint256) {
        return _asset.balanceOf(address(this));
    }
}
