//check ERC4626 thoroughly
//Modify Deposit, Withdraw, Reserve and Release functions
// Modify Constructor
// ReserveLiquidity issue to be corrected

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LiquidityVault is ERC4626 {
    uint256 public reservedLiquidity;
    IERC20 private immutable _asset; //BTC

    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event LiquidityReserved(uint256 amount);
    event LiquidityReleased(uint256 amount);

    mapping(address => bool) public authorizedAddresses;

    modifier onlyAuthorized() {
        require(authorizedAddresses[msg.sender], "Not authorized");
        _;
    }

    // Need to be changed
    // constructor(IERC20 token) {
    //     _asset = token;
    // }
    constructor(
        ERC20 _token, //USDT/DAI
        string memory _name,
        string memory _symbol
    ) ERC4626(_token) ERC20(_name, _symbol) {
        _asset = _token;
    }

    function asset() public view override returns (address) {
        return address(_asset);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Deposit > 0");

        // Transfer the assets to the vault
        IERC20(asset()).transferFrom(msg.sender, address(this), amount);

        // Calculate the shares to mint for the depositor based on the vault's exchange rate
        uint256 sharesToMint = previewDeposit(amount);

        // Mint the shares to the depositor's address
        _mint(msg.sender, sharesToMint);

        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 shares) external {
        require(shares > 0, "Withdrawal shares > 0");
        require(balanceOf(msg.sender) >= shares, "Insufficient shares");

        // Calculate the assets to return to the user based on the vault's exchange rate
        uint256 assetsToReturn = previewWithdraw(shares);

        // Check if the vault has enough assets for withdrawal
        require(
            IERC20(asset()).balanceOf(address(this)) >= assetsToReturn,
            "Vault has insufficient assets"
        );

        // Burn shares from the user's balance
        _burn(msg.sender, shares);

        // Transfer the assets to the user
        IERC20(asset()).transfer(msg.sender, assetsToReturn);

        emit Withdrawn(msg.sender, assetsToReturn);
    }

    function reserve(uint256 amount) external onlyAuthorized {
        // Ensure there's enough available liquidity to reserve the given amount.
        uint256 availableLiquidity = totalSupply() - reservedLiquidity;
        require(
            amount <= availableLiquidity,
            "Insufficient available liquidity to reserve"
        );

        // Update the reserved liquidity.
        reservedLiquidity += amount;

        // Emit an event for tracking.
        emit LiquidityReserved(amount);
    }

    function release(uint256 amount) external onlyAuthorized {
        require(
            amount <= reservedLiquidity,
            "Cannot release more than reserved liquidity"
        );

        // Subtract the released amount from the reserved liquidity
        reservedLiquidity -= amount;

        // Emit an event to log the amount of liquidity released
        emit LiquidityReleased(amount);
    }
}
