// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract ExchangeManage {
    struct Exchange {
        address wallet;
        string name;
        mapping(address => bool) supportAssets;
    }

    mapping(address => Exchange) public exchanges;

    function addExchange(string memory name, address wallet, address[] memory assets) public {
        require(exchanges[wallet].wallet == address(0), "Exchange already exists");

        Exchange storage exchange = exchanges[wallet];
        exchange.name = name;
        exchange.wallet = wallet;
        
        for(uint i = 0; i < assets.length; i++) {
            exchange.supportAssets[assets[i]] = true;
        }
    }

    function removeExchange(address wallet) public {
        require(exchanges[wallet].wallet != address(0), "Exchange does not exist");

        delete exchanges[wallet];
    }

    function isExchangeExists(address wallet) public view returns(bool) {
        return exchanges[wallet].wallet != address(0);
    }

    // Get the details of an exchange
    function getExchangeDetails(address wallet) public view returns (string memory name, address walletAddress) {
        require(exchanges[wallet].wallet != address(0), "Exchange does not exist");

        Exchange storage exchange = exchanges[wallet];
        return (exchange.name, exchange.wallet);
    }

    function addSupportedAsset(address wallet, address asset) public {
        require(exchanges[wallet].wallet != address(0), "Exchange does not exist");

        exchanges[wallet].supportAssets[asset] = true;
    }

    function removeSupportedAsset(address wallet, address asset) public {
        require(exchanges[wallet].wallet != address(0), "Exchange does not exist");

        exchanges[wallet].supportAssets[asset] = false;
    }

    function isAssetSupported(address wallet, address asset) public view returns(bool) {
        require(exchanges[wallet].wallet != address(0), "Exchange does not exist");

        return exchanges[wallet].supportAssets[asset];
    }
}
