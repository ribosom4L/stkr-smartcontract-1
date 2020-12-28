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

    function initialize(address ankrContract, address globalPoolContract, address aethContract) public initializer {
        OwnableUpgradeSafe.__Ownable_init();

        _ankrContract = IERC20(ankrContract);
        _globalPoolContract = globalPoolContract;
        _AETHContract = IAETH(aethContract);

        allowAddressForFunction(globalPoolContract, _freeze_);
        allowAddressForFunction(globalPoolContract, _unfreeze_);
    }

    modifier onlyOperator() {
        require(msg.sender == owner() || msg.sender == _operator, "Operator: not allowed");
        _;
    }

    modifier addressAllowed(address addr, bytes32 topic) {
        require(_allowedAddresses[bytes32(uint(addr)) ^ topic], "You are not allowed to run this function");
        _;
    }

    modifier onlyGlobalPoolContract() {
        require(_globalPoolContract == _msgSender(), "Ownable: caller is not the micropool contract");
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
        uint256 allowance = _ankrContract.allowance(user, address(this));

        if (allowance == 0) {
            return 0;
        }

        require(_ankrContract.transferFrom(user, address(this), allowance), "Allowance Claim Error: Tokens could not transferred from ankr contract");

         _deposits[user] = _deposits[user].add(allowance);

        emit Deposit(user, allowance);

        return allowance;
    }

    function withdraw(uint256 amount) public unlocked(msg.sender) returns (bool) {
        uint256 frozen = _frozen[msg.sender];
        uint256 available = _deposits[msg.sender].sub(frozen);

        require(available >= amount, "You dont have available deposit balance");

        _deposits[msg.sender] = _deposits[msg.sender].sub(amount);

        transferToken(msg.sender, amount);

        emit Withdraw(msg.sender, amount);

        return true;
    }

    function unfreeze(address addr, uint256 amount)
    public
    onlyGlobalPoolContract
    unlocked(addr)
    returns (bool)
    {
        _frozen[msg.sender] = _frozen[msg.sender].sub(amount, "Insufficient funds");

        emit Unfreeze(addr, amount);
        return true;
    }

    function freeze(address addr, uint256 amount)
    public
    onlyGlobalPoolContract
    unlocked(addr)
    returns (bool)
    {
        _claimAndDeposit(addr);
        require(_deposits[addr] >= amount, "You dont have enough amount to freeze ankr");
        _frozen[msg.sender] = _frozen[msg.sender].add(amount);

        emit Unfreeze(addr, amount);
        return true;
    }

    function depositsOf(address user) public view returns (uint256) {
        return _deposits[user];
    }

    function frozenDepositsOf(address user) public view returns (uint256) {
        return _frozen[user];
    }

    function transferToken(address to, uint256 amount) private {
        require(_ankrContract.transfer(to, amount), "Failed token transfer");
    }

    function allowAddressForFunction(address addr, bytes32 topic) public onlyOperator {
        _allowedAddresses[bytes32(uint(addr)) ^ topic] = true;
    }
}
