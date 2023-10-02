# Mission 1 Review

## Notes On Each Functionality

### Liquidity Providers can deposit and withdraw liquidity

I like the approach you’ve taken of using two separate contracts for the TraderHub and the LiquidityVault, this way LPs can be easily paid/charged by transferring funds to and from the LiquidityVault. It also does a great job of reducing complexity in a single contract. Good decision!

### A way to get the realtime price of the asset being traded.

I like the decision you made to have the price fetching logic be in it’s own PriceFeed contract — this does a good job of making the price available in multiple contracts of the system while keeping that logic abstracted from contracts like the TraderHub.

### Traders can open a perpetual position for BTC, with a given size and collateral.

We have logic to track the size and collateral amount in each position and add to each of the values respectively. One thing we’ll want to add is the ability to track the price at which the trader opened their position. This *could* be done by recording the price at the time when they open the trade, however I think there’s a more adaptable method we can use to achieve this!

We can track the “sizeInTokens” of a position, e.g. “how many tokens of the index token does the trader’s position represent?” (Note that the index token amounts are illusory, we are never dealing with any actual amount of BTC in this system).

For example:

* If I create a position with $40,000 of size, if the price of bitcoin is $20,000, I will have a sizeInTokens of 2 tokens.
* This can be used to determine the PnL of the position later when I choose to decrease my position and realize profits or losses. The method for determining PnL based on this is laid out in the examples for Mission 1.

Another note, it will be useful to make the collateral token that traders can provide the same token as the one that LPs can deposit and withdraw. This will streamline the process of paying profits to traders and losses to LPs.


### Traders can increase the size of a perpetual position.

We have logic to increase the size of a perpetual position. The only thing we’ll want to add is the logic necessary to translate that into a sizeInTokens for the position. If I increase the size of the position via positions[msg.sender].size += additionalSize, we should compute what the additionalSizeInTokens is based on the current BTC price and increment positions[msg.sender].sizeInTokens += additionalSizeInTokens.

### Traders can increase the collateral of a perpetual position.

We have logic for this! Notice that a dedicated function might not be necessary as the trader could call increasePositionSize(0, additionalCollateral) — however a dedicated function for increaseCollateral is fine for utility as well! Just be sure that it doesn’t introduce any inconsistencies with the increasePositionSize function.

### Traders cannot utilize more than a configured percentage of the deposited liquidity.

The totalLiquidity in the TraderHub contract is tracking the deposited collateral by traders, when the reserve validation should depend on the liquidity present in the LiquidityVault. You might consider substituting instances of the totalLiquidity with the deposited amount in the LiquidityVault, and changing the validation to validate the aggregate size of all positions rather than the position’s collateral.

E.g. require(totalOpenInterest * 100 / liquidityVault.totalAssets() <= maxUtilizationPercentage, "Exceeds max utilization");


### Liquidity providers cannot withdraw liquidity that is reserved for positions.

Similarly to the validation that trader’s cannot open more size than can be supported by the liquidity available in the LiquidityVault, LPs should not be able to withdraw more liquidity than the openInterest/liquidity validation can support.

Therefore we should include a similar require statement for LPs in the LiquidityVault contract when they are withdrawing, e.g.

require(traderHub.totalOpenInterest() * 100 / totalAssets() <= traderHub.maxUtilizationPercentage(), "Exceeds max utilization");

This will replace the need to track the reserved amounts with the reserve and release functions.


## Suggestions

- Change the collateral token used by traders to match the _asset that LPs deposit and withdraw.
- Introduce sizeInTokens as a field for the Position struct in the TraderHub, and update it accordingly in the openPosition and increasePositionSize function.
- Modify the maxUtilization validation in the TraderHub such that it validates the total size of positions (open interest) vs. the deposited liquidity in the LiquidityVault.
- Add a similar maxUtilization validation to the withdraw function such that LPs cannot withdraw liquidity that would set the utilization over the maximum.
