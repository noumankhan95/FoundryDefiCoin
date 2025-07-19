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
    HelperConfig.NetworkConfig config;
    address weth;
    address wbtc;

    function setUp() public {
        DeployContract deployed = new DeployContract();
        (i_token, i_engine, config) = deployed.run();

        weth = config.weth;
        wbtc = config.wbtc;
        wethUsd = config.wethUsdPriceFeed;
        wbtcUsd = config.wbtcUsdPriceFeed;

        console.log("DSCToken:", address(i_token));
        console.log("PoolEngine:", address(i_engine));

        i_handler = new Handler(
            i_token,
            i_engine,
            weth,
            wbtc,
            wethUsd,
            wbtcUsd
        );
        bytes4[] memory _selectors = new bytes4[](2);
        _selectors[0] = i_handler.mintAndDepositCollateral.selector;
        _selectors[1] = i_handler.redeemCollateral.selector;
        targetSelector(
            FuzzSelector({addr: address(i_handler), selectors: _selectors})
        );
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
        uint256 usdWbtc = i_engine.getCollateralAmountInUsd(
            wbtcUsd,
            wbtcAmount
        );

        console.log(usdWeth, "WETH AMOUNT");
        console.log(usdWbtc, "WBTC AMOUNT");

        uint256 supply = i_token.totalSupply();
        console.log("total COllateral", usdWeth + usdWbtc);
        console.log(supply, "TOTAL Supply");

        assert(usdWeth + usdWbtc >= supply);
        // assert(true);
    }
}
