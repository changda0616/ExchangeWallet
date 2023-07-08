// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// Owner: EOA
contract Wallet {
    address public owner;
    uint private _recoveryCount;
    uint private _recoveryStarted;
    uint private _cooldownEnd;
    uint private constant _RECOVER_THRESHOLD = 2;
    uint private constant _RECOVERY_PERIOD = 1 days;
    uint private constant _COOLDOWN_PERIOD = 3 days;
    mapping(address => bool) private _recoveryAddresses;

    event Deposit(address indexed _from, uint _value);
    event Withdrawal(address indexed _to, uint _value);
    event RecoveryStarted(address indexed _recoveryAddress);
    event RecoveryAddressConfirmed(address indexed _recoveryAddress);
    event OwnerRecovered(address indexed _oldOwner, address indexed _newOwner);
    event RecoveryAddressAdded(address indexed _recoveryAddress);
    event RecoveryAddressRemoved(address indexed _recoveryAddress);

    constructor() {
        owner = msg.sender;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw(uint amount) public returns (bool) {
        require(msg.sender == owner, "Only owner can withdraw");
        require(address(this).balance >= amount, "Not enough balance");
        (bool result, ) = payable(msg.sender).call{value: amount}("");
        emit Withdrawal(msg.sender, amount);
        return result;
    }

    function isRecoveryAddress(address account) public view returns (bool) {
        return _recoveryAddresses[account];
    }

    function checkBalance() public view returns (uint) {
        require(msg.sender == owner, "Only owner can check the balance");
        return address(this).balance;
    }

    function addRecoveryAddress(address _recoveryAddress) public {
        require(msg.sender == owner, "Only owner can add recovery address");
        _recoveryAddresses[_recoveryAddress] = true;
        emit RecoveryAddressAdded(_recoveryAddress);
    }

    function removeRecoveryAddress(address _recoveryAddress) public {
        require(msg.sender == owner, "Only owner can remove recovery address");
        delete _recoveryAddresses[_recoveryAddress];
        emit RecoveryAddressRemoved(_recoveryAddress);
    }

    function startRecovery() public {
        require(_recoveryAddresses[msg.sender], "Not a recovery address");
        require(block.timestamp > _cooldownEnd, "Recovery is in cooldown");
        _recoveryStarted = block.timestamp;
        _cooldownEnd = block.timestamp + _COOLDOWN_PERIOD;
        _recoveryCount = 1;
        emit RecoveryStarted(msg.sender);
    }

    function confirmRecovery() public {
        require(_recoveryAddresses[msg.sender], "Not a recovery address");
        require(
            block.timestamp <= _recoveryStarted + _RECOVERY_PERIOD,
            "Recovery period has ended"
        );
        _recoveryCount++;
        emit RecoveryAddressConfirmed(msg.sender);
        if (_recoveryCount >= _RECOVER_THRESHOLD) {
            address oldOwner = owner;
            owner = msg.sender;
            _recoveryCount = 0;
            emit OwnerRecovered(oldOwner, owner);
        }
    }
}
