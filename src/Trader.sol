// Hella confused with values, need to check this again
// doubting closePosition func
// consideration of leverage?// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LiquidityVault.sol";
import "./PriceFeed.sol";

contract TraderContract is Ownable {
    IERC20 private _asset; // The collateral and trading asset
    LiquidityVault public liquidityVault;
    PriceFeed public priceFeed;

    uint256 private _totalOpenInterest;
    uint256 public maxUtilizationPercentage = 80; // 80% max utilization of total liquidity

    enum PositionType {
        LONG,
        SHORT
    }

    struct Position {
        uint256 size;
        PositionType positionType;
        bool isOpen;
        uint256 sizeInTokens;
    }

    mapping(address => uint256) public collaterals;
    mapping(address => Position) public positions;

    event CollateralDeposited(address indexed trader, uint256 amount);
    event CollateralIncreased(
        address indexed trader,
        uint256 newCollateralAmount
    );
    event PositionOpened(
        address indexed trader,
        uint256 size,
        PositionType positionType
    );
    event PositionIncreased(address indexed trader, uint256 newSize);
    event PositionClosed(address indexed trader);

    constructor(address _liquidityVault, address _priceFeed, IERC20 asset) {
        liquidityVault = LiquidityVault(_liquidityVault);
        priceFeed = PriceFeed(_priceFeed);
        _asset = asset;
    }

    function depositCollateral(uint256 amount) external {
        require(amount > 0, "Amount should be greater than 0");
        _asset.transferFrom(msg.sender, address(this), amount);
        collaterals[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount);
    }

    function increaseCollateral(uint256 additionalAmount) external {
        require(additionalAmount > 0, "Amount should be greater than 0");
        _asset.transferFrom(msg.sender, address(this), additionalAmount);
        collaterals[msg.sender] += additionalAmount;
        emit CollateralIncreased(msg.sender, collaterals[msg.sender]);
    }

    function openPosition(uint256 size, PositionType positionType) external {
        require(collaterals[msg.sender] > 0, "Deposit collateral first");
        require(!positions[msg.sender].isOpen, "Position already open");

        uint256 requiredLiquidity = size;
        uint256 availableLiquidity = (liquidityVault.totalAssets() *
            maxUtilizationPercentage) / 100;

        require(
            _totalOpenInterest + requiredLiquidity <= availableLiquidity,
            "Exceeds max utilization"
        );

        _totalOpenInterest += requiredLiquidity;

        uint256 currentPrice = priceFeed.getPrice();
        uint256 sizeInTokens = size / currentPrice;

        positions[msg.sender] = Position({
            size: size,
            positionType: positionType,
            isOpen: true,
            sizeInTokens: sizeInTokens
        });

        emit PositionOpened(msg.sender, size, positionType);
    }

    function increasePositionSize(uint256 additionalSize) external {
        require(positions[msg.sender].isOpen, "No open position");

        uint256 requiredLiquidity = additionalSize;
        uint256 availableLiquidity = (liquidityVault.totalAssets() *
            maxUtilizationPercentage) / 100;

        require(
            _totalOpenInterest + requiredLiquidity <= availableLiquidity,
            "Exceeds max utilization"
        );

        _totalOpenInterest += requiredLiquidity;

        positions[msg.sender].size += additionalSize;
        uint256 currentPrice = priceFeed.getPrice();
        positions[msg.sender].sizeInTokens += additionalSize / currentPrice;

        emit PositionIncreased(msg.sender, positions[msg.sender].size);
    }

    function closePosition() external {
        require(positions[msg.sender].isOpen, "No open position");

        _totalOpenInterest -= positions[msg.sender].size;

        positions[msg.sender].isOpen = false;
        emit PositionClosed(msg.sender);
    }

    function totalOpenInterest() public view returns (uint256) {
        return _totalOpenInterest;
    }
}
