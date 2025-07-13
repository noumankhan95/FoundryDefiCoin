//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {DSCToken} from "./DSCToken.sol";
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";

contract PoolEngine {
    //Errors
    error PoolEngine__PriceFeedAndTokenLengthNotEqual();
    error PoolEngine__AmountMustbeMoreThanZero();
    error PoolEngine__CollateralTypeNotAllowed();
    error PoolEngine__CollateralTransferFailed();
    //   Storage Values       //
    address[] public s_approvedTokens;
    mapping(address => address) s_tokenToPriceFeed;
    mapping(address => mapping(address => uint256)) s_userToCollateral;
    mapping(address => uint256) s_usertomintedDSC;
    uint256 internal constant MULTIPLICATION_PRECISION = 1e10;
    uint256 internal constant DIVISION_PRECISION = 1e18;
    uint256 internal constant LIQUIDATION_THRESHOLD = 50;
    uint256 internal constant ADDITIONAL_DIVISION_PRECISION = 100;
    DSCToken internal s_dscToken;
    // Events

    event DSCToken_minted(address indexed user);
    event DSCToken_collateralDeposited(
        address indexed user,
        uint256 indexed amount
    );

    //Constructor Values //
    constructor(
        address[] memory _approvedTokens,
        address[] memory _tokenPriceFeeds,
        address dSCTokenAddress
    ) {
        require(
            _approvedTokens.length == _tokenPriceFeeds.length,
            PoolEngine__PriceFeedAndTokenLengthNotEqual()
        );
        for (uint i = 0; i < _approvedTokens.length; i++) {
            s_tokenToPriceFeed[_approvedTokens[i]] = _tokenPriceFeeds[i];
            s_approvedTokens.push(_approvedTokens[i]);
        }
        s_dscToken = DSCToken(dSCTokenAddress);
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
    function depositCollateralAndMintDSC(
        uint256 _amount,
        address _collateralAddress
    ) external isMoreThanZero(_amount) isTokenAllowed(_collateralAddress) {
        depositCollateral(_amount, _collateralAddress);
        mintDSC(_amount, _collateralAddress);
    }

    function depositCollateral(
        uint256 _amount,
        address _collateralAddress
    ) internal {
        s_userToCollateral[msg.sender][_collateralAddress] += _amount;
        uint256 collateralInUsd = getCollateralAmountInUsd(
            _collateralAddress,
            _amount
        );
        emit DSCToken_collateralDeposited(msg.sender, _amount);
    }

    function mintDSC(
        uint256 _amount,
        address _collateral
    ) internal isMoreThanZero(_amount) {
        s_usertomintedDSC[msg.sender] += _amount;
        bool success = IERC20(_collateral).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        s_dscToken.mintToken(msg.sender, _amount);
        emit DSCToken_minted(msg.sender);
        if (!success) {
            revert PoolEngine__CollateralTransferFailed();
        }
    }

    function redeemCollateral() external {}

    function liquidate() external {}

    //Helper Functions

    function getCollateralAmountInUsd(
        address _collateralTypeAddress,
        uint256 _amount
    )
        internal
        view
        isTokenAllowed(_collateralTypeAddress)
        isMoreThanZero(_amount)
        returns (uint256)
    {
        (, int256 price, , , ) = AggregatorV3Interface(_collateralTypeAddress)
            .latestRoundData();
        return
            ((uint256(price) * MULTIPLICATION_PRECISION) * _amount) /
            DIVISION_PRECISION;
    }

    function calculateAmountToLend(
        uint256 _amount
    ) internal pure returns (uint256) {
        return
            (_amount * LIQUIDATION_THRESHOLD) / ADDITIONAL_DIVISION_PRECISION;
    }
}
