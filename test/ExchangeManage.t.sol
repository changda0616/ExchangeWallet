// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin/token/ERC20/IERC20.sol";

import "forge-std/Test.sol";
import "../src/ExchangeManage.sol";
import "../src/ERC20/ERC20Token.sol";
import "../src/Proxy/Delegator.sol";

contract ExchangeManageTest is Test {
    struct Exchange {
        address wallet;
        string name;
        mapping(address => bool) supportAssets;
    }
    Delegator delegator;
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

    uint256 constant INIT_BALANCE = 5000 ether;

    bytes32 internal constant IMPL_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1); // 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc

    event ExchangeAdded(address indexed wallet, address[] indexed assets);
    event ExchangeRemoved(address indexed wallet);
    event SupportedAssetAdded(address indexed wallet, address indexed asset);
    event SupportedAssetRemoved(address indexed wallet, address indexed asset);

    function setUp() public {
        vm.label(protoclAdmin, "protoclAdmin");
        vm.label(exchangeOwnedWallet, "exchangeOwnedWallet");
        vm.label(someone, "someone");
        vm.label(address(this), "This");

        vm.deal(someone, INIT_BALANCE);

        vm.startPrank(protoclAdmin);
        ExchangeManage imple = new ExchangeManage();
        delegator = new Delegator(address(imple), "");
        exchangeManage = ExchangeManage(payable(address(delegator)));
        exchangeManage.initialize();
        bytes32 proxySlot = vm.load(address(exchangeManage), IMPL_SLOT);
        assertEq(
            bytes32(uint256(uint160(address(imple)))),
            proxySlot,
            "Implementation should be set"
        );
        assertEq(
            address(exchangeManage.owner()),
            address(protoclAdmin),
            "Owner should be set"
        );
        vm.stopPrank();
    }

    function testUpgrade() public {
        vm.startPrank(protoclAdmin);
        ExchangeManage imple2 = new ExchangeManage();
        exchangeManage.upgradeTo(address(imple2));
        bytes32 proxySlot = vm.load(address(exchangeManage), IMPL_SLOT);
        assertEq(
            bytes32(uint256(uint160(address(imple2)))),
            proxySlot,
            "Implementation should be upgraded"
        );
    }

    function testUpgradeFailedByNotOwner() public {
        vm.startPrank(makeAddr("notOwner"));
        ExchangeManage imple2 = new ExchangeManage();
        vm.expectRevert("Ownable: caller is not the owner");
        exchangeManage.upgradeTo(address(imple2));
    }

    function testUpgradeToRandomContractFailed() public {
        vm.startPrank(protoclAdmin);
        address mockContract = makeAddr("contract");
        vm.etch(mockContract, "");
        vm.expectRevert();
        exchangeManage.upgradeTo(address(mockContract));
    }

    function testAddExchange() public {
        vm.startPrank(protoclAdmin);
        address[] memory tokenList = new address[](2);
        tokenList[0] = address(mUSDC);
        tokenList[1] = address(mWeth);
        vm.expectEmit(true, true, true, false);
        emit ExchangeAdded(exchangeOwnedWallet, tokenList);
        exchangeManage.addExchange(
            "Exchange 1",
            exchangeOwnedWallet,
            tokenList
        );
        assertEq(
            exchangeManage.isExchangeExists(exchangeOwnedWallet),
            true,
            "Exchange should be added"
        );

        (string memory name, address wallet) = exchangeManage.exchanges(
            exchangeOwnedWallet
        );
        assertEq(name, "Exchange 1", "Exchange name should be set");
        assertEq(wallet, exchangeOwnedWallet, "Exchange wallet should be set");
        assertEq(
            exchangeManage.isAssetSupported(
                exchangeOwnedWallet,
                address(mUSDC)
            ),
            true,
            "USDC should be supported"
        );
        assertEq(
            exchangeManage.isAssetSupported(
                exchangeOwnedWallet,
                address(mWeth)
            ),
            true,
            "USDC should be supported"
        );
    }

    function testAddExchangeFail() public {
        vm.startPrank(someone);
        address[] memory tokenList = new address[](2);
        tokenList[0] = address(mUSDC);
        tokenList[1] = address(mWeth);
        vm.expectRevert("Ownable: caller is not the owner");
        exchangeManage.addExchange(
            "Exchange 1",
            exchangeOwnedWallet,
            tokenList
        );
        changePrank(protoclAdmin);
        exchangeManage.addExchange(
            "Exchange 1",
            exchangeOwnedWallet,
            tokenList
        );
        assertEq(
            exchangeManage.isExchangeExists(exchangeOwnedWallet),
            true,
            "Exchange should be added"
        );
        vm.expectRevert("Exchange already exists");
        exchangeManage.addExchange(
            "Exchange 1",
            exchangeOwnedWallet,
            tokenList
        );
    }

    function testRemoveExchange() public {
        vm.startPrank(protoclAdmin);
        address[] memory tokenList = new address[](2);
        tokenList[0] = address(mUSDC);
        tokenList[1] = address(mWeth);
        exchangeManage.addExchange(
            "Exchange 1",
            exchangeOwnedWallet,
            tokenList
        );
        assertEq(
            exchangeManage.isExchangeExists(exchangeOwnedWallet),
            true,
            "Exchange should be added"
        );
        vm.expectEmit(true, true, false, false);
        emit ExchangeRemoved(exchangeOwnedWallet);
        exchangeManage.removeExchange(exchangeOwnedWallet);
        assertEq(
            exchangeManage.isExchangeExists(exchangeOwnedWallet),
            false,
            "Exchange should be added"
        );
    }

    function testRemoveExchangeFail() public {
        vm.startPrank(protoclAdmin);
        vm.expectRevert("Exchange does not exist");
        exchangeManage.removeExchange(exchangeOwnedWallet);

        address[] memory tokenList = new address[](2);
        tokenList[0] = address(mUSDC);
        tokenList[1] = address(mWeth);
        exchangeManage.addExchange(
            "Exchange 1",
            exchangeOwnedWallet,
            tokenList
        );

        assertEq(
            exchangeManage.isExchangeExists(exchangeOwnedWallet),
            true,
            "Exchange should be added"
        );
        changePrank(someone);
        vm.expectRevert("Ownable: caller is not the owner");
        exchangeManage.addExchange(
            "Exchange 1",
            exchangeOwnedWallet,
            tokenList
        );
    }

    function testAddSupportedAsset() public {
        vm.startPrank(protoclAdmin);
        address[] memory tokenList = new address[](1);
        tokenList[0] = address(mUSDC);
        exchangeManage.addExchange(
            "Exchange 1",
            exchangeOwnedWallet,
            tokenList
        );
        assertEq(
            exchangeManage.isAssetSupported(
                exchangeOwnedWallet,
                address(mWeth)
            ),
            false,
            "mWeth is not supported"
        );
        changePrank(exchangeOwnedWallet);
        vm.expectEmit(true, true, true, true);
        emit SupportedAssetAdded(exchangeOwnedWallet, address(mWeth));
        exchangeManage.addSupportedAsset(address(mWeth));
        assertEq(
            exchangeManage.isAssetSupported(
                exchangeOwnedWallet,
                address(mWeth)
            ),
            true,
            "mWeth should be supported"
        );
    }

    function testAddSupportedAssetFail() public {
        vm.startPrank(protoclAdmin);
        vm.expectRevert("Sender is not in the exchange exist");
        exchangeManage.addSupportedAsset(address(mWeth));

        address[] memory tokenList = new address[](1);
        tokenList[0] = address(mUSDC);
        exchangeManage.addExchange(
            "Exchange 1",
            exchangeOwnedWallet,
            tokenList
        );
        vm.expectRevert("Sender is not in the exchange exist");
        exchangeManage.addSupportedAsset(address(mWeth));
    }

    function testRemoveSupportedAsset() public {
        vm.startPrank(protoclAdmin);
        address[] memory tokenList = new address[](2);
        tokenList[0] = address(mUSDC);
        tokenList[1] = address(mWeth);
        exchangeManage.addExchange(
            "Exchange 1",
            exchangeOwnedWallet,
            tokenList
        );
        assertEq(
            exchangeManage.isAssetSupported(
                exchangeOwnedWallet,
                address(mWeth)
            ),
            true,
            "mWeth is supported"
        );
        changePrank(exchangeOwnedWallet);
        vm.expectEmit(true, true, true, false);
        emit SupportedAssetRemoved(exchangeOwnedWallet, address(mWeth));
        exchangeManage.removeSupportedAsset(address(mWeth));
        assertEq(
            exchangeManage.isAssetSupported(
                exchangeOwnedWallet,
                address(mWeth)
            ),
            false,
            "mWeth should not be supported"
        );
    }

    function testRemoveSupportedAssetFail() public {
        vm.startPrank(protoclAdmin);
        address[] memory tokenList = new address[](1);
        tokenList[0] = address(mUSDC);
        exchangeManage.addExchange(
            "Exchange 1",
            exchangeOwnedWallet,
            tokenList
        );
        vm.expectRevert("Sender is not in the exchange exist");
        exchangeManage.removeSupportedAsset(address(mWeth));
    }
}
