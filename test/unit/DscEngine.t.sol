//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {Test} from "forge-std/Test.sol";
import {DSCToken} from "src/DSCToken.sol";
import {PoolEngine} from "src/Engine.sol";
import {DeployContract} from "script/DeployContract.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
// import {ERC20} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/ERC20.sol";
import {ERC20Mock} from "test/mocks/ERC20.t.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {console} from "forge-std/console.sol";

contract DSCTest is Test {
    DSCToken token;
    PoolEngine pool;
    HelperConfig config;
    HelperConfig.NetworkConfig public activeNetwork;
    address user = makeAddr("user");
    uint256 internal constant STARTING_USER_BALANCE = 10e18;
    address deployer;

    function setUp() external {
        (token, pool, config) = new DeployContract().run();
        (
            activeNetwork.wbtc,
            activeNetwork.weth,
            activeNetwork.deployerKey,
            activeNetwork.wethUsdPriceFeed,
            activeNetwork.wbtcUsdPriceFeed
        ) = config.activeNetworkConfig();
        // vm.prank(address(activeNetwork.deployerKey));
        ERC20Mock(activeNetwork.wbtc).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(activeNetwork.weth).mint(user, STARTING_USER_BALANCE);
        vm.deal(user, STARTING_USER_BALANCE);
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

    function testcheckBalanceisDealt() external view {
        uint256 expectedWbtcBalance = ERC20Mock(activeNetwork.wbtc).balanceOf(
            user
        );
        uint256 expectedWethBalance = ERC20Mock(activeNetwork.weth).balanceOf(
            user
        );
        assert(expectedWbtcBalance == STARTING_USER_BALANCE);
        assert(expectedWethBalance == STARTING_USER_BALANCE);
    }

    function testPriceFeed() external {
        uint256 _testamount = 0.8 ether;
        uint256 _amount = pool.getCollateralAmountInUsd(
            activeNetwork.wethUsdPriceFeed,
            _testamount
        );
        console.log(_amount);
        assert(_amount == 1600000000000000000000);
    }

    function testDepositCollateral() external {
        // vm.prank(deployer);
    }
}
