// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "./lib/Lockable.sol";

contract AETH is OwnableUpgradeSafe, ERC20UpgradeSafe, Lockable {
    using SafeMath for uint256;

    event RatioUpdate(uint256 newRatio);

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    address private _microPoolContract;

    // ratio should be base on 1 ether
    // if ratio is 0.9, this variable should be  9e17
    uint256 private _ratio;

    modifier onlyMicroPoolContract() {
        require(_microPoolContract == _msgSender(), "Ownable: caller is not the micropool contract");
        _;
    }

    function initialize(string memory name, string memory symbol) public initializer {
        OwnableUpgradeSafe.__Ownable_init();
        __ERC20_init(name, symbol);
        _totalSupply = 0;

        _ratio = 1e18;
    }

    function updateRatio(uint256 newRatio) public onlyOwner {
        require(newRatio < _ratio, "New ratio cannot be smaller than old ratio");
        _ratio = newRatio;
        emit RatioUpdate(_ratio);
    }

    function ratio() public view returns (uint256) {
        return _ratio;
    }

    function updateMicroPoolContract(address microPoolContract) external onlyOwner {
        _microPoolContract = microPoolContract;
    }

    function mint(address account, uint256 amount) external onlyMicroPoolContract {
        _mint(account, amount.mul(ratio).div(1e18));
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
