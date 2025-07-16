//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {DSCToken} from "./DSCToken.sol";
import {AggregatorV3Interface} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

contract PoolEngine {
    //Errors
    error PoolEngine__PriceFeedAndTokenLengthNotEqual();
    error PoolEngine__AmountMustbeMoreThanZero();
    error PoolEngine__CollateralTypeNotAllowed();
    error PoolEngine__CollateralTransferFailed();
    error PoolEngine__RedeemFailed();
    error PoolEngine__HealthyHealthFactor();
    error PoolEngine__LiquidatorUnHealthyHealthFactor();
    error PoolEngine__MintFailed();
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
    DSCToken internal immutable i_dscToken;
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
    event DSCEngine_tokensBurnt(address indexed user, uint256 indexed _amount);

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
        i_dscToken = DSCToken(dSCTokenAddress);
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
        address _collateralAddress,
        uint256 _amountToMint
    ) external isMoreThanZero(_amount) isTokenAllowed(_collateralAddress) {
        depositCollateral(_amount, _collateralAddress);
        mintDSC(_amountToMint);
    }

    function depositCollateral(
        uint256 _amount,
        address _collateralAddress
    ) public {
        s_userToCollateral[msg.sender][_collateralAddress] += _amount;
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

    function mintDSC(uint256 _amount) public isMoreThanZero(_amount) {
        s_usertomintedDSC[msg.sender] += _amount;

        bool success = i_dscToken.mintToken(msg.sender, _amount);
        if (!success) {
            revert PoolEngine__MintFailed();
        }
        emit DSCEngine_minted(msg.sender);
        revertIfHealthFactorIsDown(msg.sender);
    }

    function redeemCollateralAndBurnDSC(
        uint256 _amount,
        address _tokenCollateral,
        uint256 _amountToBurn
    ) external {
        redeemCollateral(_amount, _tokenCollateral, msg.sender, address(this));
        burnDSC(msg.sender, _amountToBurn);
    }

    function redeemCollateral(
        uint256 _amount,
        address _collateralAddress,
        address _from,
        address _to
    ) public isMoreThanZero(_amount) {
        s_userToCollateral[_from][_collateralAddress] -= _amount;
        bool success = IERC20(_collateralAddress).transfer(_to, _amount);
        emit DSCEngine_collateralRedeemed(_from, _amount);
        if (!success) {
            revert PoolEngine__RedeemFailed();
        }
    }

    function burnDSC(
        address _user,
        uint256 _amount
    ) internal isMoreThanZero(_amount) {
        s_usertomintedDSC[_user] -= _amount;
        i_dscToken.transferFrom(msg.sender, address(this), _amount);
        emit DSCEngine_tokensBurnt(msg.sender, _amount);
        i_dscToken.burnTokens(_amount);
    }

    function liquidate(
        address _user,
        uint256 _debt,
        address _collateralAddress
    ) external isMoreThanZero(_debt) isTokenAllowed(_collateralAddress) {
        console.log("Liquidating user: ", _user);
        uint256 healthFactor = checkHealthFactor(_user);
        if (healthFactor >= MIN_HEALTH_FACTOR) {
            revert PoolEngine__HealthyHealthFactor();
        }
        uint256 totalCollateral = getCollateralAmountInUsd(
            s_tokenToPriceFeed[_collateralAddress],
            _debt
        );
        uint256 incentive = (totalCollateral * INCENTIVE) / DIVISION_PRECISION;
        uint256 totalIncentive = totalCollateral + incentive;
        uint256 totalUsdToRedeem = _debt + incentive;

        // ✅ Convert USD → token amount
        uint256 tokenAmountToRedeem = getTokenAmountFromUsd(
            _collateralAddress,
            totalUsdToRedeem
        );
        console.log("total", tokenAmountToRedeem);
        console.log(
            "balance",
            getUserToCollateralValue(_user, _collateralAddress)
        );
        redeemCollateral(tokenAmountToRedeem, _collateralAddress, _user, msg.sender);
        burnDSC(_user, _debt);

        uint256 endingHealthFactor = checkHealthFactor(msg.sender);
        if (endingHealthFactor >= MIN_HEALTH_FACTOR) {
            revert PoolEngine__LiquidatorUnHealthyHealthFactor();
        }
    }

    //LIQUIDATION HELPER FUNCTIONS
    function checkHealthFactor(address user) public view returns (uint256) {
        uint256 totalAmount = getCollateral(user);
        return (totalAmount * DIVISION_PRECISION) / s_usertomintedDSC[user];
    }

    function getCollateral(address _user) public view returns (uint256) {
        uint256 totalAmount;

        for (uint256 i = 0; i < s_approvedTokens.length; i++) {
            if (s_userToCollateral[_user][s_approvedTokens[i]] != 0) {
                totalAmount += getCollateralAmountInUsd(
                    s_tokenToPriceFeed[s_approvedTokens[i]],
                    s_userToCollateral[_user][s_approvedTokens[i]]
                );
            }
        }
        return totalAmount;
    }

    function revertIfHealthFactorIsDown(address _user) public view {
        uint256 health = checkHealthFactor(_user);
        if (health < MIN_HEALTH_FACTOR) {
            revert PoolEngine__HealthyHealthFactor();
        }
    }

    function getCollateralAmountInUsd(
        address _collateralTypeAddress,
        uint256 _amount
    ) public view isMoreThanZero(_amount) returns (uint256) {
        (, int256 price, , , ) = AggregatorV3Interface(_collateralTypeAddress)
            .latestRoundData();
        return
            ((uint256(price) * MULTIPLICATION_PRECISION) * _amount) /
            DIVISION_PRECISION;
    }

    function calculateAdjustedCollateral(
        uint256 _amount
    ) public pure returns (uint256) {
        return
            (_amount * LIQUIDATION_THRESHOLD) / ADDITIONAL_DIVISION_PRECISION;
    }

    function getUserToCollateralValue(
        address _user,
        address _collateral
    ) public view returns (uint256) {
        return s_userToCollateral[_user][_collateral];
    }

    function getMintedDSCByUser(address _user) public view returns (uint256) {
        return s_usertomintedDSC[_user];
    }

    function getTokenAmountFromUsd(
        address _collateralAddress,
        uint256 usdAmount
    ) public view returns (uint256) {
        (, int256 price, , , ) = AggregatorV3Interface(
            s_tokenToPriceFeed[_collateralAddress]
        ).latestRoundData();
        // price = 8 decimals, MULTIPLICATION_PRECISION = 1e10, to scale to 1e18
        return
            (usdAmount * DIVISION_PRECISION) /
            (uint256(price) * MULTIPLICATION_PRECISION);
    }
}
