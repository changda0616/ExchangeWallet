// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./Proxy/Delegate.sol";
import "./ExchangeManage.sol";
import "openzeppelin/token/ERC20/IERC20.sol";

interface IExchangeStakePool {
    function initialize(address _token, address _exchangeManage) external;
}

contract ExchangeStakePool is Delegate {
    IERC20 public token;
    ExchangeManage public exchangeManage;
    mapping(address => uint256) public userStakes;

    event Staked(address indexed user, uint256 indexed amount);
    event Unstaked(address indexed user, uint256 indexed amount);

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _owner,
        address _token,
        address _exchangeManage
    ) public {
        require(
            ExchangeManage(_exchangeManage).isAssetSupported(_owner, _token),
            ""
        );
        _transferOwnership(_owner);
        token = IERC20(_token);
        exchangeManage = ExchangeManage(_exchangeManage);
    }

    function stake(uint256 amount) public {
        userStakes[msg.sender] += amount;

        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) public {
        require(userStakes[msg.sender] >= amount, "Not enough stakes");
        userStakes[msg.sender] -= amount;

        require(token.transfer(msg.sender, amount), "Transfer failed");

        emit Unstaked(msg.sender, amount);
    }
}
