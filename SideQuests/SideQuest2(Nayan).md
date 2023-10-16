### 1. A protocol plans to have dozens of vault contracts which it wishes to be able to upgrade all at the same time, which upgradeability pattern should they use?

Ans. Beacon Proxy pattern

### 2.Order the 5 upgradeability patterns in terms of gas efficiency upon user interactions, explain your reasoning for each placement.

    UUPS: requires one SLOAD (storage read) to fetch the implementation address

    Beacon: requires an SLOAD to get the beacon address and another SLOAD to get the implementation address at the beacon contract, plus the CALL to the beacon

    Transparent proxy: involves more logic in the proxy contract to prevent clashes between the proxy and implementation's storage

    Diamond: involves routing calls to various function selectors across different contracts

    Eternal Storage: involves data storage in a separate contract, and all reads and writes to storage must be performed through external calls to this contract

### 3. How can storage collisions occur when using a proxy?

    A storage collision can occur when a new version of the implementation contract is deployed that has a different storage layout than the original.

### 4. Do storage collisions apply when using the Eternal Storage upgradeability pattern? Why?

    No, storage collisions are avoided in the Eternal Storage pattern because all state variables are stored in a single contract,decoupling storage from contract logic and thereby preventing mismatches in storage layout between different contract versions

### 5. What is function selector clashing and how can it cause unexpected issues?

    Function selector clashing occurs when two different functions produce the same 4-byte selector,As a result, when a call is made using a function selector, the EVM may execute the wrong function, leading to unpredictable behavior

### 6. What is the purpose of the \_\_safe_upgrade_gap variable in the following MixinRoles contract? Why is it necessary?

    The `__safe_upgrade_gap` variable in the `MixinRoles` contract serves as a storage gap, ensuring that storage layout changes made in future contract upgrades do not clash with existing storage locations

### 7. What differences are there between the transparent and UUPS upgradeability patterns? What are the pros/cons of each?

Transparent Proxy:

- In the Transparent Proxy pattern, function calls are checked to ensure they are not made by the admin, preventing the admin from directly interacting with the logic contract, unless a specific function is exposed for admin interactions.
- Transparent proxies prevent storage clashes between the proxy and logic contract by using a predefined storage slot for the proxy's admin address and implementation address

Pros:

- It prevents the admin from making proxy calls to the logic contract
- admin logic and the contract logic are distinctly separated, making the codebase easier to understand and potentially safer.

Cons:

- codebase can become more complex due to the necessary checks to distinguish between admin and user interactions
- It can have slightly higher gas costs due to additional logic to handle admin interactions transparently.

UUPS:

- It allows the proxy contract to upgrade its implementation address, assuming the proxy contract has been authorized by the admin
- Unlike Transparent Proxies, the UUPS pattern doesn't restrict the admin's ability to interact with the logic contract through the proxy.

Pros:

- more gas-efficient for regular function calls due to its simpler architecture

Cons:

- Without a fixed storage layout, there's a higher risk of storage collisions
- because the upgrade function is in the logic contract, any security issues in that function could potentially compromise the whole system

### 8. Briefly explain the Diamond Standard at a high level. What does it achieve? How does it achieve it?

    Diamond Standard enables multiple contract functionalities to be combined, allowing for more flexible and scalable on-chain systems. It achieves this by introducing the concept of "facets," which are individual contracts that contain specific functions or logic. In the Diamond pattern, a central "diamond" contract doesn't implement the logic itself but rather delegates calls to the appropriate facets. The standard ensures that the combined logic remains under the Ethereum block gas limit by modularizing functionality.

### 9. What is malicious about the following proxy? What other risks exist?

- Unrestricted delegatecall in the Fallback
- Centralized Control with proxyOwner
- function voting_var is calling the transfer function on the implementation contract, transferring 100 ether to the proxyOwner. This could be used maliciously if the proxyOwner can control the voting process to drain funds from the contract

### 10. Is this an appropriate implementation of a UUPS compliant implementation contract? Why or why not?

I think, this is not an appropriate implementation of a UUPS compliant implementation contract because of:

- `_authorizeUpgrade` function is overridden but is left empty
- constructor uses `_disableInitializers()` which is meant to prevent the use of initializers in the contract. but the initialize function still exists, which is confusing
- `onlyProxy` modifier code missing
- initialize function takes an`_endpoint`parameter but doesn't use it
