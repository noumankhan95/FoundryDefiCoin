//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {HelperConfig} from "script/HelperConfig.s.sol";
import {DSCToken} from "src/DSCToken.sol";
import {PoolEngine} from "src/Engine.sol";

contract DeployContract {
    DSCToken internal s_dscToken;
    PoolEngine internal s_engine;
    address[] public _approvedTokens;
    address[] public _tokenPriceFeeds;

    function run()
        external
        returns (DSCToken, PoolEngine, HelperConfig.NetworkConfig memory)
    {
        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helper.run();

        s_dscToken = new DSCToken();
        _approvedTokens = [config.wbtc, config.weth];
        _tokenPriceFeeds = [config.wethUsdPriceFeed, config.wbtcUsdPriceFeed];
        s_engine = new PoolEngine(
            _approvedTokens,
            _tokenPriceFeeds,
            address(s_dscToken)
        );
        s_dscToken.transferOwnership(address(s_engine));
        return (s_dscToken, s_engine, config);
    }
}
