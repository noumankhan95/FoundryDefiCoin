//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {Test} from "forge-std/Test.sol";
import {DSCToken} from "src/DSCToken.sol";
import {PoolEngine} from "src/Engine.sol";
import {DeployContract} from "script/DeployContract.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";

contract DSCTest is Test {
    DSCToken token;
    PoolEngine pool;
    HelperConfig config;
    HelperConfig.NetworkConfig public activeNetwork;

    function setUp() external {
        (token, pool, config) = new DeployContract().run();
        (
            activeNetwork.wbtc,
            activeNetwork.weth,
            activeNetwork.deployerKey,
            activeNetwork.wethUsdPriceFeed,
            activeNetwork.wbtcUsdPriceFeed
        ) = config.activeNetworkConfig();
    }

    address[] public _priceFeeds;
    address[] public _approvedTokens;

    function testConstructorThrowsErrorifArraysLengthUnequal() public {
        _priceFeeds = [
            activeNetwork.wethUsdPriceFeed,
            activeNetwork.wbtcUsdPriceFeed
        ];
        _approvedTokens = [activeNetwork.weth];
        vm.expectRevert(
            PoolEngine.PoolEngine__PriceFeedAndTokenLengthNotEqual.selector
        );
        new PoolEngine(_approvedTokens, _priceFeeds, address(token));
    }
}
