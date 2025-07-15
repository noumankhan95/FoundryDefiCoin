//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;
import {ERC20} from "lib/chainlink-brownie-contracts/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address _user, uint256 _amount) external {
        require(_amount > 0, "Amount Should be more than zero");
        require(_user != address(0), "No Zero Address");
        _mint(_user, _amount);
    }
}
