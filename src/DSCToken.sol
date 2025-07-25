//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {ERC20Burnable, ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract DSCToken is ERC20Burnable, Ownable {
    error DSCToken__ZeroAddress();
    error DSCToken__BalanceNotEnough();
    error DSCToken__AmountShouldbeMoreThanZero();

    constructor() ERC20("LIFI Token", "LF") Ownable(msg.sender) {}

    function mintToken(
        address _account,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        if (_account == address(0)) {
            revert DSCToken__ZeroAddress();
        }
        _mint(_account, _amount);
        return true;
    }

    function burnTokens(uint256 _amount) external onlyOwner {
        if (_amount == 0) {
            revert DSCToken__AmountShouldbeMoreThanZero();
        }

        burn(_amount);
    }
}
