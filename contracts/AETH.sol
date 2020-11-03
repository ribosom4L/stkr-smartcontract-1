// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "./lib/Lockable.sol";

contract AETH is OwnableUpgradeSafe, ERC20UpgradeSafe, Lockable {
    using SafeMath for uint256;

    event Freeze(address indexed account, uint256 value);
    event Unfreeze(address indexed account, uint256 value);
    event Claimed(address payable user, uint256 amount);

    event ClaimableToggle(bool _claimable);

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    mapping(address => uint256) private _balances;
    mapping(address => uint256) private _frozenBalances;

    bool public _claimable;

    address public _microPoolContract;

    uint256 public ratio;

    modifier onlyMicroPoolContract() {
        require(_microPoolContract == _msgSender(), "Ownable: caller is not the micropool contract");
        _;
    }

    modifier claimable() {
        require(_claimable, "Not claimable");
        _;
    }

    function initialize(string memory name, string memory symbol) public initializer {
        OwnableUpgradeSafe.__Ownable_init();
        __ERC20_init(name, symbol);
        _totalSupply = 0;

        changeRatio(10**_decimals);

        _claimable = false;
    }

    function updateMicroPoolContract(address microPoolContract) external onlyOwner {
        _microPoolContract = microPoolContract;
    }

    function availableBalanceOf(address account) public view returns (uint256) {
        return balanceOf(account).sub(frozenBalanceOf(account));
    }

    function frozenBalanceOf(address account) public view returns (uint256) {
        return _frozenBalances[account];
    }

    function mint(address account, uint256 amount) external onlyMicroPoolContract {
        _mint(account, amount);
    }

    function mintPool() payable external onlyMicroPoolContract {
        _mint(msg.sender, msg.value);
    }

    function mintFrozen(address account, uint256 amount) external onlyMicroPoolContract {
        _frozenBalances[account] = _frozenBalances[account].add(amount);

        _mint(account, amount);

        emit Freeze(account, amount);
    }

    function unfreeze() external claimable {
        uint256 amount = _frozenBalances[msg.sender];

        require(amount > 0, "Frozen Balance zero");

        _frozenBalances[msg.sender] = 0;

        _balances[msg.sender] = _balances[msg.sender].add(amount);

        emit Unfreeze(msg.sender, amount);
    }

    function swap() payable claimable external {
        require(availableBalanceOf(msg.sender) > 0, "Available aeth balance is zero");

        uint256 balance = availableBalanceOf(msg.sender);
        _burn(msg.sender, balance);
        require(msg.sender.send(balance), "Insufficient funds");
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function toggleClaimable() external onlyOwner {
        _claimable = !_claimable;
        emit ClaimableToggle(_claimable);
    }

    receive() external payable {
        _mint(msg.sender, msg.value);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) override internal {
        // if this is a real transfer
        if (from != address(0)) {
            require(availableBalanceOf(from) >= amount, "Available balance is lower than transfer amount");
        }
    }

    function changeRatio(uint256 _ratio) public onlyOwner {
        ratio = _ratio;
    }


}
