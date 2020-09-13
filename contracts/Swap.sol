// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "./lib/SafeMath.sol";
import "./lib/Context.sol";
import "./core/OwnedByGovernor.sol";

abstract contract TokenContract {
    function mint(address account, uint256 amount) external virtual;
    function burnFrom(address sender, uint256 amount) external virtual returns (bool);
}

contract Swap is Context, OwnedByGovernor {
    using SafeMath for uint256;

    TokenContract private _tokenContract;

    event Swapped(
        address indexed user,
        uint256 amount
    );

    // allow to receive ETH payments
    receive() external payable {}

    function swap(uint256 amount) external {
        // TODO: validations

        _tokenContract.burnFrom(_msgSender(), amount);
        _msgSender().transfer(amount);
        emit Swapped(_msgSender(), amount);
    }

    function updateTokenContract(TokenContract tokenContract) external onlyGovernor {
        _tokenContract = tokenContract;
    }
}
