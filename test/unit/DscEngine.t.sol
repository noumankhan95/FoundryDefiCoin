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
import {ERC20MockDebt} from "../mocks/MockMoreDebtDSC.sol";
import {TestMockV3Aggregator} from "test/mocks/AggregatorV3.t.sol";

contract DSCTest is Test {
    DSCToken token;
    PoolEngine pool;
    HelperConfig config;
    HelperConfig.NetworkConfig public activeNetwork;
    address user = makeAddr("user");
    uint256 internal constant STARTING_USER_BALANCE = 10e18;
    address deployer;

    function setUp() external {
        (token, pool, activeNetwork) = new DeployContract().run();
        // (
        //     activeNetwork.wbtc,
        //     activeNetwork.weth,
        //     activeNetwork.deployerKey,
        //     activeNetwork.wethUsdPriceFeed,
        //     activeNetwork.wbtcUsdPriceFeed
        // ) = config.activeNetworkConfig();
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
        assert(_amount == 1600000000000000000000);
    }

    //DEPOSIT and MINT TESTS

    function testDepositCollateral() external {
        // vm.prank(deployer);
        uint256 startingBalance = ERC20Mock(activeNetwork.weth).balanceOf(user);
        vm.startPrank(user);
        ERC20Mock(activeNetwork.weth).approve(address(pool), 0.6 ether);
        pool.depositCollateral(0.6 ether, activeNetwork.weth);
        uint256 endingBalance = ERC20Mock(activeNetwork.weth).balanceOf(user);

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
        console.log(ERC20Mock(activeNetwork.weth).balanceOf(address(pool)));
        pool.redeemCollateral(0.6 ether, activeNetwork.weth, user, user);

        assert(ERC20Mock(activeNetwork.weth).balanceOf(user) == 10 ether);
    }

    function testrevertifAmountisZero() public mintandDepositDSC {
        ERC20Mock(activeNetwork.weth).approve(address(pool), 0.6 ether);
        vm.expectRevert(
            PoolEngine.PoolEngine__AmountMustbeMoreThanZero.selector
        );
        pool.redeemCollateral(0 ether, activeNetwork.weth, user, address(pool));
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
        token.approve(address(pool), _amountToMint);
        pool.redeemCollateralAndBurnDSC(
            0.6 ether,
            activeNetwork.weth,
            _amountToMint
        );
    }

    //liquidate Tests

    function testLiquidationSetUp() public {
        // address owner = msg.sender;
        // owner.deal();
        vm.startPrank(user);
        ERC20MockDebt moreDebtToken = new ERC20MockDebt(activeNetwork.weth);
        _approvedTokens = [activeNetwork.weth];
        _priceFeeds = [activeNetwork.wethUsdPriceFeed];

        PoolEngine engine = new PoolEngine(
            _approvedTokens,
            _priceFeeds,
            address(moreDebtToken)
        );
        moreDebtToken.transferOwnership(address(engine));
        ERC20Mock(activeNetwork.weth).approve(
            address(engine),
            600000000000000000000
        );
        engine.depositCollateralAndMintDSC(
            0.6 ether,
            activeNetwork.weth,
            600000000000000000000
        );
        vm.stopPrank();
        address liquidator = makeAddr("liquidator");

        vm.startPrank(liquidator);
        ERC20Mock(activeNetwork.weth).mint(liquidator, 20 ether);
        ERC20Mock(activeNetwork.weth).balanceOf(liquidator);
        ERC20Mock(activeNetwork.weth).approve(address(engine), 900 ether);

        engine.depositCollateralAndMintDSC(
            1 ether,
            activeNetwork.weth,
            900 ether
        );
        console.log(moreDebtToken.balanceOf(user), "balance");
        console.log(engine.getMintedDSCByUser(user), "2 balance");
        TestMockV3Aggregator(activeNetwork.wethUsdPriceFeed).updateAnswer(18e8);

        moreDebtToken.approve(address(engine), type(uint256).max);

        engine.liquidate(user, 10 ether, activeNetwork.weth);
        vm.stopPrank();
    }

    function testCantLiquidateGoodHealth() public {
        vm.startPrank(user);
        ERC20Mock(activeNetwork.weth).approve(address(pool), 2 ether);
        pool.depositCollateralAndMintDSC(
            2 ether,
            activeNetwork.weth,
            200 ether
        );
        vm.stopPrank();
        address liquidator = makeAddr("liquidator");
        vm.startPrank(liquidator);
        ERC20Mock(activeNetwork.weth).mint(liquidator, 100 ether);
        ERC20Mock(activeNetwork.weth).approve(address(pool),10 ether);
        pool.depositCollateralAndMintDSC(6 ether,activeNetwork.weth,250 ether);
        vm.expectRevert(PoolEngine.PoolEngine__HealthyHealthFactor.selector);
        pool.liquidate(user,200 ether,activeNetwork.weth);
        vm.stopPrank();
    }
}
