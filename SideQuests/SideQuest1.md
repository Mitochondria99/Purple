
## Side Quest 1


### 1. In the safeTransferFrom function, what does 0x23b872dd000000000000000000000000 represent and what does it mean when used in the following context on line 192: mstore(0x0c, 0x23b872dd000000000000000000000000).

 - This 0x23b872dd000000000000000000000000 represents the function selector for transferFrom and all of the zeros at the end are used to get rid of all of the dirty bytes that are left from the address.


### 2. In the safeTransferFrom function, why is shl used on line 191 to shift the from to the left by 96 bits?

- This is used for formatting. Without shifting it would look like this 
 000000000000000000000000aabbccddeeff00112233445566778899aabbccdd and after shifting it would look like this 
 aabbccddeeff00112233445566778899aabbccdd000000000000000000000000

 When you are sending a transaction the arguments needs to be formatted and aligned properly. 

This makes sure that the `from` address is formatted right in memory.

### 3. In the safeTransferFrom function, is this memory safe assembly? Why or why not?

- Yes, it is by managing the free pointer and using specific memory slots carefully.


### 4. In the safeTransferFrom function, on line 197, why is 0x1c provided as the 4th argument to call?

- This is call data starting at the offset of 0x1c and this is spanning for the next 0x64. This is basically specifies where in memory the data for the call will begin. The memory location will contain the function selector function along with the arguments to that function the from address to adddress and amount.

### 5. In the safeTransfer function, on line 266, why is revert used with 0x1c and 0x04

- This is suppose to put a stop to execution, if conditions arent met 0x1c(28 decimals) this is where the error starts in memory and the length of the error message is 0x04(4 decimals) this is the length of the error message. This is basically being reverted at this particular location in memory.

### 6. In the safeTransfer function, on line 268, why is 0 mstore’d at 0x34.

- This is used because earlier on this occured mstore(0x34, amount). This code then sets the value at memory location 0x34 back to zero. This is just cleaning up the memory in that memory location.

### 7. In the safeApprove function, on line 317, why is mload(0x00) validated for equality to 1?

- This is checking if data at this specific location is returning true or not. This is bascailly checkig the result of the call and seeing if the approve operation was successful.

### 8. In the safeApprove function, if the token returns false from the approve(address,uint256) function, what happens?

- It would revert