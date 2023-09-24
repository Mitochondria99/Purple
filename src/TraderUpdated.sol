// Hella confused with values, need to check this again
// doubting closePosition func

//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LiquidityVault.sol";
import "./PriceFeed.sol";

contract TraderContract is Ownable {
    LiquidityVault public liquidityVault;
    PriceFeed public priceFeed;

    enum PositionType {
        LONG,
        SHORT
    }
    struct Position {
        uint256 size;
        PositionType positionType;
        bool isOpen;
    }

    mapping(address => uint256) public collaterals;
    mapping(address => Position) public positions;
    uint256 public maxUtilizationPercent = 80;

    event CollateralDeposited(address indexed trader, uint256 amount);
    event PositionOpened(
        address indexed trader,
        uint256 size,
        PositionType positionType
    );
    event PositionIncreased(address indexed trader, uint256 newSize);
    event CollateralIncreased(
        address indexed trader,
        uint256 newCollateralAmount
    );
    event PositionClosed(address indexed trader);

    constructor(address _liquidityVault, address _priceFeed) {
        liquidityVault = LiquidityVault(_liquidityVault);
        priceFeed = PriceFeed(_priceFeed);
    }

    function depositCollateral(uint256 amount) external {
        collaterals[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount);
    }

    function openPosition(uint256 size, PositionType positionType) external {
        require(collaterals[msg.sender] > 0, "Deposit collateral first");
        require(!positions[msg.sender].isOpen, "Position already open");

        uint256 requiredLiquidity = size;
        uint256 availableLiquidity = ((liquidityVault.totalSupply() *
            maxUtilizationPercent) / 100) - liquidityVault.reservedLiquidity();

        require(
            requiredLiquidity <= availableLiquidity,
            "Exceeds max utilization"
        );

        liquidityVault.reserve(requiredLiquidity);

        positions[msg.sender] = Position({
            size: size,
            positionType: positionType,
            isOpen: true
        });

        emit PositionOpened(msg.sender, size, positionType);
    }

    function increasePositionSize(uint256 additionalSize) external {
        require(positions[msg.sender].isOpen, "No open position");

        uint256 requiredLiquidity = additionalSize;
        uint256 availableLiquidity = ((liquidityVault.totalSupply() *
            maxUtilizationPercent) / 100) - liquidityVault.reservedLiquidity();

        require(
            requiredLiquidity <= availableLiquidity,
            "Exceeds max utilization"
        );

        liquidityVault.reserve(requiredLiquidity);
        positions[msg.sender].size += additionalSize;

        emit PositionIncreased(msg.sender, positions[msg.sender].size);
    }

    function increaseCollateral(uint256 additionalAmount) external {
        collaterals[msg.sender] += additionalAmount;
        emit CollateralIncreased(msg.sender, collaterals[msg.sender]);
    }

    function closePosition() external {
        require(positions[msg.sender].isOpen, "No open position to close");

        liquidityVault.release(positions[msg.sender].size);
        positions[msg.sender].isOpen = false;

        emit PositionClosed(msg.sender);
    }
}
