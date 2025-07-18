//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {DSCToken} from "src/DSCToken.sol";
import {PoolEngine} from "src/Engine.sol";
import {DeployContract} from "script/DeployContract.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Handler} from "./handler.t.sol";
import {ERC20Mock} from "test/mocks/ERC20.t.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";

contract Invariants is StdInvariant, Test {
    address wethUsd;
    address wbtcUsd;
    Handler i_handler;
    DSCToken i_token;
    PoolEngine i_engine;
    HelperConfig config;
    address weth;
    address wbtc;

    function setUp() public {
        DeployContract deployed = new DeployContract();
        (i_token, i_engine, config) = deployed.run();
        (wbtc, weth, , wethUsd, wbtcUsd) = config.activeNetworkConfig();
        console.log("DSCToken:", address(i_token));
        console.log("PoolEngine:", address(i_engine));
        i_handler = new Handler(i_token, i_engine, weth, wbtc);

        targetContract(address(i_handler));
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupplyDollars()
        public
    {
        uint256 wethAmount = ERC20Mock(weth).balanceOf(address(i_engine));
        uint256 wbtcAmount = ERC20Mock(wbtc).balanceOf(address(i_engine));
        console.log(wethAmount, "WETH AMOUNT -1 ");
        console.log(wbtcAmount, "WBTC AMOUNT -1");
        uint256 usdWeth = i_engine.getCollateralAmountInUsd(
            wethUsd,
            wethAmount
        );
        uint256 usdWbth = i_engine.getCollateralAmountInUsd(
            wbtcUsd,
            wbtcAmount
        );
        console.log(usdWeth, "WETH AMOUNT");
        console.log(usdWbth, "WBTC AMOUNT");

        uint256 supply = i_token.totalSupply();
        console.log(supply, "TOTAL Supply");

        assert(usdWeth + usdWbth > supply);
        // assert(true);
    }
}
