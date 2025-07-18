//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;
import {DSCToken} from "src/DSCToken.sol";
import {PoolEngine} from "src/Engine.sol";
import {Test} from "forge-std/Test.sol";

contract Handler is Test {
    DSCToken immutable i_token;
    PoolEngine immutable i_engine;
    address immutable i_weth;
    address immutable i_wbtc;

    constructor(
        DSCToken _token,
        PoolEngine _engine,
        address _weth,
        address _wbtc
    ) {
        i_token = _token;
        i_engine = _engine;
        i_weth = _weth;
        i_wbtc = _wbtc;
    }

    function depositCollateral(
        uint256 _collateralseed,
        uint256 _amount
    ) public {
        address collateralAddress = collateralSeed(_collateralseed);
        bound(_amount, 0, type(uint256).max);
        i_engine.depositCollateral(_amount, collateralAddress);
    }

    function mintDSC(uint256 _amount) public {
        bound(_amount, 0, type(uint256).max);
        i_engine.mintDSC(_amount);
    }

    //HELPER

    function collateralSeed(
        uint256 _collateralseed
    ) internal view returns (address) {
        if (_collateralseed % 2 == 0) {
            return i_weth;
        }
        return i_wbtc;
    }
}
