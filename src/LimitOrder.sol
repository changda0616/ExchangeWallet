// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "openzeppelin/token/ERC20/IERC20.sol";

contract LimitOrderContract {
    struct Order {
        address trader;
        IERC20 baseToken;
        IERC20 quoteToken;
        uint256 amount;
        uint256 price;
        bool executed;
    }

    mapping(uint256 => Order) public orders;
    uint256 public orderCount = 0;

    event OrderPlaced(
        uint256 indexed id,
        address indexed trader,
        uint256 indexed price
    );
    event OrderExecuted(
        uint256 indexed id,
        address indexed trader,
        uint256 indexed price
    );

    // We can only do limit sell for now
    function placeOrder(
        address trader,
        IERC20 baseToken,
        IERC20 quoteToken,
        uint256 amount,
        uint256 price
    ) public {
        require(
            baseToken != quoteToken,
            "Base token and quote token cannot be the same"
        );
        require(
            baseToken.allowance(msg.sender, address(this)) >= amount,
            "Not enough allowance for base token"
        );

        orders[orderCount] = Order({
            trader: trader,
            baseToken: baseToken,
            quoteToken: quoteToken,
            amount: amount,
            price: price,
            executed: false
        });

        emit OrderPlaced(orderCount, trader, price);
        orderCount++;
    }

    function executeOrder(uint256 id) public {
        Order storage order = orders[id];
        require(order.executed == false, "Order already executed");
        require(
            msg.sender == order.trader,
            "Order can only be executed by the trader"
        );

        order.executed = true;
        emit OrderExecuted(id, order.trader, order.price);

        require(
            order.baseToken.transferFrom(
                msg.sender,
                order.trader,
                order.amount
            ),
            "Transfer of base token failed"
        );

        uint256 quoteAmount = order.amount * order.price;
        require(
            order.quoteToken.transfer(msg.sender, quoteAmount),
            "Transfer of quote token failed"
        );
    }
}
