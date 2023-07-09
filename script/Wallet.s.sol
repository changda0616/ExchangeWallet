// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/Proxy/Delegator.sol";
import "../src/Wallet.sol";

contract WalletScript is Script {
    function setUp() public {}

    function run() public {
        uint256 key = vm.envUint("user_key");

        vm.broadcast(key);

        Wallet imple = new Wallet();
        Delegator delegator = new Delegator(address(imple), "");
        Wallet wallet = Wallet(payable(address(delegator)));
        wallet.initialize();
    }
}
