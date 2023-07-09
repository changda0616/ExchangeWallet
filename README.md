# ExchangeWallet

## Description

In the realm of blockchain, centralized exchanges often offer the convenience of superior user interactions and lower transaction fees. However, the bear market has exposed numerous cases of bookkeeping discrepancies, integrity issues, and asset insolvency in many of these exchanges. This highlights the inherent risks users face when they enjoy the benefits of centralized exchanges. The wallet services provided by these exchanges are usually under their custody, meaning users do not have full control over their wallets. In other words, the digital currency held in the wallet is just a figure in the exchange's data center, not necessarily representing an equivalent amount of assets stored in an independent wallet for the user.

Under this premise, self-custody wallets have found a greater voice. Yet, managing a wallet can be quite challenging, and the current self-custody wallets often come with a steep learning curve for blockchain newcomers. It is not as intuitive as logging into an exchange with a ready-to-use wallet.

Therefore, I aim to create a service that allows exchanges to integrate self-custody wallets. Users can choose to manage their assets while still enjoying the conveniences offered by centralized exchanges. I envision this project could bridge the gap between centralized and decentralized services, offering users a higher degree of autonomy and security over their digital assets.

For example, imagine a service where users can toggle between a centralized wallet and a self-custody wallet with just a few clicks. Not only does this preserve the usability of traditional exchanges, but it also introduces a safer alternative where users can secure their assets according to their comfort level and knowledge of blockchain technology.

## Possible Features

- Smart Wallet: Provides a smart contract wallet, giving users full control over the assets in this wallet.
- Asset Transfer Contract: Offers a contract for asset transfers. Upon the user's request, centralized exchanges can transfer assets deposited by users into this smart wallet.
- Spending Management Contract: Allows users to permit a certain amount of assets for a specific time period. Exchanges can use these assets to participate in Web2 or Web3 services, such as investment programs offered by the exchange's team of traders.
- Private Key Recovery Contract: Similar to the "Forgot Password" function in Web2, this contract allows users to recover their account or transfer assets to a new wallet by getting a signature from past connected parties.

These features aim to provide users with a comprehensive tool that allows them to maintain control of their assets while enjoying the benefits and conveniences of participating in a wide range of blockchain services.

## Setting Up Three Accounts to Simulate Roles in the System

This system simulation involves three distinct roles. Each of these roles requires an account setup:

1. **Protocol Owner**: The Protocol Owner role involves owning the ExchangeManage and ExchangeStakePoolFactory.

2. **Exchange Wallet**: This role owns the MakeOrder Contract. In addition to owning, the Exchange Wallet is responsible for creating a staking pool by calling the initStakePool method of ExchangeStakePoolFactory. Each created pool houses an ERC20 token.

3. **User**: A User has the ability to create and own the Wallet Contract, which can be recovered under certain conditions. A User can also make orders through the MakeOrder contract. When the exchange price meets the order's price, the exchange's wallet is signaled to execute the order. Additionally, a User can stake their tokens to participate in exchange events via the ExchangeStakePool.

## How to run

To run this system, follow the steps listed below:

1. Duplicate the file named '.env.example' and rename the copy to '.env'.

2. Provide the necessary keys and wallets for the corresponding role in the '.env' file.

3. Select or activate a blockchain. The instructions below illustrate how to deploy to your local testnet.

   Use the command: `anvil`

4. To deploy the contracts owned by the Exchange or protocol admin, run the following command:

   `forge script script/Exchange.s.sol --rpc-url http://localhost:8545 -vvvv --broadcast`

5. To deploy the contract owned by the Exchange and protocol admin, use the following command:

   `forge script script/Wallet.s.sol --rpc-url http://localhost:8545 -vvvv --broadcast`


## Test Coverage

| File                             | % Lines          | % Statements     | % Branches     | % Funcs        |
|----------------------------------|------------------|------------------|----------------|----------------|
| src/ExchangeManage.sol           | 86.36% (19/22)   | 87.50% (21/24)   | 75.00% (9/12)  | 85.71% (6/7)   |
| src/ExchangeStakePool.sol        | 100.00% (11/11)  | 100.00% (11/11)  | 50.00% (4/8)   | 100.00% (3/3)  |
| src/ExchangeStakePoolFactory.sol | 84.62% (11/13)   | 87.50% (14/16)   | 100.00% (6/6)  | 66.67% (2/3)   |
| src/MakeOrder.sol                | 96.36% (53/55)   | 96.61% (57/59)   | 65.79% (25/38) | 75.00% (3/4)   |
| src/Proxy/Delegate.sol           | 0.00% (0/1)      | 0.00% (0/1)      | 100.00% (0/0)  | 50.00% (1/2)   |
| src/Wallet.sol                   | 100.00% (25/25)  | 100.00% (27/27)  | 91.67% (11/12) | 100.00% (7/7)  |
| script/Exchange.s.sol            | 0.00% (0/27)     | 0.00% (0/44)     | 100.00% (0/0)  | 0.00% (0/2)    |
| script/Wallet.s.sol              | 0.00% (0/6)      | 0.00% (0/10)     | 100.00% (0/0)  | 0.00% (0/2)    |
| Total                            | 74.38% (119/160) | 67.71% (130/192) | 72.37% (55/76) | 73.33% (22/30) |
