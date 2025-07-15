//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DSCToken} from "src/DSCToken.sol";
import {PoolEngine} from "src/Engine.sol";
import {Script} from "forge-std/Script.sol";

contract DeployContract is Script {
    DSCToken internal s_dscToken;
    PoolEngine internal s_engine;
    address[] public _approvedTokens;
    address[] public _tokenPriceFeeds;

    function run() external returns (DSCToken, PoolEngine, HelperConfig) {
        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helper.run();
        vm.startBroadcast(config.deployerKey);
        s_dscToken = new DSCToken();
        _approvedTokens = [config.wbtc, config.weth];
        _tokenPriceFeeds = [config.wethUsdPriceFeed, config.wbtcUsdPriceFeed];
        s_engine = new PoolEngine(
            _approvedTokens,
            _tokenPriceFeeds,
            address(s_dscToken)
        );
        s_dscToken.transferOwnership(address(s_engine));
        vm.stopBroadcast();
        return (s_dscToken, s_engine, helper);
    }
}
