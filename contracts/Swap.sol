// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "./lib/SafeMath.sol";

abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}

abstract contract TokenContract {
    function mint(address account, uint256 amount) external virtual;
    function burnFrom(address sender, uint256 amount) external virtual returns (bool);
}

contract Swap is Context {
    using SafeMath for uint256;

    TokenContract private _tokenContract;

    event Swapped(
        address indexed user,
        uint256 amount
    );

    constructor(
        TokenContract tokenContract
    ) public {
        _tokenContract = tokenContract;
    }

    function swap(uint256 amount) external {
        // TODO: validations

        _tokenContract.burnFrom(_msgSender(), amount);
        _msgSender().transfer(amount);
        emit Swapped(_msgSender(), amount);
    }
}
