// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract Delegate is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        _transferOwnership(msg.sender);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
