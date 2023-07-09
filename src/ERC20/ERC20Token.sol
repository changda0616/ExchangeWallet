// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "openzeppelin/token/ERC20/ERC20.sol";

contract ERC20Token is ERC20 {
    uint256 public constant INITIAL_SUPPLY = 1_000_000 ether;

    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }
}
