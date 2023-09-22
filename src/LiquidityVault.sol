//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LiquidityVault is ERC4626, Ownable {
    uint256 public reservedLiquidity;

    // For better transparency, using events to log activities on the contract
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event LiquidityReserved(uint256 amount);
    event LiquidityReleased(uint256 amount);

    // This ensures that only authorized addresses can reserve and release liquidity.
    mapping(address => bool) public authorizedAddresses;

    modifier onlyAuthorized() {
        require(authorizedAddresses[msg.sender], "Not authorized");
        _;
    }

    constructor(address _token) ERC4626(_token) {}

    // Allows the owner to authorize/deauthorize trader contracts
    function setAuthorization(
        address _address,
        bool _status
    ) external onlyOwner {
        authorizedAddresses[_address] = _status;
    }

    function deposit(uint256 amount) external {
        _deposit(msg.sender, msg.sender, amount, amount); // Simplified for the demonstration
        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(
            amount + reservedLiquidity <= totalSupply(),
            "Cannot withdraw reserved liquidity"
        );
        _withdraw(msg.sender, msg.sender, msg.sender, amount, amount);
        emit Withdrawn(msg.sender, amount);
    }

    // Only trader contracts can reserve liquidity for trading operations.
    function reserve(uint256 amount) external onlyAuthorized {
        reservedLiquidity += amount;
        emit LiquidityReserved(amount);
    }

    // Only trader contracts can release liquidity post trading operations.
    function release(uint256 amount) external onlyAuthorized {
        reservedLiquidity -= amount;
        emit LiquidityReleased(amount);
    }
}
