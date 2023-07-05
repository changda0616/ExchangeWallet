// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/access/Ownable.sol";

contract ExchangeStakePool is Ownable {
    IERC20 public token;
    mapping(address => uint256) public userStakes;

    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);

    constructor(address _token) {
        token = IERC20(_token);
    }

    function stake(uint256 amount) public {
        userStakes[msg.sender] += amount;

        require(token.transfer(address(this), amount), "Transfer failed");
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) public {
        require(userStakes[msg.sender] >= amount, "Not enough stakes");
        userStakes[msg.sender] -= amount;

        require(token.transfer(msg.sender, amount), "Transfer failed");

        emit Unstaked(msg.sender, amount);
    }

    function getStakeAmount(address user) public view returns (uint256) {
        return userStakes[user];
    }
}
