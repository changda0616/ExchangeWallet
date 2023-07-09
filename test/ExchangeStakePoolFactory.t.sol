// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "../src/ERC20/ERC20Token.sol";

import "../src/Proxy/Delegator.sol";

import "../src/ExchangeStakePoolFactory.sol";
import "../src/ExchangeStakePool.sol";

import "../src/ExchangeManage.sol";

contract ExchangeStakePoolFactoryTest is Test {
    Delegator delegator;
    ExchangeStakePoolFactory exchangeStakePoolFactory;
    Delegator exchangeManageDelegator;
    ExchangeManage exchangeManage;

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

    event PoolInit(address indexed exchange);

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
        bytes32 proxySlot = vm.load(
            address(exchangeStakePoolFactory),
            IMPL_SLOT
        );
        assertEq(
            bytes32(uint256(uint160(address(imple)))),
            proxySlot,
            "Implementation should be set"
        );
        assertEq(
            address(exchangeStakePoolFactory.owner()),
            address(protoclAdmin),
            "Owner should be set"
        );

        assertEq(
            address(exchangeStakePoolFactory.exchangeManage()),
            address(exchangeManage),
            "ExchangeManage should be set"
        );

        vm.stopPrank();
    }

    function testUpgrade() public {
        vm.startPrank(protoclAdmin);
        ExchangeStakePoolFactory imple2 = new ExchangeStakePoolFactory();
        exchangeStakePoolFactory.upgradeTo(address(imple2));
        bytes32 proxySlot = vm.load(
            address(exchangeStakePoolFactory),
            IMPL_SLOT
        );
        assertEq(
            bytes32(uint256(uint160(address(imple2)))),
            proxySlot,
            "Implementation should be upgraded"
        );
    }

    function testUpgradeFailedByNotOwner() public {
        vm.startPrank(makeAddr("notOwner"));
        ExchangeStakePoolFactory imple2 = new ExchangeStakePoolFactory();
        vm.expectRevert("Ownable: caller is not the owner");
        exchangeStakePoolFactory.upgradeTo(address(imple2));
    }

    function testUpgradeToRandomContractFailed() public {
        vm.startPrank(protoclAdmin);
        address mockContract = makeAddr("contract");
        vm.etch(mockContract, "");
        vm.expectRevert();
        exchangeStakePoolFactory.upgradeTo(address(mockContract));
    }

    function testInitStakePool() public {
        vm.startPrank(exchangeOwnedWallet);

        address pool = exchangeStakePoolFactory.initStakePool(address(mWeth));
        ExchangeStakePool exchangeStakePool = ExchangeStakePool(pool);
        assertEq(address(exchangeStakePool.owner()), exchangeOwnedWallet);
        assertEq(address(exchangeStakePool.token()), address(mWeth));
        assertEq(
            address(
                exchangeStakePoolFactory.getStakingPool(
                    exchangeOwnedWallet,
                    address(mWeth)
                )
            ),
            pool
        );

        address pool2 = exchangeStakePoolFactory.initStakePool(address(mUSDC));
        ExchangeStakePool exchangeStakePool2 = ExchangeStakePool(pool2);
        assertEq(address(exchangeStakePool2.owner()), exchangeOwnedWallet);
        assertEq(address(exchangeStakePool2.token()), address(mUSDC));
        assertEq(
            address(
                exchangeStakePoolFactory.getStakingPool(
                    exchangeOwnedWallet,
                    address(mUSDC)
                )
            ),
            pool2
        );
    }

    function testInitStakePoolFailByNotSupportedWallet() public {
        vm.startPrank(makeAddr("random"));
        vm.expectRevert("Exchange is not in the list");
        address pool = exchangeStakePoolFactory.initStakePool(address(mUSDC));
    }

    function testInitStakePoolFailByNotSupportToken() public {
        vm.startPrank(exchangeOwnedWallet);
        exchangeManage.removeSupportedAsset(address(mUSDC));
        vm.expectRevert("Asset is not supported");
        address pool = exchangeStakePoolFactory.initStakePool(address(mUSDC));
    }

    function testInitStakePoolFailByInitTwice() public {
        vm.startPrank(exchangeOwnedWallet);
        address pool = exchangeStakePoolFactory.initStakePool(address(mWeth));
        vm.expectRevert("Pool already created for this exchange");
        exchangeStakePoolFactory.initStakePool(address(mWeth));
    }
}
