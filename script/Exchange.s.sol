// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/MakeOrder.sol";

contract ExchangeScript is Script {
    function setUp() public {}

    function run() public {
        uint256 key = vm.envUint("wallet_key");
        address admin = vm.envAddress("wallet");
        vm.broadcast(key);

        MakeOrder makeOrder = new MakeOrder();
    }
}
