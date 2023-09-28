// Hella confused with values, need to check this again
// doubting closePosition func

// TODO: consideration of leverage?
//TODO: Liquidation code

// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LiquidityVault.sol";
import "./PriceFeed.sol";

contract TraderContract is Ownable {
    IERC20 private _asset; // The collateral and trading asset
    LiquidityVault public liquidityVault;
    PriceFeed public priceFeed;
    uint256 public minimumPositionSize;

    uint256 private _totalOpenInterest;
    uint256 public maxUtilizationPercentage = 80; // max utilization of total liquidity

    enum PositionType {
        LONG,
        SHORT
    }

    struct Position {
        uint256 size;
        PositionType positionType;
        uint256 collateral;
        bool isOpen;
        uint256 sizeInTokens;
        uint256 entryPrice;
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

    function openPosition(
        uint256 size,
        uint256 collateralAmount,
        PositionType positionType
    ) external {
        require(size >= minimumPositionSize, "Position size below minimum");

        uint256 currentPrice = priceFeed.getPrice();
        uint256 sizeInTokens = size / currentPrice;

        require(
            collaterals[msg.sender] >= collateralAmount,
            "Insufficient collateral"
        );

        Position memory newPosition = Position({
            size: size,
            sizeInTokens: sizeInTokens,
            collateral: collateralAmount,
            entryPrice: currentPrice,
            positionType: positionType,
            isOpen: true
        });

        positions[msg.sender] = newPosition; // long or short (ID )
        collaterals[msg.sender] -= collateralAmount;
        _totalOpenInterest += size;
    }

    function increasePositionSize(uint256 additionalSize) external {
        Position storage position = positions[msg.sender];
        uint256 currentPrice = priceFeed.getPrice();
        uint256 additionalSizeInTokens = additionalSize / currentPrice; // Calculate size in index tokens

        require(position.isOpen, "No open position");
        require(
            collaterals[msg.sender] >= additionalSize,
            "Insufficient collateral"
        );

        position.size += additionalSize;
        position.sizeInTokens += additionalSizeInTokens;

        // Deducting collateral from user's available collateral
        collaterals[msg.sender] -= additionalSize;

        // Updating totalOpenInterest
        _totalOpenInterest += additionalSize;
    }

    function decreasePositionSize(uint256 sizeToDecrease) external {
        Position storage position = positions[msg.sender];
        require(position.isOpen, "No open position");
        require(
            position.size >= sizeToDecrease,
            "Decreasing more than position size"
        );

        uint256 currentPrice = priceFeed.getPrice();
        uint256 pnl;

        if (position.positionType == PositionType.LONG) {
            pnl = (currentPrice - position.entryPrice) * sizeToDecrease;
        } else {
            pnl = (position.entryPrice - currentPrice) * sizeToDecrease;
        }

        // Adjust the position size and collateral
        position.size -= sizeToDecrease;
        position.collateral += pnl; // This can be negative, decreasing the collateral

        // Update totalOpenInterest
        _totalOpenInterest -= sizeToDecrease;
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
