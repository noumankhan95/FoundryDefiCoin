//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;
import {ERC20Burnable, ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {TestMockV3Aggregator} from "./AggregatorV3.t.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract ERC20MockDebt is ERC20Burnable, Ownable {
    error DSCToken__AmountShouldbeMoreThanZero();
    address mockAggregator;

    constructor(
        address _aggregator
    ) ERC20("LIFI Token", "LF") Ownable(msg.sender) {
        mockAggregator = _aggregator;
    }

    function mintToken(
        address _user,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        require(_amount > 0, "Amount Should be more than zero");
        require(_user != address(0), "No Zero Address");

        _mint(_user, _amount);
        return true;
    }

    function burnTokens(uint256 _amount) external onlyOwner {
        if (_amount == 0) {
            revert DSCToken__AmountShouldbeMoreThanZero();
        }

        burn(_amount);
    }
}
