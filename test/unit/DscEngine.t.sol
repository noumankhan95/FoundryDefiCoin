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

    function testPriceFeed() external view {
        uint256 _testamount = 0.8 ether;
        uint256 _amount = pool.getCollateralAmountInUsd(
            activeNetwork.wethUsdPriceFeed,
            _testamount
        );
        console.log(_amount);
        assert(_amount == 1600000000000000000000);
    }

    //DEPOSIT and MINT TESTS

    function testDepositCollateral() external {
        // vm.prank(deployer);
        uint256 startingBalance = ERC20Mock(activeNetwork.weth).balanceOf(user);
        console.log(startingBalance / 1e18, "start Balance");
        vm.startPrank(user);
        ERC20Mock(activeNetwork.weth).approve(address(pool), 0.6 ether);
        pool.depositCollateral(0.6 ether, activeNetwork.weth);
        uint256 endingBalance = ERC20Mock(activeNetwork.weth).balanceOf(user);
        console.log(endingBalance / 1e18, "end Balance");

        vm.stopPrank();
        assert(endingBalance == startingBalance - 0.6 ether);
    }

    function testapprovedTokenUsersIsUpdating() external {
        vm.startPrank(user);
        ERC20Mock(activeNetwork.weth).approve(address(pool), 0.6 ether);

        uint256 _adjustedUDSPrice = pool.getCollateralAmountInUsd(
            activeNetwork.wethUsdPriceFeed,
            0.6 ether
        );
        uint256 _amountToMint = pool.calculateAdjustedCollateral(
            _adjustedUDSPrice
        );

        pool.depositCollateralAndMintDSC(
            0.6 ether,
            activeNetwork.weth,
            _amountToMint
        );
        assert(
            pool.getUserToCollateralValue(user, activeNetwork.weth) == 0.6 ether
        );
    }

    function testCanDepositAndMint() external {
        uint256 startingBalanceWeth = ERC20Mock(activeNetwork.weth).balanceOf(
            user
        );
        vm.startPrank(user);
        ERC20Mock(activeNetwork.weth).approve(address(pool), 0.6 ether);
        uint256 _adjustedUDSPrice = pool.getCollateralAmountInUsd(
            activeNetwork.wethUsdPriceFeed,
            0.6 ether
        );
        uint256 _amountToMint = pool.calculateAdjustedCollateral(
            _adjustedUDSPrice
        );

        pool.depositCollateralAndMintDSC(
            0.6 ether,
            activeNetwork.weth,
            _amountToMint
        );
        uint256 endingBalanceWeth = ERC20Mock(activeNetwork.weth).balanceOf(
            user
        );
        uint256 dscAmount = token.balanceOf(user);
        vm.stopPrank();
        assert(endingBalanceWeth == startingBalanceWeth - 0.6 ether);
        assert(dscAmount == 600000000000000000000);
    }

    //TEST minting healthFactor Checks

    function testHealthFactor() external mintandDepositDSC {
        uint256 healthFactor = pool.checkHealthFactor(address(user));
        assert(healthFactor == 1e18);
        vm.stopPrank();
    }

    modifier mintandDepositDSC() {
        vm.startPrank(user);
        ERC20Mock(activeNetwork.weth).approve(address(pool), 0.6 ether);
        uint256 _adjustedUDSPrice = pool.getCollateralAmountInUsd(
            activeNetwork.wethUsdPriceFeed,
            0.6 ether
        );
        uint256 _amountToMint = pool.calculateAdjustedCollateral(
            _adjustedUDSPrice
        );

        pool.depositCollateralAndMintDSC(
            0.6 ether,
            activeNetwork.weth,
            _amountToMint
        );
        vm.stopPrank();
        _;
    }

    function testMintingFailsIfHealthFactorIsDown() public mintandDepositDSC {
        vm.startPrank(user);
        ERC20Mock(activeNetwork.weth).approve(address(pool), 0.6 ether);
        uint256 _adjustedUDSPrice = pool.getCollateralAmountInUsd(
            activeNetwork.wethUsdPriceFeed,
            0.6 ether
        );
        uint256 _amountToMint = pool.calculateAdjustedCollateral(
            _adjustedUDSPrice
        );

        pool.depositCollateralAndMintDSC(
            0.6 ether,
            activeNetwork.weth,
            _amountToMint
        );
        vm.expectRevert(PoolEngine.PoolEngine__HealthyHealthFactor.selector);
        pool.mintDSC(_amountToMint);
        vm.stopPrank();
    }

    //REDEEM collateral TESTS
    function testCanRedeemCollateral() public mintandDepositDSC {
        console.log(pool.getUserToCollateralValue(user, activeNetwork.weth));
        ERC20Mock(activeNetwork.weth).approve(address(pool), 0.6 ether);
        pool.redeemCollateral(
            0.6 ether,
            activeNetwork.weth,
            address(pool),
            user
        );

        assert(ERC20Mock(activeNetwork.weth).balanceOf(user) == 10 ether);
    }

    function testrevertifAmountisZero() public mintandDepositDSC {
        console.log(pool.getUserToCollateralValue(user, activeNetwork.weth));
        ERC20Mock(activeNetwork.weth).approve(address(pool), 0.6 ether);
        vm.expectRevert(
            PoolEngine.PoolEngine__AmountMustbeMoreThanZero.selector
        );
        pool.redeemCollateral(0 ether, activeNetwork.weth, address(pool), user);
    }

    function testRedeemAndBurn() public {
        vm.startPrank(user);
        ERC20Mock(activeNetwork.weth).approve(address(pool), 0.6 ether);
        uint256 _adjustedUDSPrice = pool.getCollateralAmountInUsd(
            activeNetwork.wethUsdPriceFeed,
            0.6 ether
        );
        uint256 _amountToMint = pool.calculateAdjustedCollateral(
            _adjustedUDSPrice
        );
        pool.depositCollateralAndMintDSC(
            0.6 ether,
            activeNetwork.weth,
            _amountToMint
        );
        console.log(token.balanceOf(user), "USER TOKEN");
        console.log(_amountToMint);
        token.approve(address(pool), _amountToMint);
        pool.redeemCollateralAndBurnDSC(
            0.6 ether,
            activeNetwork.weth,
            _amountToMint
        );
    }
}
