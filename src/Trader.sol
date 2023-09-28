// Hella confused with values, need to check this again
// doubting closePosition func
// consideration of leverage?
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./PriceFeed.sol";
import "./LiquidityVault.sol";

contract TraderHub is Ownable {
    enum PositionType {
        LONG,
        SHORT
    }

    struct Position {
        uint256 size; // in USD
        uint256 collateral; // amount of tokens collateralized
        uint256 sizeInTokens;
        PositionType positionType;
    }

    mapping(address => Position) public positions;
    IERC20 public collateralToken;
    PriceFeed public priceFeed;
    LiquidityVault public liquidityVault;
    uint256 public maxUtilizationPercent = 80; // Sample percentage

    constructor(
        address _collateralToken,
        address _priceFeed,
        address _liquidityVault
    ) {
        collateralToken = IERC20(_collateralToken);
        priceFeed = PriceFeed(_priceFeed);
        liquidityVault = LiquidityVault(_liquidityVault);
    }

    uint256 private _totalOpenInterest;

    function totalOpenInterest() public view returns (uint256) {
        return _totalOpenInterest;
    }

    function openPosition(
        uint256 collateralAmount,
        uint256 size,
        PositionType positionType
    ) external {
        uint256 btcPrice = priceFeed.getPrice();
        uint256 sizeInTokens = size / btcPrice;

        positions[msg.sender] = Position({
            size: size,
            collateral: collateralAmount,
            sizeInTokens: sizeInTokens,
            positionType: positionType
        });

        // Transfer collateral from the trader
        collateralToken.transferFrom(
            msg.sender,
            address(this),
            collateralAmount
        );

        // Update the total open interest
        _totalOpenInterest += size;
    }

    function increasePositionSize(
        address traderAddress,
        uint256 additionalSize
    ) external {
        uint256 btcPrice = priceFeed.getPrice();
        uint256 additionalSizeInTokens = additionalSize / btcPrice;

        positions[traderAddress].size += additionalSize;
        positions[traderAddress].sizeInTokens += additionalSizeInTokens;

        // Update the total open interest
        _totalOpenInterest += additionalSize;
    }

    function closePosition(address traderAddress) external {
        Position storage position = positions[traderAddress];
        require(position.size > 0, "No position open");

        //(Friday)Logic to handle PnL, pay profits to trader or losses to LP would go here

        // Deduct from the total open interest
        _totalOpenInterest -= position.size;

        // Reset the trader's position
        delete positions[traderAddress];
    }
}
