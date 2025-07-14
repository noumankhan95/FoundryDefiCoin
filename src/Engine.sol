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
    error PoolEngine__RedeemFailed();
    error PoolEngine__HealthyHealthFactor();
    error PoolEngine__LiquidatorUnHealthyHealthFactor();
    //   Storage Values       //
    address[] public s_approvedTokens;
    mapping(address => address) s_tokenToPriceFeed;
    mapping(address => mapping(address => uint256)) s_userToCollateral;
    mapping(address => uint256) s_usertomintedDSC;
    uint256 internal constant MULTIPLICATION_PRECISION = 1e10;
    uint256 internal constant DIVISION_PRECISION = 1e18;
    uint256 internal constant LIQUIDATION_THRESHOLD = 50;
    uint256 internal constant ADDITIONAL_DIVISION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant INCENTIVE = 10;
    DSCToken internal s_dscToken;
    // Events

    event DSCEngine_minted(address indexed user);
    event DSCEngine_collateralDeposited(
        address indexed user,
        uint256 indexed amount
    );
    event DSCEngine_collateralRedeemed(
        address indexed user,
        uint256 indexed _amount
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
        mintDSC(_amount);
    }

    function redeemCollateralAndBurnDSC(
        uint256 _amount,
        address _tokenCollateral
    ) external {
        redeemCollateral(_amount, _tokenCollateral, address(this), msg.sender);
        burnDSC(msg.sender, _amount);
    }

    function depositCollateral(
        uint256 _amount,
        address _collateralAddress
    ) internal {
        bool success = IERC20(_collateralAddress).transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        if (!success) {
            revert PoolEngine__CollateralTransferFailed();
        }
        emit DSCEngine_collateralDeposited(msg.sender, _amount);
    }

    function mintDSC(uint256 _amount) internal isMoreThanZero(_amount) {
        s_usertomintedDSC[msg.sender] += _amount;

        s_dscToken.mintToken(msg.sender, _amount);
        emit DSCEngine_minted(msg.sender);
    }

    function burnDSC(
        address _user,
        uint256 _amount
    ) internal isMoreThanZero(_amount) {
        s_usertomintedDSC[_user] -= _amount;
        s_dscToken.burnTokens(_amount);
    }

    function redeemCollateral(
        uint256 _amount,
        address _collateralAddress,
        address _from,
        address _to
    ) internal {
        s_userToCollateral[_from][_collateralAddress] -= _amount;
        bool success = IERC20(_collateralAddress).transferFrom(
            _from,
            _to,
            _amount
        );
        emit DSCEngine_collateralRedeemed(_from, _amount);
        if (!success) {
            revert PoolEngine__RedeemFailed();
        }
    }

    function liquidate(
        address _user,
        uint256 _debt,
        address _collateralAddress
    ) external isMoreThanZero(_debt) isTokenAllowed(_collateralAddress) {
        uint256 healthFactor = checkHealthFactor(_user);
        if (healthFactor >= MIN_HEALTH_FACTOR) {
            revert PoolEngine__HealthyHealthFactor();
        }
        uint256 totalCollateral = getCollateralAmountInUsd(
            _collateralAddress,
            _debt
        );
        uint256 incentive = (totalCollateral * INCENTIVE) / DIVISION_PRECISION;
        uint256 totalIncentive = totalCollateral + incentive;

        redeemCollateral(totalIncentive, _collateralAddress, _user, msg.sender);

        uint256 endingHealthFactor = checkHealthFactor(msg.sender);
        if (endingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert PoolEngine__LiquidatorUnHealthyHealthFactor();
        }
    }

    //LIQUIDATION HELPER FUNCTIONS

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

    function checkHealthFactor(address user) public view returns (uint256) {
        uint256 totalAmount = getCollateral(user);
        return
            (calculateAdjustedCollateral(totalAmount) * DIVISION_PRECISION) /
            s_usertomintedDSC[user];
    }

    function getCollateral(address _user) internal view returns (uint256) {
        uint256 totalAmount;

        for (uint256 i = 0; i < s_approvedTokens.length; i++) {
            totalAmount += getCollateralAmountInUsd(
                s_approvedTokens[i],
                s_userToCollateral[_user][s_approvedTokens[i]]
            );
        }
        return totalAmount;
    }

    function calculateAdjustedCollateral(
        uint256 _amount
    ) internal pure returns (uint256) {
        return
            (_amount * LIQUIDATION_THRESHOLD) / ADDITIONAL_DIVISION_PRECISION;
    }
}
