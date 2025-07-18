//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {DSCToken} from "src/DSCToken.sol";
import {PoolEngine} from "src/Engine.sol";
import {DeployContract} from "script/DeployContract.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Handler} from "./handler.t.sol";

contract Invariants {
    HelperConfig.NetworkConfig i_activeConfig;
    Handler immutable i_handler;

    constructor() {
        HelperConfig config = new HelperConfig();
        i_activeConfig = config.run();
        DeployContract deployed = new DeployContract();
        (DSCToken token, PoolEngine engine, HelperConfig c) = deployed.run();
        i_handler = new Handler(
            token,
            engine,
            i_activeConfig.weth,
            i_activeConfig.wbtc
        );
    }
}
