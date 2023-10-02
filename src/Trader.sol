//TODO: Liquidation Fee code
//TODO: BORROWING_PER_SHARE_PER_SECOND decimal arrangement

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
    uint256 public positionFeeBasisPoints = 100;
    uint256 private _totalOpenInterest;
    uint256 public maxUtilizationPercentage = 80; // max utilization of total liquidity
    uint256 public BORROWING_PER_SHARE_PER_SECOND; //TODO

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
    event CollateralIncreased(address indexed trader,uint256 newCollateralAmount);
    event PositionOpened(address indexed trader,uint256 size,PositionType positionType);
    event PositionSizeIncreased(address indexed trader,uint256 positionId,uint256 additionalSize);
    event PositionClosed(address indexed trader);

    modifier onlyOwnerOrTrusted() {
        require(msg.sender == owner(), "Not authorized");
        _;
    }

    constructor(address _liquidityVault, address _priceFeed, IERC20 asset) {
        liquidityVault = LiquidityVault(_liquidityVault);
        priceFeed = PriceFeed(_priceFeed);
        _asset = asset;
    }

    //-------------------
    //      FEES
    //-------------------

    function setPositionFeeBasisPoints(uint256 newFee) external onlyOwnerOrTrusted {
        require(newFee >= 0 && newFee <= 200, "Fee out of bounds");
        positionFeeBasisPoints = newFee;
    }

    function calculatePositionFee(uint256 sizeDelta) internal view returns (uint256) {
        return (sizeDelta * positionFeeBasisPoints) / 10_000;
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

    function openPosition(uint256 size,PositionType positionType) external returns (uint256) {
        require(size >= minimumPositionSize, "Position size below minimum");
        require(size / (collaterals[msg.sender]) <= MAX_LEVERAGE,"leverage limit exceded ");
        uint256 currentPrice = priceFeed.getPrice();
        uint256 sizeInTokens = size / currentPrice;

        // Calculate required collateral based on leverage
        uint256 requiredCollateral = size / MAX_LEVERAGE;
        require(collaterals[msg.sender] >= requiredCollateral,"Insufficient collateral");
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

    function increasePositionSize(uint256 positionId,uint256 additionalSize) external {
        require(positions[msg.sender][positionId].isOpen, "No open position");

        Position storage position = positions[msg.sender][positionId];

        // Adjusting for PnL and Fee before increasing the position
        _updateCollateralAndHandleFees(position,position.size + additionalSize);

        uint256 currentPrice = priceFeed.getPrice();
        uint256 additionalSizeInTokens = additionalSize / currentPrice;

        // Calculate additional collateral requirement based on the leverage
        uint256 additionalCollateralRequirement = (additionalSize * currentPrice) / MAX_LEVERAGE;

        require(collaterals[msg.sender] >= additionalCollateralRequirement,"Insufficient collateral");
        position.size += additionalSize;
        position.sizeInTokens += additionalSizeInTokens;
        collaterals[msg.sender] -= additionalCollateralRequirement;
        _totalOpenInterest += additionalSize;
    }

    function decreasePositionSize(uint256 positionId,uint256 sizeToDecrease) external {
        require(positions[msg.sender][positionId].isOpen,"Position is closed or doesn't exist.");
        Position storage position = positions[msg.sender][positionId];
        require(position.size >= sizeToDecrease,"can't decrease more than position size");
        _updateCollateralAndHandleFees(position,position.size - sizeToDecrease);

        position.size -= sizeToDecrease;

        uint256 currentPrice = priceFeed.getPrice();
        uint256 sizeToDecreaseInTokens = sizeToDecrease / currentPrice;
        position.sizeInTokens -= sizeToDecreaseInTokens;
        _totalOpenInterest -= sizeToDecrease;
    }

    function closePosition(uint256 positionId) external {
        require(positions[msg.sender][positionId].isOpen,"Position is closed or doesn't exist.");

        Position storage positionToClose = positions[msg.sender][positionId];
        _updateCollateralAndHandleFees(positionToClose, 0);
        _totalOpenInterest -= positionToClose.size;
        positionToClose.isOpen = false;
        collaterals[msg.sender] += positionToClose.collateral;
    }

    function _updateCollateralAndHandleFees(Position storage position,uint256 newSize) internal {
        require(position.isOpen,"Position is already closed or doesn't exist.");

        uint256 currentPrice = priceFeed.getPrice();
        int256 totalPnL;

        if (position.positionType == PositionType.LONG) {
            totalPnL = int256((currentPrice - position.entryPrice) * position.size);
        } else {
            totalPnL = int256((position.entryPrice - currentPrice) * position.size);
        }

        uint256 secondsSinceLastUpdate = block.timestamp - position.lastUpdated;
        uint256 borrowingFeeAmount = position.size * secondsSinceLastUpdate * BORROWING_PER_SHARE_PER_SECOND;
        
         // Adjusting collateral for borrowing fees
        require(position.collateral >= borrowingFeeAmount,"Insufficient position collateral to cover borrowing fee");
        position.collateral -= borrowingFeeAmount;
        _asset.transfer(address(liquidityVault), borrowingFeeAmount); // Transfer borrowing fees to the liquidity vault

        // Calculate position fee
        uint256 sizeDelta = newSize > position.size ? newSize - position.size : position.size - newSize;
        uint256 positionFee = calculatePositionFee(sizeDelta);

        // Ensure the position has enough collateral to cover the position fee
        require(position.collateral >= positionFee,"Insufficient position collateral to cover position fee");
        position.collateral -= positionFee;
        _asset.transfer(address(liquidityVault), positionFee); // Transfer position fee to the liquidity vault

        // Adjusting collateral based on PnL
        if (totalPnL < 0) {
            uint256 loss = uint256(-totalPnL);
            require(position.collateral >= loss,"Loss exceeds position collateral");
             position.collateral -= loss;
            _asset.transfer(address(liquidityVault), loss); // Transfer losses to the liquidity vault
        } else {
            position.collateral += uint256(totalPnL);
        }

        require(position.collateral > 0, "Position liquidated");

        uint256 requiredCollateralForNewSize = newSize / MAX_LEVERAGE;
        require(position.collateral >= requiredCollateralForNewSize,"Insufficient collateral for new size");
        uint256 newLeverage = newSize / position.collateral;
        require(newLeverage <= MAX_LEVERAGE, "Exceeds maximum leverage");
        position.lastUpdated = block.timestamp;
    }

    function totalOpenInterest() public view returns (uint256) {
        return _totalOpenInterest;
    }
}
