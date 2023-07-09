// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Wallet.sol";
import "../src/Delegator.sol";

contract WalletTest is Test {
    Delegator walletProxy;
    Wallet wallet;

    address owner = makeAddr("owner");
    address recovery1 = address(0x12);
    address recovery2 = address(0x34);

    uint256 constant INIT_BALANCE = 10 ether;

    uint private constant RECOVERY_PERIOD = 1 days;
    uint private constant COOLDOWN_PERIOD = 3 days;

    event Deposit(address indexed _from, uint _value);
    event Withdrawal(address indexed _to, uint _value);
    event RecoveryStarted(address indexed _recoveryAddress);
    event RecoveryAddressConfirmed(address indexed _recoveryAddress);
    event OwnerRecovered(address indexed _oldOwner, address indexed _newOwner);
    event RecoveryAddressAdded(address indexed _recoveryAddress);
    event RecoveryAddressRemoved(address indexed _recoveryAddress);

    bytes32 internal constant IMPL_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1); // 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc

    function setUp() public {
        vm.label(owner, "owner");
        vm.label(recovery1, "recovery1");
        vm.label(recovery2, "recovery2");
        vm.label(address(this), "This");

        vm.deal(owner, INIT_BALANCE);
        vm.startPrank(owner);
        Wallet walletImplementation = new Wallet();
        walletProxy = new Delegator(address(walletImplementation), "");
        wallet = Wallet(payable(address(walletProxy)));
        wallet.initialize();
        vm.stopPrank();
    }

    function testUpgrade() public {
        vm.startPrank(owner);
        Wallet walletImplementation2 = new Wallet();
        wallet.upgradeTo(address(walletImplementation2));
        bytes32 proxySlot = vm.load(address(wallet), IMPL_SLOT);
        assertEq(
            bytes32(uint256(uint160(address(walletImplementation2)))),
            proxySlot,
            "Implementation should be upgraded"
        );
    }

    function testUpgradeFailedByNotOwner() public {
        vm.startPrank(makeAddr("notOwner"));
        Wallet walletImplementation2 = new Wallet();
        vm.expectRevert("Ownable: caller is not the owner");
        wallet.upgradeTo(address(walletImplementation2));
    }

    function testUpgradeToRandomContractFailed() public {
        vm.startPrank(owner);
        address mockContract = makeAddr("contract");
        vm.etch(mockContract, "");
        vm.expectRevert();
        wallet.upgradeTo(address(mockContract));
    }

    function testDeposit() public {
        vm.startPrank(owner);
        uint sentAmount = 1 ether;
        vm.expectEmit(true, true, false, false);
        emit Deposit(address(owner), sentAmount);
        (bool result, ) = payable(address(wallet)).call{value: sentAmount}("");
        assertEq(result, true, "Deposit should succeed");
        assertEq(
            wallet.checkBalance(),
            sentAmount,
            "Balance should match the sent amount"
        );
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(owner);
        uint sentAmount = 1 ether;
        (bool result, ) = payable(address(wallet)).call{value: sentAmount}("");
        assertEq(result, true, "Deposit should succeed");
        vm.expectEmit(true, true, false, false);
        emit Withdrawal(address(owner), sentAmount);
        bool withdrawResult = wallet.withdraw(sentAmount);
        assertEq(withdrawResult, true, "Withdrawal should succeed");
        assertEq(
            wallet.checkBalance(),
            0,
            "Balance should be zero after withdrawal"
        );
    }

    function testFailWithdrawByNonOwner() public {
        vm.startPrank(owner);
        uint sentAmount = 1 ether;
        (bool result, ) = payable(address(wallet)).call{value: sentAmount}("");
        assertEq(result, true, "Deposit should succeed");
        changePrank(address(this));
        wallet.withdraw(1 ether);
        vm.expectRevert("Ownable: caller is not the owner");
    }

    function testStartRecovery() public {
        vm.startPrank(owner);
        wallet.addRecoveryAddress(recovery1);
        changePrank(recovery1);
        vm.expectEmit(true, false, false, false);
        emit RecoveryStarted(address(recovery1));
        wallet.startRecovery();
    }

    function testStartRecoveryFailedByRandomGuy() public {
        vm.startPrank(owner);
        wallet.addRecoveryAddress(recovery1);
        changePrank(makeAddr("random"));
        vm.expectRevert("Not a recovery address");
        wallet.startRecovery();
    }

    function testStartRecoveryAfterCooldown() public {
        vm.startPrank(owner);
        wallet.addRecoveryAddress(recovery1);
        wallet.addRecoveryAddress(recovery2);

        changePrank(recovery1);
        wallet.startRecovery();

        vm.warp(block.timestamp + COOLDOWN_PERIOD + 1 seconds);

        changePrank(recovery2);

        vm.expectEmit(true, false, false, false);
        emit RecoveryStarted(address(recovery2));

        wallet.startRecovery();
    }

    function testStartRecoveryFailedDuringCooldown() public {
        vm.startPrank(owner);
        wallet.addRecoveryAddress(recovery1);
        wallet.addRecoveryAddress(recovery2);

        changePrank(recovery1);
        vm.expectEmit(true, false, false, false);
        emit RecoveryStarted(address(recovery1));
        wallet.startRecovery();

        changePrank(recovery2);
        vm.warp(block.timestamp + 10 hours);
        vm.expectRevert("Recovery is in cooldown");
        wallet.startRecovery();
    }

    function testRecovery() public {
        vm.startPrank(owner);
        wallet.addRecoveryAddress(recovery1);
        wallet.addRecoveryAddress(recovery2);

        // Owner forget the owner's private key
        changePrank(address(recovery1));
        vm.expectEmit(true, false, false, false);
        emit RecoveryStarted(address(recovery1));
        wallet.startRecovery();
        changePrank(address(recovery2));

        vm.expectEmit(true, false, false, false);
        emit RecoveryAddressConfirmed(address(recovery2));

        vm.expectEmit(true, true, false, false);
        emit OwnerRecovered(address(owner), address(recovery2));
        wallet.confirmRecovery();
        assertEq(
            wallet.owner(),
            recovery2,
            "Owner should be the recovery address"
        );
    }

    function testRecoveryFailedByRandomGuy() public {
        vm.startPrank(owner);
        wallet.addRecoveryAddress(recovery1);

        changePrank(address(recovery1));
        wallet.startRecovery();

        changePrank(makeAddr("random"));

        vm.expectRevert("Not a recovery address");
        wallet.confirmRecovery();
    }

    function testRecoveryFailPeriodExpired() public {
        vm.startPrank(owner);
        wallet.addRecoveryAddress(recovery1);
        wallet.addRecoveryAddress(recovery2);

        // Owner forget the owner's private key
        changePrank(address(recovery1));
        wallet.startRecovery();
        vm.warp(block.timestamp + RECOVERY_PERIOD + 1 seconds);
        changePrank(address(recovery2));
        vm.expectRevert("Recovery period has ended");
        wallet.confirmRecovery();
    }

    function testRecoveryAddressManagement() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, false);
        emit RecoveryAddressAdded(address(recovery1));
        wallet.addRecoveryAddress(recovery1);

        vm.expectEmit(true, false, false, false);
        emit RecoveryAddressAdded(address(recovery2));
        wallet.addRecoveryAddress(recovery2);

        assertEq(
            wallet.isRecoveryAddress(recovery1),
            true,
            "Should be a recovery address"
        );
        assertEq(
            wallet.isRecoveryAddress(recovery2),
            true,
            "Should be a recovery address"
        );

        vm.expectEmit(true, false, false, false);
        emit RecoveryAddressRemoved(address(recovery1));

        wallet.removeRecoveryAddress(recovery1);
        assertEq(
            wallet.isRecoveryAddress(recovery1),
            false,
            "Should not be a recovery address"
        );
    }

    function testRecoveryFailAddressManagementByNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");
        wallet.addRecoveryAddress(recovery1);
    }
}
