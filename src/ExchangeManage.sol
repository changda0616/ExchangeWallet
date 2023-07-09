// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;
import "./Proxy/Delegate.sol";

// owner: Protocol
contract ExchangeManage is Delegate {
    struct Exchange {
        string name;
        address wallet;
        mapping(address => bool) supportAssets;
    }

    event ExchangeAdded(address indexed wallet, address[] indexed assets);
    event ExchangeRemoved(address indexed wallet);
    event SupportedAssetAdded(address indexed wallet, address indexed asset);
    event SupportedAssetRemoved(address indexed wallet, address indexed asset);

    mapping(address => Exchange) public exchanges;

    constructor() {
        _disableInitializers();
    }

    function addExchange(
        string memory name,
        address wallet,
        address[] memory assets
    ) public onlyOwner {
        require(
            exchanges[wallet].wallet == address(0),
            "Exchange already exists"
        );

        Exchange storage exchange = exchanges[wallet];
        exchange.name = name;
        exchange.wallet = wallet;

        for (uint i = 0; i < assets.length; i++) {
            exchange.supportAssets[assets[i]] = true;
        }
        emit ExchangeAdded(wallet, assets);
    }

    function removeExchange(address wallet) public onlyOwner {
        require(
            exchanges[wallet].wallet != address(0),
            "Exchange does not exist"
        );

        delete exchanges[wallet];
        emit ExchangeRemoved(wallet);
    }

    function isExchangeExists(address wallet) public view returns (bool) {
        return exchanges[wallet].wallet != address(0);
    }

    // Get the details of an exchange
    function getExchangeDetails(
        address wallet
    ) public view returns (string memory name, address walletAddress) {
        require(
            exchanges[wallet].wallet != address(0),
            "Exchange does not exist"
        );

        Exchange storage exchange = exchanges[wallet];
        return (exchange.name, exchange.wallet);
    }

    function addSupportedAsset(address asset) public {
        require(
            exchanges[msg.sender].wallet != address(0),
            "Sender is not in the exchange exist"
        );

        exchanges[msg.sender].supportAssets[asset] = true;
        emit SupportedAssetAdded(msg.sender, asset);
    }

    function removeSupportedAsset(address asset) public {
        require(
            exchanges[msg.sender].wallet != address(0),
            "Sender is not in the exchange exist"
        );

        exchanges[msg.sender].supportAssets[asset] = false;
        emit SupportedAssetRemoved(msg.sender, asset);
    }

    function isAssetSupported(
        address wallet,
        address asset
    ) public view returns (bool) {
        require(
            exchanges[wallet].wallet != address(0),
            "Wallet is not in the exchange exist"
        );

        return exchanges[wallet].supportAssets[asset];
    }
}
