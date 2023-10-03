//check ERC4626 thoroughly

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
    address payable public vaultOwner;
    IERC20 private _asset;
    ITrader private trader;
    uint256 public penaltyFeeBasisPoints; // penalty applied on providing unneccesary liquidity

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(
        IERC20 assetToken,
        uint256 _basisPoints,
        string memory name,
        string memory symbol,
        address traderAddress
    ) ERC4626(assetToken) ERC20(name, symbol) {
        _asset = assetToken;
        vaultOwner = payable(msg.sender);
        trader = ITrader(traderAddress);
        penaltyFeeBasisPoints = _basisPoints;
    }

    function setTraderAddress(address newTraderAddress) external onlyOwner {
        trader = ITrader(newTraderAddress);
    }

    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override returns (uint256) {
        require(
            assets <= maxDeposit(receiver),
            "ERC4626: deposit more than max"
        );

        uint256 shares = previewDeposit(assets);
        _deposit(_msgSender(), receiver, assets, shares);
        afterDeposit(assets, shares);

        return shares;
    }

    function mint(
        uint256 shares,
        address receiver
    ) public virtual override returns (uint256) {
        require(shares <= maxMint(receiver), "ERC4626: mint more than max");

        uint256 assets = previewMint(shares);
        _deposit(_msgSender(), receiver, assets, shares);
        afterDeposit(assets, shares);

        return assets;
    }

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(shares <= maxRedeem(owner), "ERC4626: redeem more than max");

        uint256 assets = previewRedeem(shares);
        beforeWithdraw(assets, shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public virtual override returns (uint256) {
        require(
            assets <= maxWithdraw(owner),
            "ERC4626: withdraw more than max"
        );

        uint256 shares = previewWithdraw(assets);
        beforeWithdraw(assets, shares);
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    function _penaltyFeeBasisPoints() internal view returns (uint256) {
        return penaltyFeeBasisPoints;
    }

    function _penaltyFeeRecipient() internal view returns (address) {
        return vaultOwner;
    }

    function afterDeposit(uint256 assets, uint256 shares) internal virtual {}

    function beforeWithdraw(uint256 assets, uint256 shares) internal virtual {}
}
