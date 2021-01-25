// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.6.11;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "./lib/openzeppelin/ERC20UpgradeSafe.sol";
import "./lib/Lockable.sol";

contract FETH is OwnableUpgradeSafe, ERC20UpgradeSafe, Lockable {
    using SafeMath for uint256;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    address private _globalPoolContract;
    address private _fethPool;

    modifier onlyPools() {
        require(_globalPoolContract == msg.sender || _fethPool == msg.sender, "Ownable: caller is not the micropool contract");
        _;
    }

    function initialize(string memory name, string memory symbol, address globalPoolContract) public initializer {
        OwnableUpgradeSafe.__Ownable_init();
        __ERC20_init(name, symbol);
        _totalSupply = 0;
        _globalPoolContract = globalPoolContract;
    }

    function mint(address account, uint256 amount) external onlyPools {
        _mint(account, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function setFethPool(address addr) external {
        _fethPool = addr;
    }

    function approveAndDeposit(uint256 amount) external {
        _approve(msg.sender, _fethPool, amount);

    }
}
