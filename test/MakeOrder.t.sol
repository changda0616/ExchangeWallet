// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/IERC20.sol";

import "forge-std/Test.sol";
import "../src/MakeOrder.sol";
import "../src/ExchangeManage.sol";
import "../src/ERC20/ERC20Token.sol";
import "../src/Proxy/Delegator.sol";

contract MakeOrderTest is Test {
    Delegator delegator;
    MakeOrder makeOrder;
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

    event OrderPlaced(
        uint256 indexed id,
        address indexed trader,
        OrderType indexed orderType
    );
    event OrderExecuted(
        uint256 indexed id,
        address indexed trader,
        OrderType indexed orderType
    );

    event OrderCancelled(
        uint256 indexed id,
        address indexed trader,
        OrderType indexed orderType
    );

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

        changePrank(exchangeOwnedWallet);
        MakeOrder imple = new MakeOrder();
        delegator = new Delegator(address(imple), "");
        makeOrder = MakeOrder(payable(address(delegator)));
        PRICE_DECIMASL = makeOrder.PRICE_DECIMASL();
        makeOrder.initialize(address(exchangeManage));

        bytes32 proxySlot = vm.load(address(makeOrder), IMPL_SLOT);
        assertEq(
            bytes32(uint256(uint160(address(imple)))),
            proxySlot,
            "Implementation should be set"
        );
        assertEq(
            address(makeOrder.owner()),
            address(exchangeOwnedWallet),
            "Owner should be set"
        );

        assertEq(
            address(makeOrder.exchangeManage()),
            address(exchangeManage),
            "ExchangeManage should be set"
        );

        vm.stopPrank();
    }

    function testUpgrade() public {
        vm.startPrank(exchangeOwnedWallet);
        MakeOrder imple2 = new MakeOrder();
        makeOrder.upgradeTo(address(imple2));
        bytes32 proxySlot = vm.load(address(makeOrder), IMPL_SLOT);
        assertEq(
            bytes32(uint256(uint160(address(imple2)))),
            proxySlot,
            "Implementation should be upgraded"
        );
    }

    function testUpgradeFailedByNotOwner() public {
        vm.startPrank(makeAddr("notOwner"));
        MakeOrder imple2 = new MakeOrder();
        vm.expectRevert("Ownable: caller is not the owner");
        makeOrder.upgradeTo(address(imple2));
    }

    function testUpgradeToRandomContractFailed() public {
        vm.startPrank(exchangeOwnedWallet);
        address mockContract = makeAddr("contract");
        vm.etch(mockContract, "");
        vm.expectRevert();
        makeOrder.upgradeTo(address(mockContract));
    }

    function testPlaceBuyOrder() public {
        deal(address(mUSDC), someone, INIT_BALANCE);

        vm.startPrank(someone);
        uint256 limitPriceWithoutMantissa = 1800;
        uint256 limitPrice = limitPriceWithoutMantissa * 10 ** PRICE_DECIMASL;
        uint256 buyAmount = 1 * 10 ** mWethDecimals;
        mUSDC.approve(address(makeOrder), limitPrice);
        vm.expectEmit(true, true, true, true);
        emit OrderPlaced(makeOrder.orderCount() + 1, someone, OrderType.Buy);
        uint256 orderId = makeOrder.placeOrder(
            OrderType.Buy,
            mWeth,
            mUSDC,
            buyAmount,
            limitPrice
        );
        assertEq(orderId, makeOrder.orderCount(), "Order count should be 1");

        (
            OrderType orderType,
            address trader,
            IERC20 baseToken,
            IERC20 quoteToken,
            uint256 amount,
            uint256 price,
            bool executed
        ) = makeOrder.orders(orderId);

        assertEq(
            uint16(orderType),
            uint16(OrderType.Buy),
            "Should be a buy order"
        );
        assertEq(trader, someone, "Trader should be someone");
        assertEq(
            address(baseToken),
            address(mWeth),
            "Base token should be mWeth"
        );
        assertEq(
            address(quoteToken),
            address(mUSDC),
            "Quote token should be mUSDC"
        );
        assertEq(amount, buyAmount, "Should be 1 mWeth to be bought");
        assertEq(
            price,
            limitPrice,
            "The price should be at 1800 USDC to be Sold"
        );
        assertEq(executed, false, "Should not be executed");
        assertEq(
            mUSDC.balanceOf(someone),
            INIT_BALANCE - (amount * limitPriceWithoutMantissa),
            "Balance should be deducted"
        );
        assertEq(
            makeOrder.liabilities(address(mUSDC), someone),
            amount * limitPriceWithoutMantissa,
            "Libilities should be added"
        );
    }

    function testPlaceSellOrder() public {
        deal(address(mWeth), someone, INIT_BALANCE);

        vm.startPrank(someone);
        uint256 limitPriceWithoutMantissa = 1800;
        uint256 limitPrice = limitPriceWithoutMantissa * 10 ** PRICE_DECIMASL;
        uint256 sellAmount = 1 * 10 ** mWethDecimals;
        mWeth.approve(address(makeOrder), limitPrice);
        vm.expectEmit(true, true, true, true);
        emit OrderPlaced(makeOrder.orderCount() + 1, someone, OrderType.Sell);
        uint256 orderId = makeOrder.placeOrder(
            OrderType.Sell,
            mWeth,
            mUSDC,
            sellAmount,
            limitPrice
        );
        assertEq(orderId, makeOrder.orderCount(), "Order count should be 1");

        (
            OrderType orderType,
            address trader,
            IERC20 baseToken,
            IERC20 quoteToken,
            uint256 amount,
            uint256 price,
            bool executed
        ) = makeOrder.orders(orderId);

        assertEq(
            uint16(orderType),
            uint16(OrderType.Sell),
            "Should be a sell order"
        );
        assertEq(trader, someone, "Trader should be someone");
        assertEq(
            address(baseToken),
            address(mWeth),
            "Base token should be mWeth"
        );
        assertEq(
            address(quoteToken),
            address(mUSDC),
            "Quote token should be mUSDC"
        );
        assertEq(amount, sellAmount, "Should be 1 mWeth to be Sold");
        assertEq(
            price,
            limitPrice,
            "The price should be at 1800 USDC to be Bought"
        );
        assertEq(executed, false, "Should not be executed");
        assertEq(
            mWeth.balanceOf(someone),
            INIT_BALANCE - amount,
            "Balance should be deducted"
        );
        assertEq(
            makeOrder.liabilities(address(mWeth), someone),
            amount,
            "Libilities should be added"
        );
    }

    function testPlaceOrderFailWithInvalidPairs() public {
        vm.expectRevert("Base token and quote token cannot be the same");
        uint256 orderId = makeOrder.placeOrder(
            OrderType.Sell,
            mWeth,
            mWeth,
            1,
            1
        );
        vm.expectRevert("BaseToken is not supported");
        makeOrder.placeOrder(
            OrderType.Sell,
            IERC20(makeAddr("token1")),
            mWeth,
            1,
            1
        );
        vm.expectRevert("QuoteToken is not supported");
        makeOrder.placeOrder(
            OrderType.Sell,
            mWeth,
            IERC20(makeAddr("token1")),
            1,
            1
        );
    }

    function testExecuteBuyOrder() public {
        deal(address(mUSDC), someone, INIT_BALANCE);
        deal(address(mWeth), exchangeOwnedWallet, INIT_BALANCE);

        vm.startPrank(someone);
        uint256 limitPriceWithoutMantissa = 1800;
        uint256 limitPrice = limitPriceWithoutMantissa * 10 ** PRICE_DECIMASL;
        uint256 buyAmount = 1 * 10 ** mWethDecimals;
        mUSDC.approve(address(makeOrder), limitPrice);

        uint256 orderId = makeOrder.placeOrder(
            OrderType.Buy,
            mWeth,
            mUSDC,
            buyAmount,
            limitPrice
        );

        uint256 transferedAmount = buyAmount * limitPriceWithoutMantissa;
        changePrank(exchangeOwnedWallet);
        mWeth.approve(address(makeOrder), buyAmount);
        vm.expectEmit(true, true, true, true);
        emit OrderExecuted(orderId, someone, OrderType.Buy);
        uint256 id = makeOrder.executeOrder(orderId);
        assertEq(id, orderId, "Order is should be correct");

        (
            OrderType orderType,
            address trader,
            IERC20 baseToken,
            IERC20 quoteToken,
            uint256 amount,
            uint256 price,
            bool executed
        ) = makeOrder.orders(orderId);
        assertEq(
            makeOrder.liabilities(address(quoteToken), someone),
            0,
            "Liabilities should be deducted"
        );
        assertEq(
            baseToken.balanceOf(someone),
            amount,
            "Someone should get base token"
        );
        assertEq(
            baseToken.balanceOf(exchangeOwnedWallet),
            INIT_BALANCE - amount,
            "ExchangeOwnedWallet should send base token"
        );
        assertEq(
            quoteToken.balanceOf(exchangeOwnedWallet),
            transferedAmount,
            "ExchangeOwnedWallet should get quote token"
        );

        assertEq(executed, true, "Order should be executed");
    }

    function testExecuteSellOrder() public {
        deal(address(mWeth), someone, INIT_BALANCE);
        deal(address(mUSDC), exchangeOwnedWallet, INIT_BALANCE);

        vm.startPrank(someone);
        uint256 limitPriceWithoutMantissa = 1800;
        uint256 limitPrice = limitPriceWithoutMantissa * 10 ** PRICE_DECIMASL;
        uint256 sellAmount = 1 * 10 ** mWethDecimals;

        mWeth.approve(address(makeOrder), limitPrice);

        uint256 orderId = makeOrder.placeOrder(
            OrderType.Sell,
            mWeth,
            mUSDC,
            sellAmount,
            limitPrice
        );

        uint256 transferedAmount = sellAmount * limitPriceWithoutMantissa;

        changePrank(exchangeOwnedWallet);
        mUSDC.approve(address(makeOrder), transferedAmount);
        vm.expectEmit(true, true, true, true);
        emit OrderExecuted(orderId, someone, OrderType.Sell);
        uint256 id = makeOrder.executeOrder(orderId);
        assertEq(id, orderId, "Order is should be correct");

        (
            OrderType orderType,
            address trader,
            IERC20 baseToken,
            IERC20 quoteToken,
            uint256 amount,
            uint256 price,
            bool executed
        ) = makeOrder.orders(orderId);
        assertEq(
            makeOrder.liabilities(address(baseToken), someone),
            0,
            "Liabilities should be deducted"
        );
        assertEq(
            quoteToken.balanceOf(someone),
            transferedAmount,
            "Someone should get quote token"
        );
        assertEq(
            quoteToken.balanceOf(exchangeOwnedWallet),
            INIT_BALANCE - transferedAmount,
            "ExchangeOwnedWallet should send base token"
        );
        assertEq(
            baseToken.balanceOf(exchangeOwnedWallet),
            amount,
            "ExchangeOwnedWallet should get base token"
        );
        assertEq(executed, true, "Order should be executed");
    }

    function testExecuteOrderFail() public {
        deal(address(mWeth), someone, INIT_BALANCE);
        deal(address(mUSDC), exchangeOwnedWallet, INIT_BALANCE);

        vm.startPrank(someone);
        uint256 limitPriceWithoutMantissa = 1800;
        uint256 limitPrice = limitPriceWithoutMantissa * 10 ** PRICE_DECIMASL;
        uint256 sellAmount = 1 * 10 ** mWethDecimals;

        mWeth.approve(address(makeOrder), limitPrice);

        uint256 orderId = makeOrder.placeOrder(
            OrderType.Sell,
            mWeth,
            mUSDC,
            sellAmount,
            limitPrice
        );

        (
            OrderType orderType,
            address trader,
            IERC20 baseToken,
            IERC20 quoteToken,
            uint256 amount,
            uint256 price,
            bool executed
        ) = makeOrder.orders(orderId);
        uint256 transferedAmount = amount * (price / 10 ** PRICE_DECIMASL);

        changePrank(makeAddr("someoneelse"));
        vm.expectRevert("Ownable: caller is not the owner");
        makeOrder.executeOrder(orderId);
        changePrank(exchangeOwnedWallet);
        mUSDC.approve(address(makeOrder), transferedAmount);

        makeOrder.executeOrder(orderId);
        vm.expectRevert("Order already executed");
        makeOrder.executeOrder(orderId);
    }

    function testCancelBuyOrder() public {
        deal(address(mUSDC), someone, INIT_BALANCE);
        deal(address(mWeth), exchangeOwnedWallet, INIT_BALANCE);

        vm.startPrank(someone);
        uint256 limitPriceWithoutMantissa = 1800;
        uint256 limitPrice = limitPriceWithoutMantissa * 10 ** PRICE_DECIMASL;
        uint256 buyAmount = 1 * 10 ** mWethDecimals;
        mUSDC.approve(address(makeOrder), limitPrice);

        uint256 orderId = makeOrder.placeOrder(
            OrderType.Buy,
            mWeth,
            mUSDC,
            buyAmount,
            limitPrice
        );
        assertEq(
            mUSDC.balanceOf(someone),
            INIT_BALANCE - buyAmount * limitPriceWithoutMantissa,
            "WEth balance of someone should be deducted"
        );
        vm.expectEmit(true, true, true, true);
        emit OrderCancelled(orderId, someone, OrderType.Buy);
        uint256 id = makeOrder.cancelOrder(orderId);
        assertEq(id, orderId, "Order is should be correct");
        (
            OrderType orderType,
            address trader,
            IERC20 baseToken,
            IERC20 quoteToken,
            uint256 amount,
            uint256 price,
            bool executed
        ) = makeOrder.orders(orderId);
        assertEq(executed, true, "Order should be executed");
        assertEq(
            makeOrder.liabilities(address(quoteToken), someone),
            0,
            "Liabilities should be deducted"
        );
        assertEq(
            quoteToken.balanceOf(someone),
            INIT_BALANCE,
            "Trader should get base token"
        );
        vm.expectRevert("Order already executed");
        makeOrder.cancelOrder(orderId);
    }

    function testCancelSellOrder() public {
        deal(address(mWeth), someone, INIT_BALANCE);
        deal(address(mUSDC), exchangeOwnedWallet, INIT_BALANCE);

        vm.startPrank(someone);
        uint256 limitPriceWithoutMantissa = 1800;
        uint256 limitPrice = limitPriceWithoutMantissa * 10 ** PRICE_DECIMASL;
        uint256 sellAmount = 1 * 10 ** mWethDecimals;

        mWeth.approve(address(makeOrder), limitPrice);

        uint256 orderId = makeOrder.placeOrder(
            OrderType.Sell,
            mWeth,
            mUSDC,
            sellAmount,
            limitPrice
        );
        assertEq(
            mWeth.balanceOf(someone),
            INIT_BALANCE - sellAmount,
            "WEth balance of someone should be deducted"
        );
        vm.expectEmit(true, true, true, true);
        emit OrderCancelled(orderId, someone, OrderType.Sell);
        uint256 id = makeOrder.cancelOrder(orderId);
        assertEq(id, orderId, "Order is should be correct");
        (
            OrderType orderType,
            address trader,
            IERC20 baseToken,
            IERC20 quoteToken,
            uint256 amount,
            uint256 price,
            bool executed
        ) = makeOrder.orders(orderId);
        assertEq(executed, true, "Order should be executed");
        assertEq(
            makeOrder.liabilities(address(quoteToken), someone),
            0,
            "Liabilities should be deducted"
        );
        assertEq(
            baseToken.balanceOf(someone),
            INIT_BALANCE,
            "Trader should get base token"
        );

        vm.expectRevert("Order already executed");
        makeOrder.cancelOrder(orderId);
    }

    function testCancelOrderByExchangeWallet() public {
        deal(address(mWeth), someone, INIT_BALANCE);
        deal(address(mUSDC), exchangeOwnedWallet, INIT_BALANCE);

        vm.startPrank(someone);
        uint256 limitPriceWithoutMantissa = 1800;
        uint256 limitPrice = limitPriceWithoutMantissa * 10 ** PRICE_DECIMASL;
        uint256 sellAmount = 1 * 10 ** mWethDecimals;

        mWeth.approve(address(makeOrder), limitPrice);

        uint256 orderId = makeOrder.placeOrder(
            OrderType.Sell,
            mWeth,
            mUSDC,
            sellAmount,
            limitPrice
        );
        assertEq(
            mWeth.balanceOf(someone),
            INIT_BALANCE - sellAmount,
            "WEth balance of someone should be deducted"
        );
        changePrank(exchangeOwnedWallet);
        uint256 id = makeOrder.cancelOrder(orderId);
        assertEq(id, orderId, "Order is should be correct");
        (
            OrderType orderType,
            address trader,
            IERC20 baseToken,
            IERC20 quoteToken,
            uint256 amount,
            uint256 price,
            bool executed
        ) = makeOrder.orders(orderId);
        assertEq(executed, true, "Order should be executed");
        assertEq(
            makeOrder.liabilities(address(quoteToken), someone),
            0,
            "Liabilities should be deducted"
        );
        assertEq(
            baseToken.balanceOf(someone),
            INIT_BALANCE,
            "Trader should get base token"
        );

        vm.expectRevert("Order already executed");
        makeOrder.cancelOrder(orderId);
    }

    function testCancelOrderFailByRandomEOA() public {
        deal(address(mWeth), someone, INIT_BALANCE);
        deal(address(mUSDC), exchangeOwnedWallet, INIT_BALANCE);

        vm.startPrank(someone);
        uint256 limitPriceWithoutMantissa = 1800;
        uint256 limitPrice = limitPriceWithoutMantissa * 10 ** PRICE_DECIMASL;
        uint256 sellAmount = 1 * 10 ** mWethDecimals;

        mWeth.approve(address(makeOrder), limitPrice);

        uint256 orderId = makeOrder.placeOrder(
            OrderType.Sell,
            mWeth,
            mUSDC,
            sellAmount,
            limitPrice
        );
        assertEq(
            mWeth.balanceOf(someone),
            INIT_BALANCE - sellAmount,
            "WEth balance of someone should be deducted"
        );
        changePrank(makeAddr("someoneelse"));
        vm.expectRevert(
            "Order can only be cancelled by the trader or the owner"
        );
        uint256 id = makeOrder.cancelOrder(orderId);
    }
}
