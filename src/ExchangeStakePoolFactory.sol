// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./Proxy/Delegate.sol";
import "./Proxy/Delegator.sol";
import "./ExchangeStakePool.sol";
import "./ExchangeManage.sol";

// Owner: Protocol
contract ExchangeStakePoolFactory is Delegate {
    ExchangeManage public exchangeManage;
    // exchange wallet => token => pool
    mapping(address => mapping(address => address)) public exchangeToPool;
    event PoolInit(address indexed exchange, address indexed pool);

    constructor() {
        _disableInitializers();
    }

    function initialize(address _exchangeManage) public {
        _transferOwnership(msg.sender);
        exchangeManage = ExchangeManage(_exchangeManage);
    }

    function initStakePool(address _token) public returns (address poolAddr) {
        require(
            exchangeManage.isExchangeExists(msg.sender),
            "Exchange is not in the list"
        );
        require(
            exchangeManage.isAssetSupported(msg.sender, _token),
            "Asset is not supported"
        );
        require(
            exchangeToPool[msg.sender][_token] == address(0),
            "Pool already created for this exchange"
        );
        
        
        ExchangeStakePool poolImple = new ExchangeStakePool();
        Delegator delegator = new Delegator(address(poolImple), "");
        ExchangeStakePool pool = ExchangeStakePool(payable(address(delegator)));
        pool.initialize(msg.sender, _token, address(exchangeManage));

        exchangeToPool[msg.sender][_token] = address(pool);
        emit PoolInit(msg.sender, address(pool));
        poolAddr = address(pool);
    }

    function getStakingPool(
        address _exchangeWallet,
        address _token
    ) public view returns (address) {
        return exchangeToPool[_exchangeWallet][_token];
    }
}
