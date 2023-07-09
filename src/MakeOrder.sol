// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "./Proxy/Delegate.sol";
import "openzeppelin/token/ERC20/IERC20.sol";
import "./ExchangeManage.sol";
enum OrderType {
    Buy,
    Sell
}

// Owner: Exchange wallet
contract MakeOrder is Delegate {
    struct Order {
        OrderType orderType;
        address trader;
        IERC20 baseToken;
        IERC20 quoteToken;
        uint256 amount;
        uint256 price;
        bool executed;
    }
    uint256 public orderCount = 0;
    uint16 public constant PRICE_DECIMASL = 18;
    ExchangeManage public exchangeManage;

    mapping(uint256 => Order) public orders;

    mapping(address => mapping(address => uint256)) public liabilities;

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

    constructor() {
        _disableInitializers();
    }

    function initialize(address _exchangeManage) public {
        _transferOwnership(msg.sender);
        exchangeManage = ExchangeManage(_exchangeManage);
    }

    function placeOrder(
        OrderType orderType,
        IERC20 baseToken,
        IERC20 quoteToken,
        uint256 amount,
        uint256 price
    ) public returns (uint256 id) {
        require(
            baseToken != quoteToken,
            "Base token and quote token cannot be the same"
        );
        require(
            exchangeManage.isAssetSupported(owner(), address(baseToken)),
            "BaseToken is not supported"
        );
        require(
            exchangeManage.isAssetSupported(owner(), address(quoteToken)),
            "QuoteToken is not supported"
        );

        orderCount++;
        orders[orderCount] = Order({
            orderType: orderType,
            trader: msg.sender,
            baseToken: baseToken,
            quoteToken: quoteToken,
            amount: amount,
            price: price,
            executed: false
        });

        if (orderType == OrderType.Buy) {
            uint256 transferAmount = amount * (price / 10 ** PRICE_DECIMASL);
            liabilities[address(quoteToken)][msg.sender] += transferAmount;
            require(
                quoteToken.allowance(msg.sender, address(this)) >=
                    transferAmount,
                "Not enough allowance for quote token"
            );
            require(
                quoteToken.transferFrom(
                    msg.sender,
                    address(this),
                    transferAmount
                ),
                "Transfer of quote token failed"
            );
        } else {
            liabilities[address(baseToken)][msg.sender] += amount;
            require(
                baseToken.allowance(msg.sender, address(this)) >= amount,
                "Not enough allowance for base token"
            );
            require(
                baseToken.transferFrom(msg.sender, address(this), amount),
                "Transfer of base token failed"
            );
        }
        emit OrderPlaced(orderCount, msg.sender, orderType);
        id = orderCount;
    }

    function executeOrder(uint256 id) public onlyOwner returns (uint256) {
        Order storage order = orders[id];
        require(order.executed == false, "Order already executed");

        order.executed = true;
        OrderType orderType = order.orderType;
        address trader = order.trader;
        IERC20 baseToken = order.baseToken;
        IERC20 quoteToken = order.quoteToken;
        uint256 amount = order.amount;
        uint256 price = order.price;

        if (orderType == OrderType.Buy) {
            uint256 transferedAmount = amount * (price / 10 ** PRICE_DECIMASL);
            liabilities[address(quoteToken)][trader] -= transferedAmount;
            require(
                baseToken.transferFrom(msg.sender, trader, amount),
                "Transfer of base token failed"
            );
            require(
                quoteToken.transfer(msg.sender, transferedAmount),
                "Transfer of quote token failed"
            );
        } else {
            uint256 willTransferAmount = amount *
                (price / 10 ** PRICE_DECIMASL);

            liabilities[address(baseToken)][trader] -= amount;

            require(
                quoteToken.transferFrom(msg.sender, trader, willTransferAmount),
                "Transfer of quote token failed"
            );
            require(
                baseToken.transfer(msg.sender, amount),
                "Transfer of base token failed"
            );
        }
        emit OrderExecuted(id, order.trader, orderType);
        return id;
    }

    function cancelOrder(uint256 id) public returns (uint256) {
        Order storage order = orders[id];
        require(order.executed == false, "Order already executed");
        require(
            msg.sender == order.trader || msg.sender == owner(),
            "Order can only be cancelled by the trader or the owner"
        );

        order.executed = true;
        OrderType orderType = order.orderType;
        address trader = order.trader;
        IERC20 baseToken = order.baseToken;
        IERC20 quoteToken = order.quoteToken;
        uint256 amount = order.amount;
        uint256 price = order.price;

        if (orderType == OrderType.Buy) {
            uint256 transferAmount = amount * (price / 10 ** PRICE_DECIMASL);
            liabilities[address(quoteToken)][trader] -= transferAmount;

            require(
                quoteToken.transfer(address(trader), transferAmount),
                "Transfer of quote token failed"
            );
        } else {
            liabilities[address(baseToken)][trader] -= amount;

            require(
                baseToken.transfer(trader, amount),
                "Transfer of base token failed"
            );
        }

        emit OrderCancelled(id, trader, orderType);
        return id;
    }
}
