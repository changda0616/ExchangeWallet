// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./ExchangeStakePool.sol";
import "./ExchangeManage.sol";

// Owner: Protocol
contract ExchangeStakePoolFactory {
    ExchangeManage public exchangeManage;
    mapping(address => address) public exchangeToPool;
    mapping(address => bool) public poolList;
    event PoolInit(address indexed exchange, address indexed pool);

    constructor(address _exchangeManage) {
        exchangeManage = ExchangeManage(_exchangeManage);
    }

    function initStakePool(address _token) public {
        require(
            exchangeManage.isExchangeExists(msg.sender),
            "Exchange is not in the list"
        );
        require(
            exchangeToPool[msg.sender] == address(0),
            "Pool already created for this exchange"
        );

        ExchangeStakePool pool = new ExchangeStakePool(_token);
        exchangeToPool[msg.sender] = address(pool);
        poolList[address(pool)] = true;
        emit PoolInit(msg.sender, address(pool));
    }

    function getStakingPool(
        address _exchangeWallet
    ) public view returns (address) {
        return exchangeToPool[_exchangeWallet];
    }
}
