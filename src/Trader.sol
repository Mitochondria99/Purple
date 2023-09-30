// Hella confused with values, need to check this again
// doubting closePosition func
// in case of loss, send value deducted from collateral to LPs (func decrespositionsize)
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
    uint256 constant MAX_LEVERAGE = 20;
    uint256 public lastPositionId = 0;

    uint256 private _totalOpenInterest;
    uint256 public maxUtilizationPercentage = 80; // max utilization of total liquidity

    enum PositionType {
        LONG,
        SHORT
    }

    struct Position {
        uint256 positionId;
        uint256 size;
        PositionType positionType;
        uint256 collateral;
        bool isOpen;
        uint256 sizeInTokens;
        uint256 entryPrice;
        uint256 lastUpdated;
    }

    mapping(address => uint256) public collaterals;
    mapping(address => Position[]) public positions;

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
    event PositionSizeIncreased(
        address indexed trader,
        uint256 positionId,
        uint256 additionalSize
    );
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
        PositionType positionType
    ) external returns (uint256) {
        require(size >= minimumPositionSize, "Position size below minimum");
        require(
            size / (collaterals[msg.sender]) <= MAX_LEVERAGE,
            "leverage limit exceded "
        );
        uint256 currentPrice = priceFeed.getPrice();
        uint256 sizeInTokens = size / currentPrice;

        // Calculate required collateral based on leverage
        uint256 requiredCollateral = size / MAX_LEVERAGE; // Given max leverage of 20
        require(
            collaterals[msg.sender] >= requiredCollateral,
            "Insufficient collateral"
        );
        // for the new position
        lastPositionId++;

        Position memory newPosition = Position({
            positionId: lastPositionId,
            size: size,
            sizeInTokens: sizeInTokens,
            collateral: requiredCollateral,
            entryPrice: currentPrice,
            positionType: positionType,
            isOpen: true,
            lastUpdated: block.timestamp
        });

        positions[msg.sender][lastPositionId] = newPosition;
        collaterals[msg.sender] -= requiredCollateral;
        _totalOpenInterest += size;
        return lastPositionId;
    }

    function increasePositionSize(
        uint256 positionId,
        uint256 additionalSize
    ) external {
        require(additionalSize > 0, "Increase amount must be positive");

        Position storage position = positions[msg.sender][positionId];
        require(position.size > 0, "Invalid position");

        uint256 newSize = position.size + additionalSize;
        uint256 additionalCollateralRequired = additionalSize / 20; // leverage of 20x
        _adjustCollateralBasedOnPnL(position, newSize);

        require(
            collaterals[msg.sender] >= additionalCollateralRequired,
            "Insufficient collateral after PnL adjustment"
        );

        // Update position and collateral details
        position.size = newSize;
        position.lastUpdated = block.timestamp;
        collaterals[msg.sender] -= additionalCollateralRequired;
    }

    function decreasePositionSize(
        uint256 positionId,
        uint256 sizeToDecrease
    ) external {
        Position storage position = positions[msg.sender][positionId];

        require(
            position.isOpen,
            "Position is already closed or doesn't exist."
        );
        require(
            position.size >= sizeToDecrease,
            "Decreasing more than position size"
        );

        uint256 newSize = position.size - sizeToDecrease;

        // adjust the collateral based on the current PnL and the newSize
        _adjustCollateralBasedOnPnL(position, newSize);
        position.size = newSize;
        _totalOpenInterest -= sizeToDecrease;
    }

    // function closePosition(uint256 positionId) external {
    //     require(
    //         positions[msg.sender][positionId].isOpen,
    //         "Position is already closed or doesn't exist."
    //     );

    //     Position storage positionToClose = positions[msg.sender][positionId];

    //     // Adjust the collateral based on PnL
    //     _adjustCollateralBasedOnPnL(positionToClose);

    //     // Updating totalOpenInterest
    //     _totalOpenInterest -= positionToClose.size;

    //     // Mark the position as closed
    //     positionToClose.isOpen = false;
    // }

    function _adjustCollateralBasedOnPnL(
        Position storage position,
        uint256 newSize
    ) internal {
        uint256 currentPrice = priceFeed.getPrice();
        int256 totalPnL;

        if (position.positionType == PositionType.LONG) {
            totalPnL = int256(
                (currentPrice - position.entryPrice) * position.size
            );
        } else {
            totalPnL = int256(
                (position.entryPrice - currentPrice) * position.size
            );
        }

        if (totalPnL < 0) {
            uint256 loss = uint256(-totalPnL);
            require(
                position.collateral >= loss,
                "Loss exceeds position collateral"
            );

            // Deducting the loss from the position's collateral
            position.collateral -= loss;

            // Transfer the loss amount to the liquidityVault
            collaterals[msg.sender] -= loss;
            _asset.transfer(address(liquidityVault), loss);
        }

        // Calculate the new collateral after considering PnL
        int256 newCollateral = int256(position.collateral) + totalPnL;
        require(newCollateral > 0, "Position liquidated");
        uint256 requiredCollateralForNewSize = newSize / MAX_LEVERAGE;

        // Ensure the trader has enough collateral to support the new size
        require(
            uint256(newCollateral) >= requiredCollateralForNewSize,
            "Insufficient collateral for new size"
        );

        uint256 newLeverage = (newSize * MAX_LEVERAGE) / uint256(newCollateral);
        require(newLeverage <= MAX_LEVERAGE, "Exceeds maximum leverage");

        // Update the position's collateral
        position.collateral = uint256(newCollateral);
    }

    function totalOpenInterest() public view returns (uint256) {
        return _totalOpenInterest;
    }
}
