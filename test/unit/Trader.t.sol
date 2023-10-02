//SPDX-License-Identifier:MIT

pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {TraderContract} from "../../src/Trader.sol";

contract TraderTest is Test {
    TraderContract trader;

    function setUP() external {
        trader = new TraderContract();
    }
}
