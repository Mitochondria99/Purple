//SPDX-License-Identifier:MIT
/** @dev Nayan 
Sample contract for trader to test with LiquidityVault
Open&Close Position nd Increase (LONG, SHORT)
Add&IncreaseCollateral
*/
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LiquidityVault.sol";
import "./PriceFeed.sol";

contract TraderContract is Ownable {
    LiquidityVault public liquidityVault;
    PriceFeed public priceFeed;

    struct Position {
        uint256 size; // Position size
        uint256 collateral;
        bool isOpen; // Position status
    }

    mapping(address => Position) public positions;
    uint256 public maxUtilizationPercent = 80;

    event PositionOpened(
        address indexed trader,
        uint256 size,
        uint256 collateral
    );
    event PositionIncreased(
        address indexed trader,
        uint256 newSize,
        uint256 addedCollateral
    );
    event CollateralIncreased(address indexed trader, uint256 newCollateral);

    constructor(address _liquidityVault, address _priceFeed) {
        liquidityVault = LiquidityVault(_liquidityVault);
        priceFeed = PriceFeed(_priceFeed);
    }

    function depositCollateral(uint256 amount) external {
        require(positions[msg.sender].isOpen, "No open position");
        require(amount > 0, "Amount must be greater than 0");

        // Transfer collateral from the trader to this contract
        // This assumes that the trader is depositing an ERC20 token as collateral
        IERC20 collateralToken = IERC20(liquidityVault.asset());
        collateralToken.transferFrom(msg.sender, address(this), amount);

        positions[msg.sender].collateral += amount;
        emit CollateralDeposited(msg.sender, amount);
    }

    function openPosition(uint256 size, uint256 collateral) external {
        require(!positions[msg.sender].isOpen, "Position already open");
        uint256 price = priceFeed.getPrice();
        require(collateral >= price * size, "Insufficient collateral");
        uint256 requiredLiquidity = size;
        uint256 availableLiquidity = (liquidityVault.totalSupply() *
            maxUtilizationPercent) /
            100 -
            liquidityVault.reservedLiquidity;
        require(
            requiredLiquidity <= availableLiquidity,
            "Exceeds max utilization"
        );

        liquidityVault.reserve(requiredLiquidity);

        positions[msg.sender] = Position({
            size: size,
            collateral: collateral,
            isOpen: true
        });

        emit PositionOpened(msg.sender, size, collateral);
    }

    function increasePositionSize(
        uint256 newSize,
        uint256 addedCollateral
    ) external {
        require(positions[msg.sender].isOpen, "No open position");

        uint256 price = priceFeed.getPrice();
        uint256 sizeDifference = newSize - positions[msg.sender].size;
        require(
            addedCollateral >= price * sizeDifference,
            "Insufficient added collateral"
        );

        uint256 requiredLiquidity = sizeDifference;
        uint256 availableLiquidity = (liquidityVault.totalSupply() *
            maxUtilizationPercent) /
            100 -
            liquidityVault.reservedLiquidity;
        require(
            requiredLiquidity <= availableLiquidity,
            "Exceeds max utilization"
        );

        liquidityVault.reserve(requiredLiquidity);

        positions[msg.sender].size += sizeDifference;
        positions[msg.sender].collateral += addedCollateral;

        emit PositionIncreased(
            msg.sender,
            positions[msg.sender].size,
            addedCollateral
        );
    }

    function increaseCollateral(uint256 addedCollateral) external {
        require(positions[msg.sender].isOpen, "No open position");
        positions[msg.sender].collateral += addedCollateral;
        emit CollateralIncreased(msg.sender, positions[msg.sender].collateral);
    }

    function closePosition() external {
        require(positions[msg.sender].isOpen, "No open position");

        uint256 price = priceFeed.getPrice();
        uint256 positionValue = positions[msg.sender].size * price;

        IERC20 collateralToken = IERC20(liquidityVault.asset());

        if (positionValue <= positions[msg.sender].collateral) {
            // The position is profitable or has broken even.
            uint256 profit = positions[msg.sender].collateral - positionValue;
            collateralToken.transfer(msg.sender, profit + positionValue);
        } else {
            // The position is at a loss.
            uint256 loss = positionValue - positions[msg.sender].collateral;
            require(
                collateralToken.balanceOf(address(this)) >= loss,
                "Contract has insufficient collateral"
            );
            collateralToken.transfer(
                msg.sender,
                positions[msg.sender].collateral
            );
        }

        // Release reserved liquidity from LiquidityVault.
        liquidityVault.release(positions[msg.sender].size);

        delete positions[msg.sender];
        emit PositionClosed(msg.sender);
    }
}
