// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LiquidityVault.sol";
import "./PriceFeed.sol";

error InsufficientCollateral(uint256 required, uint256 available);
error InvalidAmount(uint256 amount);
error Unauthorized();
error PositionClosedOrNonexistent();
error LeverageExceeded(uint256 providedLeverage, uint256 maxLeverage);
error FeeOutOfBounds(uint256 newFee);
error PositionSizeMismatch(uint256 newSize, uint256 currentPositionSize);
error BorrowingFeeExceeded(uint256 fee, uint256 availableCollateral);
error LiquidationViolation(uint256 effectiveLeverage, uint256 maxLeverage);
error InsufficientPositionCollateralForFee(
    uint256 availableCollateral,
    uint256 positionFee
);
error LossExceedsPositionCollateral(uint256 positionCollateral, uint256 loss);
error PositionLiquidated();

contract TraderContract is Ownable {
    IERC20 private _asset; // The collateral and trading asset
    LiquidityVault public liquidityVault;
    PriceFeed public priceFeed;
    uint256 public minimumPositionSize;
    uint256 constant MAX_LEVERAGE = 20;
    uint256 public lastPositionId = 0;
    uint256 public positionFeeBasisPoints = 100;
    uint256 private _totalOpenInterest;
    uint256 public maxUtilizationPercentage = 80; // max utilization of total liquidity
    uint256 public BORROWING_PER_SHARE_PER_SECOND; //TODO
    uint256 public constant LIQUIDATION_FEE = 5e18;
    uint256 public constant DIVISOR = 100e36;

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
    AggregatorV3Interface private ethUsdPriceFeedData;
    mapping(address => uint256) public collaterals;
    mapping(address => Position[]) public positions;

    event CollateralDeposited(address indexed trader, uint256 amount);
    event CollateralIncreased(
        address indexed trader,
        uint256 newCollateralAmount
    );
    // event PositionOpened(address indexed trader,uint256 size,PositionType positionType);
    // event PositionSizeIncreased(address indexed trader,uint256 positionId,uint256 additionalSize);
    // event PositionClosed(address indexed trader);

    modifier onlyOwnerAllowed() {
        require(msg.sender == owner(), "Not authorized");
        _;
    }

    constructor(
        address _liquidityVault,
        address _priceFeed,
        address ethUsdPriceFeed,
        IERC20 asset
    ) {
        liquidityVault = LiquidityVault(_liquidityVault);
        priceFeed = PriceFeed(_priceFeed);
        ethUsdPriceFeedData = AggregatorV3Interface(ethUsdPriceFeed);
        _asset = asset;
    }

    //-------------------
    //      FEES
    //-------------------

    function setPositionFeeBasisPoints(
        uint256 newFee
    ) external onlyOwnerAllowed {
        if (newFee < 0 || newFee > 200) revert FeeOutOfBounds(newFee);
        positionFeeBasisPoints = newFee;
    }

    function calculatePositionFee(
        uint256 sizeDelta
    ) internal view returns (uint256) {
        return (sizeDelta * positionFeeBasisPoints) / 10_000;
    }

    function depositCollateral(uint256 amount) external {
        if (amount <= 0) revert InvalidAmount(amount);
        _asset.transferFrom(msg.sender, address(this), amount);
        collaterals[msg.sender] += amount;
        emit CollateralDeposited(msg.sender, amount);
    }

    function increaseCollateral(uint256 additionalAmount) external {
        if (additionalAmount <= 0) revert InvalidAmount(additionalAmount);
        _asset.transferFrom(msg.sender, address(this), additionalAmount);
        collaterals[msg.sender] += additionalAmount;
        emit CollateralIncreased(msg.sender, collaterals[msg.sender]);
    }

    function openPosition(
        uint256 size,
        PositionType positionType
    ) external returns (uint256) {
        if (size < minimumPositionSize)
            revert PositionSizeMismatch(size, minimumPositionSize);
        if (size / collaterals[msg.sender] > MAX_LEVERAGE)
            revert LeverageExceeded(
                size / collaterals[msg.sender],
                MAX_LEVERAGE
            );
        uint256 currentPrice = priceFeed.getPrice(ethUsdPriceFeedData);
        uint256 sizeInTokens = size / currentPrice;

        // Calculate required collateral based on leverage
        uint256 requiredCollateral = size / MAX_LEVERAGE;
        if (collaterals[msg.sender] < requiredCollateral)
            revert InsufficientCollateral(
                requiredCollateral,
                collaterals[msg.sender]
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
        if (!positions[msg.sender][positionId].isOpen)
            revert PositionClosedOrNonexistent();

        Position storage position = positions[msg.sender][positionId];

        // Adjusting for PnL and Fee before increasing the position
        _updateCollateralAndHandleFees(
            position,
            position.size + additionalSize
        );

        uint256 currentPrice = priceFeed.getPrice(ethUsdPriceFeedData);
        uint256 additionalSizeInTokens = additionalSize / currentPrice;

        // Calculate additional collateral requirement based on the leverage
        uint256 additionalCollateralRequirement = (additionalSize *
            currentPrice) / MAX_LEVERAGE;
        if (collaterals[msg.sender] < additionalCollateralRequirement)
            revert InsufficientCollateral(
                additionalCollateralRequirement,
                collaterals[msg.sender]
            );

        position.size += additionalSize;
        position.sizeInTokens += additionalSizeInTokens;
        collaterals[msg.sender] -= additionalCollateralRequirement;
        _totalOpenInterest += additionalSize;
    }

    function decreasePositionSize(
        uint256 positionId,
        uint256 sizeToDecrease
    ) external {
        if (!positions[msg.sender][positionId].isOpen)
            revert PositionClosedOrNonexistent();
        Position storage position = positions[msg.sender][positionId];
        if (position.size < sizeToDecrease)
            revert PositionSizeMismatch(
                sizeToDecrease,
                positions[msg.sender][positionId].size
            );
        _updateCollateralAndHandleFees(
            position,
            position.size - sizeToDecrease
        );

        position.size -= sizeToDecrease;
        uint256 currentPrice = priceFeed.getPrice(ethUsdPriceFeedData);
        uint256 sizeToDecreaseInTokens = sizeToDecrease / currentPrice;
        position.sizeInTokens -= sizeToDecreaseInTokens;
        _totalOpenInterest -= sizeToDecrease;
    }

    function closePosition(uint256 positionId) external {
        if (!positions[msg.sender][positionId].isOpen)
            revert PositionClosedOrNonexistent();
        Position storage positionToClose = positions[msg.sender][positionId];
        _updateCollateralAndHandleFees(positionToClose, 0);
        _totalOpenInterest -= positionToClose.size;
        positionToClose.isOpen = false;
        collaterals[msg.sender] += positionToClose.collateral;
    }

    function _updateCollateralAndHandleFees(
        Position storage position,
        uint256 newSize
    ) internal {
        if (!position.isOpen) revert PositionClosedOrNonexistent();

        uint256 currentPrice = priceFeed.getPrice(ethUsdPriceFeedData);
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

        uint256 secondsSinceLastUpdate = block.timestamp - position.lastUpdated;
        uint256 borrowingFeeAmount = position.size *
            secondsSinceLastUpdate *
            BORROWING_PER_SHARE_PER_SECOND;

        // Adjusting collateral for borrowing fees
        if (position.collateral < borrowingFeeAmount)
            revert BorrowingFeeExceeded(
                borrowingFeeAmount,
                position.collateral
            );
        position.collateral -= borrowingFeeAmount;
        _asset.transfer(address(liquidityVault), borrowingFeeAmount); // Transfer borrowing fees to the liquidity vault

        // Calculate position fee
        uint256 sizeDelta = newSize > position.size
            ? newSize - position.size
            : position.size - newSize;
        uint256 positionFee = calculatePositionFee(sizeDelta);

        // Ensure the position has enough collateral to cover the position fee
        if (position.collateral < positionFee)
            revert InsufficientPositionCollateralForFee(
                position.collateral,
                positionFee
            );
        position.collateral -= positionFee;
        _asset.transfer(address(liquidityVault), positionFee); // Transfer position fee to the liquidity vault

        // Adjusting collateral based on PnL
        if (totalPnL < 0) {
            uint256 loss = uint256(-totalPnL);
            if (position.collateral < loss)
                revert LossExceedsPositionCollateral(position.collateral, loss);

            position.collateral -= loss;
            _asset.transfer(address(liquidityVault), loss); // Transfer losses to the liquidity vault
        } else {
            position.collateral += uint256(totalPnL);
        }

        if (position.collateral <= 0) revert PositionLiquidated();

        uint256 requiredCollateralForNewSize = newSize / MAX_LEVERAGE;
        if (position.collateral < requiredCollateralForNewSize)
            revert InsufficientCollateral(
                requiredCollateralForNewSize,
                position.collateral
            );
        uint256 newLeverage = newSize / position.collateral;
        if (newLeverage > MAX_LEVERAGE)
            revert LeverageExceeded(newLeverage, MAX_LEVERAGE);
        position.lastUpdated = block.timestamp;
    }

    function liquidatePosition(address trader, uint256 positionId) external {
        Position storage targetPosition = positions[trader][positionId];

        _updateCollateralAndHandleFees(targetPosition, targetPosition.size);
        if (targetPosition.collateral == 0) {
            return;
        }

        uint256 effectiveLeverage = targetPosition.size /
            targetPosition.collateral;
        if (effectiveLeverage > MAX_LEVERAGE)
            revert LiquidationViolation(effectiveLeverage, MAX_LEVERAGE);

        // If position exceeds max leverage after accounting for PnL and fees, then liquidate
        uint256 liquidatorReward = (targetPosition.collateral *
            LIQUIDATION_FEE) / DIVISOR;
        _asset.transfer(msg.sender, liquidatorReward);

        // Return the remaining collateral to the trader after deducting the bonus
        uint256 remainingCollateral = targetPosition.collateral -
            liquidatorReward;
        _asset.transfer(trader, remainingCollateral);
        _totalOpenInterest -= targetPosition.size;
        targetPosition.isOpen = false;
    }

    function totalOpenInterest() public view returns (uint256) {
        return _totalOpenInterest;
    }
}
