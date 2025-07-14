//SPDX-License-Identifier:MIT
pragma solidity ^0.8.18;
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract DSCToken is ERC20, Ownable {
    constructor() ERC20("LIFI Token", "LF") Ownable(msg.sender) {}

    function mintToken(address account, uint256 _amount) external {
        _mint(account, _amount);
    }

    function burnTokens(address _account, uint256 _amount) external {
        _burn(_account, _amount);
    }
}
