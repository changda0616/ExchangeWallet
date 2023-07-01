// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Wallet {
    address public owner;
    uint private constant THRESHOLD = 2;
    uint private recoveryCount;
    uint private recoveryStarted;
    uint private cooldownEnd;
    uint private constant RECOVERY_PERIOD = 1 days;
    uint private constant COOLDOWN_PERIOD = 3 days;
    mapping(address => bool) private recoveryAddresses;

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
        return recoveryAddresses[account];
    }

    function checkBalance() public view returns (uint) {
        require(msg.sender == owner, "Only owner can check the balance");
        return address(this).balance;
    }

    function addRecoveryAddress(address _recoveryAddress) public {
        require(msg.sender == owner, "Only owner can add recovery address");
        recoveryAddresses[_recoveryAddress] = true;
        emit RecoveryAddressAdded(_recoveryAddress);
    }

    function removeRecoveryAddress(address _recoveryAddress) public {
        require(msg.sender == owner, "Only owner can remove recovery address");
        delete recoveryAddresses[_recoveryAddress];
        emit RecoveryAddressRemoved(_recoveryAddress);
    }

    function startRecovery() public {
        require(recoveryAddresses[msg.sender], "Not a recovery address");
        require(block.timestamp > cooldownEnd, "Recovery is in cooldown");
        recoveryStarted = block.timestamp;
        cooldownEnd = block.timestamp + COOLDOWN_PERIOD;
        recoveryCount = 1;
        emit RecoveryStarted(msg.sender);
    }

    function confirmRecovery() public {
        require(recoveryAddresses[msg.sender], "Not a recovery address");
        require(
            block.timestamp <= recoveryStarted + RECOVERY_PERIOD,
            "Recovery period has ended"
        );
        recoveryCount++;
        emit RecoveryAddressConfirmed(msg.sender);
        if (recoveryCount >= THRESHOLD) {
            address oldOwner = owner;
            owner = msg.sender;
            recoveryCount = 0;
            emit OwnerRecovered(oldOwner, owner);
        }
    }
}
