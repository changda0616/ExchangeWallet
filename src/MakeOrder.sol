// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "openzeppelin/token/ERC20/IERC20.sol";
import "openzeppelin/access/Ownable.sol";

// Owner: Exchange wallet
contract MakeOrder is Ownable {
    struct Order {
        address trader;
        IERC20 baseToken;
        IERC20 quoteToken;
        uint256 amount;
        uint256 price;
        bool executed;
    }
    uint256 public orderCount = 0;

    mapping(uint256 => Order) public orders;
    
    mapping(address => mapping(address => uint256)) public liabilities;

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

    event OrderCancelled(uint256 indexed id, address indexed trader);

    function placeOrder(
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
            trader: msg.sender,
            baseToken: baseToken,
            quoteToken: quoteToken,
            amount: amount,
            price: price,
            executed: false
        });

        liabilities[address(baseToken)][msg.sender] += amount;
        require(
            baseToken.transferFrom(msg.sender, address(this), amount),
            "Transfer of base token failed"
        );

        emit OrderPlaced(orderCount, msg.sender, price);
        orderCount++;
    }

    function executeOrder(uint256 id) public onlyOwner {
        Order storage order = orders[id];
        require(order.executed == false, "Order already executed");
        require(
            msg.sender == order.trader,
            "Order can only be executed by the trader"
        );

        order.executed = true;
        emit OrderExecuted(id, order.trader, order.price);

        uint256 quoteAmount = order.amount * order.price;
        liabilities[address(order.baseToken)][order.trader] -= order.amount;

        require(
            order.quoteToken.transfer(order.trader, quoteAmount),
            "Transfer of quote token failed"
        );
    }

    function cancelOrder(uint256 id) public {
        Order storage order = orders[id];
        require(order.executed == false, "Order already executed or cancelled");
        require(
            msg.sender == order.trader || msg.sender == owner(),
            "Order can only be cancelled by the trader or the owner"
        );

        order.executed = true;
        uint256 amountToReturn = order.amount;
        liabilities[address(order.baseToken)][order.trader] -= amountToReturn;

        require(
            order.baseToken.transfer(order.trader, amountToReturn),
            "Transfer of base token failed"
        );

        emit OrderCancelled(id, order.trader);
    }
}
