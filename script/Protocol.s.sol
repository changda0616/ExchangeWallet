// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/ExchangeManage.sol";
import "../src/ExchangeStakePoolFactory.sol";

contract ProtocolScript is Script {
    function setUp() public {}

    function run() public {
        uint256 key = vm.envUint("wallet_key");
        address admin = vm.envAddress("wallet");
        vm.broadcast(key);

        ExchangeManage exchangeManage = new ExchangeManage();
        ExchangeStakePoolFactory exchangeStakePoolFactory = new ExchangeStakePoolFactory(
                address(exchangeManage)
            );
    }
}
