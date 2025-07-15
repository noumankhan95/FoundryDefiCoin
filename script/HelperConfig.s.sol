//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import {Script} from "forge-std/Script.sol";
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {TestMockV3Aggregator} from "test/mocks/AggregatorV3.t.sol";
import {ERC20} from "test/mocks/ERC20.t.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidNetworkConfig();
    uint8 internal constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    struct NetworkConfig {
        address wbtc;
        address weth;
        uint256 deployerKey;
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
    }
    NetworkConfig public activeNetworkConfig;

    function run() external returns (NetworkConfig memory) {
        if (block.chainid == 1) {
            activeNetworkConfig = getEthMainnetConfig();
            return activeNetworkConfig;
        } else if (block.chainid == 11_155_111) {
            activeNetworkConfig = getSepoliaEthConfig();
            return activeNetworkConfig;
        } else {
            revert HelperConfig__InvalidNetworkConfig();
        }
    }

    function getSepoliaEthConfig()
        internal
        view
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({
                wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
                wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
                weth: 0xdd13E55209Fd76AfE204dBda4007C227904f0a81,
                wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
                deployerKey: vm.envUint("PRIVATE_KEY")
            });
    }

    function getEthMainnetConfig()
        internal
        view
        returns (NetworkConfig memory)
    {
        return
            NetworkConfig({
                wbtc: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
                weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
                deployerKey: vm.envUint("key"),
                wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
                wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
            });
    }

    function getAnvilConfig() internal returns (NetworkConfig memory) {
        TestMockV3Aggregator wethPriceFeed = new TestMockV3Aggregator(
            DECIMALS,
            ETH_USD_PRICE
        );
        TestMockV3Aggregator wbtcPriceFeed = new TestMockV3Aggregator(
            DECIMALS,
            BTC_USD_PRICE
        );
        ERC20 wbtcMock = new ERC20("WBTC MOCK", "wbtc");
        ERC20 wethMock = new ERC20("WETH MOCK", "weth");
        return
            NetworkConfig({
                wbtc: address(wbtcMock),
                weth: address(wethMock),
                deployerKey: vm.envUint("key"),
                wethUsdPriceFeed: address(wethPriceFeed),
                wbtcUsdPriceFeed: address(wbtcPriceFeed)
            });
    }
}
