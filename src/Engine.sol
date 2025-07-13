//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {DSCToken} from "./DSCToken.sol";

contract PoolEngine {
    //Errors
    error PoolEngine__PriceFeedAndTokenLengthNotEqual();

    //   Storage Values       //
    address[] public s_approvedTokens;
    mapping(address => address) s_tokenToPriceFeed;

    //Constructor Values //
    constructor(
        address[] memory _approvedTokens,
        address[] memory _tokenPriceFeeds
    ) {
        require(
            _approvedTokens.length == _tokenPriceFeeds.length,
            PoolEngine__PriceFeedAndTokenLengthNotEqual()
        );
        for (uint i = 0; i < _approvedTokens.length; i++) {
            s_tokenToPriceFeed[_approvedTokens[i]] = _tokenPriceFeeds[i];
            s_approvedTokens.push(_approvedTokens[i]);
        }
    }

    function depositCollateral() external {}

    function mintDSC() external {}

    function redeemCollateral() external {}

    function liquidate() external {}
}
