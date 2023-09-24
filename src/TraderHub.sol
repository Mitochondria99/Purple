// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;


contract TraderHub {

struct Position {
    uint256 size; // size of the position
    uint256 collateral; // Collateral for the position
}

// Stores each user's current trading position
mapping(address => Position) public positions;
// Stores each user's current collateral balance
mapping(address => uint256) public balances;

// Represents liquidity for all user's
uint256 public totalLiquidity;
//Maximum percentage of total liquidity for a user
uint256 public maxUtilizationPercentage = 80;

event Deposited(address indexed user, uint256 amount);
event PositionOpened(address indexed user, uint256 size, uint256 collateral);
event PositionIncreased(address indexed user, uint256 newSize, uint256 newCollateral);
event CollateralIncreased(address indexed user, uint256 newCollateral);

// User can deposit collateral
function depositCollateral() external payable {
    balances[msg.sender] += msg.value;
    totalLiquidity += msg.value;
    emit Deposited(msg.sender, msg.value);
}

// User can open a trading position
function openPosition(uint256 size, uint256 collateral) external {
    require(balances[msg.sender] >= collateral, "Not enough balance");
    require(collateral * 100 / totalLiquidity <= maxUtilizationPercentage, "Exceeds max utilization");

    balances[msg.sender] -= collateral;
    positions[msg.sender] = Position(size, collateral);

    emit PositionOpened(msg.sender, size, collateral);
}
// User can increase position size
function increasePositionSize(uint256 additionalSize, uint256 additionalCollateral) external {
    require(balances[msg.sender] >= additionalCollateral, "Not enough balance");
    require((positions[msg.sender].collateral + additionalCollateral) * 100 / totalLiquidity <= maxUtilizationPercentage, "Exceeds max utilization");

    balances[msg.sender] -= additionalCollateral;
    positions[msg.sender].size += additionalSize;
    positions[msg.sender].collateral += additionalCollateral;

    emit PositionIncreased(msg.sender, positions[msg.sender].size, positions[msg.sender].collateral);
}
// User can increase collateral for an exisiting position without changing size
function increaseCollateral(uint256 additionalCollateral) external {
    require(balances[msg.sender] >= additionalCollateral,"Not enough balance");
    require((positions[msg.sender].collateral + additionalCollateral) * 100 / totalLiquidity <= maxUtilizationPercentage, "Exceeds max utilization");

    balances[msg.sender] -= additionalCollateral;
    positions[msg.sender].collateral += additionalCollateral;
    
    emit CollateralIncreased(msg.sender, positions[msg.sender].collateral);

}

}

