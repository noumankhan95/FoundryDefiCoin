//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;
import {DSCToken} from "src/DSCToken.sol";
import {PoolEngine} from "src/Engine.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "test/mocks/ERC20.t.sol";
import {console} from "forge-std/console.sol";

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

    function mintAndDepositCollateral(
        uint256 _collateralseed,
        uint256 _amount
    ) public {
        address collateralAddress = collateralSeed(_collateralseed);
     
        _amount = bound(_amount, 0, type(uint96).max);
        if (_amount == 0) {
            return;
        }
        vm.startPrank(msg.sender);
        ERC20Mock(collateralAddress).mint(msg.sender, _amount);
        ERC20Mock(collateralAddress).approve(address(i_engine), _amount);
        console.log("Minting to:", msg.sender);
        console.log("Amount:", _amount);
        console.log(
            "Balance after mint:",
            ERC20Mock(collateralAddress).balanceOf(msg.sender)
        );
        i_engine.depositCollateral(_amount, collateralAddress);
        vm.stopPrank();
    }

    function mintDSC(uint256 _amount) public {
        _amount = bound(_amount, 1, type(uint96).max);
        i_engine.mintDSC(_amount);
    }

    //HELPER

    function collateralSeed(
        uint256 _collateralseed
    ) private view returns (address) {
        if (_collateralseed % 2 == 0) {
            return i_weth;
        }
        return i_wbtc;
    }
}
