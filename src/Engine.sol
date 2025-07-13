//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {DSCToken} from "./DSCToken.sol";

contract PoolEngine {
    //Errors
    error PoolEngine__PriceFeedAndTokenLengthNotEqual();
    error PoolEngine__AmountMustbeMoreThanZero();
    error PoolEngine__CollateralTypeNotAllowed();
    //   Storage Values       //
    address[] public s_approvedTokens;
    mapping(address => address) s_tokenToPriceFeed;
    mapping(address => mapping(address => uint256)) s_userToCollateral;

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

    // Modifiers

    modifier isMoreThanZero(uint256 _amount) {
        require(_amount > 0, PoolEngine__AmountMustbeMoreThanZero());
        _;
    }
    modifier isTokenAllowed(address _tokenAddress) {
        require(
            s_tokenToPriceFeed[_tokenAddress] != address(0),
            PoolEngine__CollateralTypeNotAllowed()
        );
        _;
    }

    //Main Functionality
    function depositCollateral(
        uint256 _amount,
        address _collateralAddress
    ) external isMoreThanZero(_amount) isTokenAllowed(_collateralAddress) {
        s_userToCollateral[msg.sender][_collateralAddress] += _amount;
    }

    function mintDSC() external {}

    function redeemCollateral() external {}

    function liquidate() external {}


    //Helper Functions
}
