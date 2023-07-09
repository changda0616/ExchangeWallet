// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

import "../src/MakeOrder.sol";

import "../src/MakeOrder.sol";
import "../src/ExchangeManage.sol";
import "../src/ERC20/ERC20Token.sol";
import "../src/Proxy/Delegator.sol";
import "../src/ExchangeStakePoolFactory.sol";
import "../src/ExchangeStakePool.sol";

contract ExchangeScript is Script {
    function setUp() public {}

    function run() public {
        uint256 key = vm.envUint("protocol_key");
        uint256 exchange = vm.envUint("exchange_key");
        address exchangeWallet = vm.envAddress("exchange_wallet");
        vm.startBroadcast(key);

        ERC20Token mUSDC = new ERC20Token("Mock USDC", "mUSDC");
        ERC20Token mWeth = new ERC20Token("Mock Weth", "mWeth");

        ExchangeManage exchangeManageImple = new ExchangeManage();
        Delegator exchangeManageDelegator = new Delegator(
            address(exchangeManageImple),
            ""
        );
        ExchangeManage exchangeManage = ExchangeManage(
            payable(address(exchangeManageDelegator))
        );

        exchangeManage.initialize();

        address[] memory tokenList = new address[](2);
        tokenList[0] = address(mUSDC);
        tokenList[1] = address(mWeth);
        exchangeManage.addExchange("Exchange 1", exchangeWallet, tokenList);

        ExchangeStakePoolFactory factoryImple = new ExchangeStakePoolFactory();
        Delegator factoryDelegator = new Delegator(address(factoryImple), "");
        ExchangeStakePoolFactory exchangeStakePoolFactory = ExchangeStakePoolFactory(
                payable(address(factoryDelegator))
            );

        exchangeStakePoolFactory.initialize(address(exchangeManage));

        vm.stopBroadcast();
        vm.startBroadcast(exchange);

        ExchangeStakePool mWethPool = ExchangeStakePool(
            payable(exchangeStakePoolFactory.initStakePool(address(mWeth)))
        );
        ExchangeStakePool mUSDCPool = ExchangeStakePool(
            payable(exchangeStakePoolFactory.initStakePool(address(mUSDC)))
        );

        MakeOrder makeOrderImple = new MakeOrder();
        Delegator makeOrderDelegator = new Delegator(
            address(makeOrderImple),
            ""
        );
        MakeOrder makeOrder = MakeOrder(payable(address(makeOrderDelegator)));

        makeOrder.initialize(address(exchangeManage));
        vm.stopBroadcast();
    }
}
