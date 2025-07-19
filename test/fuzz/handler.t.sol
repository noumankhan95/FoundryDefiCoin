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
    address immutable i_usdweth;
    address immutable i_usdwbtc;
    address[] usersWithCollateralDeposited;

    constructor(
        DSCToken _token,
        PoolEngine _engine,
        address _weth,
        address _wbtc,
        address _usdWeth,
        address _usdWbtc
    ) {
        i_token = _token;
        i_engine = _engine;
        i_weth = _weth;
        i_wbtc = _wbtc;
        i_usdweth = _usdWeth;
        i_usdwbtc = _usdWbtc;
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
        i_engine.depositCollateral(_amount, collateralAddress);

        uint256 _adjustedUDSPrice = i_engine.getCollateralAmountInUsd(
            i_usdweth,
            _amount
        );
        uint256 _amountToMint = i_engine.calculateAdjustedCollateral(
            _adjustedUDSPrice
        );
        i_engine.mintDSC(_amountToMint);
        vm.stopPrank();
        usersWithCollateralDeposited.push(msg.sender);
    }

    function redeemCollateral(
        uint256 _amount,
        uint256 _collateralSeed,
        uint256 _userSeed
    ) public {
        if (usersWithCollateralDeposited.length == 0) {
            return;
        }
        address user = usersWithCollateralDeposited[
            _userSeed % usersWithCollateralDeposited.length
        ];
        vm.startPrank(user);
        address collateral = collateralSeed(_collateralSeed);

        uint256 maxAmountToRedeem = i_engine.getUserToCollateralValue(
            user,
            collateral
        );
        console.log("Amount here is", maxAmountToRedeem);
        if (maxAmountToRedeem == 0) {
            vm.stopPrank();
            return;
        }
        console.log("max amount to redeem", maxAmountToRedeem);
        _amount = bound(_amount, 1, maxAmountToRedeem);
        i_engine.redeemCollateral(_amount, collateral, user, user);
        uint256 _adjustedUDSPrice = i_engine.getCollateralAmountInUsd(
            i_usdweth,
            _amount
        );
        uint256 _amountToBurn = i_engine.calculateAdjustedCollateral(
            _adjustedUDSPrice
        );
        console.log("BUrning dsc", _amountToBurn);
        i_token.approve(address(i_engine), _amountToBurn);
        i_engine.burnDSC(user, _amountToBurn);
        vm.stopPrank();
    }

    // function mintDSC(uint256 _amount) public {
    //     _amount = bound(_amount, 1, type(uint96).max);
    //     i_engine.mintDSC(_amount);
    // }

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
