- README

  - How does the system work? How would a user interact with it?
  - What actors are involved? Is there a keeper? What is the admin tasked with?
  - What are the known risks/issues?
  - Any pertinent formulas used.

- Smart Contract(s) with the following functionalities, with corresponding tests:

  - ✅ Liquidity Providers can deposit and withdraw liquidity.
  - ✅ A way to get the realtime price of the asset being traded.
  - ✅ Traders can open a perpetual position for BTC, with a given size and collateral.
  - ✅ Traders can increase the size of a perpetual position.
  - ✅ Traders can increase the collateral of a perpetual position.
  - ✅ Traders cannot utilize more than a configured percentage of the deposited liquidity.
  - ✅ Liquidity providers cannot withdraw liquidity that is reserved for positions.

Functionalities to add with Mission 2:

- ✅ Traders can decrease the size of their position and realize a proportional amount of their PnL.
- Traders can decrease the collateral of their position.
- Individual position’s can be liquidated with a `liquidate` function, any address may invoke the `liquidate` function.
- A `liquidatorFee` is taken from the position’s remaining collateral upon liquidation with the `liquidate` function and given to the caller of the `liquidate` function.
- It is up to you whether the `liquidatorFee` is a percentage of the position’s remaining collateral or the position’s size, you should have a reasoning for your decision documented in the `README.md`.
- Traders can never modify their position such that it would make the position liquidatable.
- Traders are charged a `borrowingFee` which accrues as a function of their position size and the length of time the position is open.
- Traders are charged a `positionFee` from their collateral whenever they change the size of their position, the `positionFee` is a percentage of the position size delta (USD converted to collateral token). — Optional/Bonus

##Edge Cases:
