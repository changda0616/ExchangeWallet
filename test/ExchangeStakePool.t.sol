// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "../src/ERC20/ERC20Token.sol";

import "../src/Proxy/Delegator.sol";

import "../src/ExchangeStakePoolFactory.sol";
import "../src/ExchangeStakePool.sol";

import "../src/ExchangeManage.sol";

contract ExchangeStakePoolTest is Test {
    Delegator delegator;
    ExchangeStakePoolFactory exchangeStakePoolFactory;
    Delegator exchangeManageDelegator;
    ExchangeManage exchangeManage;

    ExchangeStakePool exchangeStakePool;

    ERC20Token mUSDC = new ERC20Token("Mock USDC", "mUSDC");
    ERC20Token mWeth = new ERC20Token("Mock Weth", "mWeth");
    uint256 mUSDCDecimals = mUSDC.decimals();
    uint256 mWethDecimals = mWeth.decimals();

    struct Order {
        address trader;
        IERC20 baseToken;
        IERC20 quoteToken;
        uint256 amount;
        uint256 price;
        bool executed;
    }

    address protoclAdmin = makeAddr("protoclAdmin");
    address exchangeOwnedWallet = makeAddr("exchangeOwnedWallet");
    address someone = makeAddr("someone");
    uint16 PRICE_DECIMASL;

    uint256 constant INIT_BALANCE = 5000 ether;

    event Staked(address indexed user, uint256 indexed amount);
    event Unstaked(address indexed user, uint256 indexed amount);

    bytes32 internal constant IMPL_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1); // 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc

    function setUp() public {
        vm.label(protoclAdmin, "protoclAdmin");
        vm.label(exchangeOwnedWallet, "exchangeOwnedWallet");
        vm.label(someone, "someone");
        vm.label(address(this), "This");

        vm.deal(someone, INIT_BALANCE);

        vm.startPrank(protoclAdmin);
        ExchangeManage exchangeManageImple = new ExchangeManage();
        exchangeManageDelegator = new Delegator(
            address(exchangeManageImple),
            ""
        );
        exchangeManage = ExchangeManage(
            payable(address(exchangeManageDelegator))
        );
        exchangeManage.initialize();

        address[] memory tokenList = new address[](2);
        tokenList[0] = address(mUSDC);
        tokenList[1] = address(mWeth);
        exchangeManage.addExchange(
            "Exchange 1",
            exchangeOwnedWallet,
            tokenList
        );

        ExchangeStakePoolFactory imple = new ExchangeStakePoolFactory();
        delegator = new Delegator(address(imple), "");
        exchangeStakePoolFactory = ExchangeStakePoolFactory(
            payable(address(delegator))
        );

        exchangeStakePoolFactory.initialize(address(exchangeManage));
        changePrank(exchangeOwnedWallet);
        exchangeStakePool = ExchangeStakePool(
            payable(exchangeStakePoolFactory.initStakePool(address(mWeth)))
        );

        assertEq(
            address(exchangeStakePool.owner()),
            address(exchangeOwnedWallet),
            "Owner should be set"
        );

        vm.stopPrank();
    }

    function testUpgrade() public {
        vm.startPrank(exchangeOwnedWallet);
        ExchangeStakePool imple2 = new ExchangeStakePool();
        exchangeStakePool.upgradeTo(address(imple2));
        bytes32 proxySlot = vm.load(address(exchangeStakePool), IMPL_SLOT);
        assertEq(
            bytes32(uint256(uint160(address(imple2)))),
            proxySlot,
            "Implementation should be upgraded"
        );
    }

    function testUpgradeFailedByNotOwner() public {
        vm.startPrank(makeAddr("notOwner"));
        ExchangeStakePool imple2 = new ExchangeStakePool();
        vm.expectRevert("Ownable: caller is not the owner");
        exchangeStakePool.upgradeTo(address(imple2));
    }

    function testUpgradeToRandomContractFailed() public {
        vm.startPrank(protoclAdmin);
        address mockContract = makeAddr("contract");
        vm.etch(mockContract, "");
        vm.expectRevert();
        exchangeStakePool.upgradeTo(address(mockContract));
    }

    function testStake() public {
        deal(address(mWeth), someone, INIT_BALANCE);
        vm.startPrank(someone);
        uint256 stakeAmount = 1000 ether;
        mWeth.approve(address(exchangeStakePool), stakeAmount);

        vm.expectEmit(true, true, true, false);
        emit Staked(someone, stakeAmount);
        exchangeStakePool.stake(stakeAmount);
        assertEq(
            exchangeStakePool.userStakes(someone),
            stakeAmount,
            "Should stake 1000 wEth"
        );
        assertEq(
            mWeth.balanceOf(someone),
            INIT_BALANCE - stakeAmount,
            "Balance should be deducted"
        );
    }

    function testStakeFail() public {
        deal(address(mWeth), someone, INIT_BALANCE);
        vm.startPrank(someone);
        uint256 stakeAmount = INIT_BALANCE + 1000 ether;
        mWeth.approve(address(exchangeStakePool), stakeAmount);

        vm.expectRevert("ERC20: transfer amount exceeds balance");
        exchangeStakePool.stake(stakeAmount);
    }

    function testUnStake() public {
        deal(address(mWeth), someone, INIT_BALANCE);
        vm.startPrank(someone);
        uint256 stakeAmount = 1000 ether;
        mWeth.approve(address(exchangeStakePool), stakeAmount);

        exchangeStakePool.stake(stakeAmount);
        assertEq(
            exchangeStakePool.userStakes(someone),
            stakeAmount,
            "Should stake 1000 wEth"
        );
        assertEq(
            mWeth.balanceOf(someone),
            INIT_BALANCE - stakeAmount,
            "Balance should be deducted"
        );
        exchangeStakePool.unstake(stakeAmount);
        assertEq(
            exchangeStakePool.userStakes(someone),
            0,
            "Staked amount should be deducted"
        );
        assertEq(
            mWeth.balanceOf(someone),
            INIT_BALANCE,
            "Balance should be added"
        );
    }
}
