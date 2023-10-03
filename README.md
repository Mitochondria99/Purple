Our PERPETUAL PROTOCOL is a decentralized platform,which allows users to interact with financial trading functionalities backed by ERC20 assets. This protocol facilitates operations like opening,closing, adjusting, and liquidating leveraged positions for the traders and gives an opportunity to provide liquidity for additional gains. It integrates with a `LiquidityVault` and a `PriceFeed` to manage the financial computations and fees:

# How Does the System Work? How Would a User Interact with It?

Users can deposit ERC20 collateral assets into the contract and interact with several trading functions. The contract provides functionalities to open, increase, decrease, and close leveraged trading positions. Additionally, users can liquidate positions that have breached allowed leverage limits. Whereas, LiquidityProviders can make use of a platform by providing liquidity in return of an incentive.

## Contract Operations & Functions

### Deposit and Manage Collateral

`depositCollateral` : Users deposit their ERC20 assets as collateral into the contract.

`increaseCollateral`: Allows users to incrementally increase their collateral.

## Position Management

`openPosition`: Users can open leveraged long or short positions by specifying the size and position type.

`increasePositionSize` & `decreasePositionSize`: Adjust the size of an existing position.

`closePosition`: Close a specific position and reclaim any remaining collateral.

# What actors are involved?

`Users/Traders`: Individuals or entities using the contract to open and manage their trading positions.

`Admin/Owner`: Has privileged access to modify certain contract parameters like position fees. The admin does not interact with user-specific data or user funds.

`Liquidators`: Entities that monitor and liquidate positions that breach allowed leverage levels.
Liquidators can invoke `liquidatePosition` function to liquidate a position that exceeds the permitted leverage. Liquidators are rewarded with a portion of the remaining collateral (`liquidatorReward`).

`Liquidity providers` : Vital participants that supply the necessary liquidity for traders to engage in leveraged trading.

# Liquidity Providers (LPs) and Incentives

**LP Functions**

`deposit`: Allows liquidity providers to deposit funds into the liquidity pool.

`withdraw`: LPs can remove their funds, subject to certain conditions (like ensuring that total liquidity remains above a minimum threshold).

Penalty is given to the liquidity providers for providing unneccesary liquidity.

### Incentive Mechanism

Liquidity providers earn incentives based on the fees generated from traders' positions and the relative proportion of liquidity they've supplied.These fees are accumulated in the LiquidityVault and deducted from trader's position's collateral.

##

Borrowing Fees: These are fees associated with borrowing liquidity for leveraged positions. When a trader borrows funds to leverage their position, a fee is charged based on the borrowed amount.

```
borrowingFeeAmount = position.size * secondsSinceLastUpdate * BORROWING_PER_SHARE_PER_SECOND;

```

Position Fees: These are fees charged when a trader adjusts a position. It is separate from the borrowing fee and serves as a cost associated with the act of adjusting a trade.

```
positionFee = (sizeDelta * positionFeeBasisPoints) / 10_000;
```

### LiquidatorReward considerations:

The `liquidatorReward` is computed as a fraction of the position’s remaining collateral, paid to the msg.sender who invokes the `liquidatePosition` function.
When determining if liquidatorFee should be a percentage of the position’s remaining collateral or its size, we considered it's collateral be a suitable decision given the impact of this choice on incentive structures for liquidators, potential market manipulation, and fairness to position owners.

```
liquidatorReward = (targetPosition.collateral * LIQUIDATION_FEE) / DIVISOR;

```

### known risks/issues

1. The given contracts haven't been tested completely, which may result in breaking of function logic.
