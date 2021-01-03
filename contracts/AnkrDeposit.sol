// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.11;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "./lib/Lockable.sol";
import "./lib/interfaces/IAETH.sol";
import "./lib/interfaces/IMarketPlace.sol";

contract AnkrDeposit is OwnableUpgradeSafe, Lockable {
    using SafeMath for uint256;

    event Deposit(
        address indexed user,
        uint256 value
    );

    event Freeze(
        address indexed user,
        uint256 value
    );

    event Unfreeze(
        address indexed user,
        uint256 value
    );

    event Withdraw(
        address indexed user,
        uint256 value
    );

    event Compensate(address indexed provider, uint256 ankrAmount, uint256 etherAmount);

    // deposits of users
    mapping (address => uint256) private _deposits;
    mapping (address => uint256) private _frozen;

    mapping (bytes32 => bool) private _allowedAddresses;

    IAETH private _AETHContract;

    IMarketPlace _marketPlaceContract;

    IERC20 private _ankrContract;

    address private _globalPoolContract;

    address _governanceContract;

    address _operator;

    bytes32 constant _freeze_ = "Freeze";
    bytes32 constant _unfreeze_ = "Unfreeze";

    function deposit_init(address ankrContract, address globalPoolContract, address aethContract) internal initializer {
        OwnableUpgradeSafe.__Ownable_init();

        _ankrContract = IERC20(ankrContract);
        _globalPoolContract = globalPoolContract;
        _AETHContract = IAETH(aethContract);
        allowAddressForFunction(globalPoolContract, _unfreeze_);
        allowAddressForFunction(globalPoolContract, _freeze_);
    }

    modifier onlyOperator() {
        require(msg.sender == owner() || msg.sender == _operator, "Operator: not allowed");
        _;
    }

    modifier addressAllowed(address addr, bytes32 topic) {
        require(_allowedAddresses[bytes32(uint(addr)) ^ topic], "You are not allowed to run this function");
        _;
    }

    function deposit() public unlocked(msg.sender) returns(uint256) {
        return _claimAndDeposit(msg.sender);
    }

    function deposit(address user) public unlocked(user) returns(uint256) {
        return _claimAndDeposit(user);
    }
    /*
        This function used to deposit ankr with transferFrom
    */
    function _claimAndDeposit(address user) private returns (uint256) {
        address ths = address(this);
        uint256 allowance = _ankrContract.allowance(user, ths);

        if (allowance == 0) {
            return 0;
        }

        require(_ankrContract.transferFrom(user, ths, allowance), "Allowance Claim Error: Tokens could not transferred from ankr contract");

         _deposits[user] = _deposits[user].add(allowance);

        emit Deposit(user, allowance);

        return allowance;
    }

    function withdraw(uint256 amount) public unlocked(msg.sender) returns (bool) {
        address sender = msg.sender;
        uint256 available = availableDepositsOf(sender);

        require(available >= amount, "You dont have available deposit balance");

        _deposits[sender] = _deposits[sender].sub(amount);

        _transferToken(sender, amount);

        emit Withdraw(sender, amount);

        return true;
    }

    function _unfreeze(address addr, uint256 amount)
    internal
    returns (bool)
    {
        _frozen[msg.sender] = _frozen[msg.sender].sub(amount, "Insufficient funds");

        emit Unfreeze(addr, amount);
        return true;
    }

    function _freeze(address addr, uint256 amount)
    internal
    returns (bool)
    {
        _claimAndDeposit(addr);
        require(_deposits[addr] >= amount, "You dont have enough amount to freeze ankr");
        _frozen[msg.sender] = _frozen[msg.sender].add(amount);

        emit Freeze(addr, amount);
        return true;
    }

    function unfreeze(address addr, uint256 amount)
    public
    addressAllowed(_globalPoolContract, _unfreeze_)
    returns (bool)
    {
        _frozen[msg.sender] = _frozen[msg.sender].sub(amount, "Insufficient funds");

        emit Unfreeze(addr, amount);
        return true;
    }

    function freeze(address addr, uint256 amount)
    public
    addressAllowed(_globalPoolContract, _freeze_)
    returns (bool)
    {
        _claimAndDeposit(addr);
        require(_deposits[addr] >= amount, "You dont have enough amount to freeze ankr");
        _frozen[msg.sender] = _frozen[msg.sender].add(amount);

        emit Unfreeze(addr, amount);
        return true;
    }

    function availableDepositsOf(address user) public view returns (uint256) {
        return _deposits[user].sub(_frozen[user]);
    }

    function depositsOf(address user) public view returns (uint256) {
        return _deposits[user];
    }

    function frozenDepositsOf(address user) public view returns (uint256) {
        return _frozen[user];
    }

    function _transferToken(address to, uint256 amount) internal {
        require(_ankrContract.transfer(to, amount), "Failed token transfer");
    }

    function allowAddressForFunction(address addr, bytes32 topic) public onlyOperator {
        _allowedAddresses[bytes32(uint(addr)) ^ topic] = true;
    }
}
