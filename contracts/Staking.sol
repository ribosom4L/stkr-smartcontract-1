// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "./lib/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./lib/Ownable.sol";
import "./core/OwnedByGovernor.sol";

// TODO: user can join late (reward will be reduce)
// TODO: if quit early will not earn reward
contract Staking is Ownable, OwnedByGovernor {
    using SafeMath for uint256;

    event Stake(
        address indexed staker,
        StakeType indexed stakeType,
        uint256 value
    );
    event Unstake(
        address indexed staker,
        StakeType indexed stakeType,
        uint256 value
    );

    enum StakeType {STANDARD, PROVIDER, POOL_FEE}

    // TODO: Set
    address public _ankrContract;
    address public _microPoolContract;

    mapping(address => uint256) public _stakes;
    mapping(address => uint256) public _providerStakes;
    mapping(address => uint256) public _poolStakes;

    uint256 private providerStakingAmount = 1e3;

    constructor(address ankrContract, address microPoolContract) public {
        _ankrContract = ankrContract;
        _microPoolContract = microPoolContract;
    }

    modifier shouldAllowed(address addr, uint256 amount) {
        // TODO: Error msg
        require(
            IERC20(_ankrContract).transferFrom(addr, address(this), amount),
            "Allowance"
        );
        _;
    }

    modifier addressAllowed(address addr) {
        require(msg.sender == addr, "");
        _;
    }

    function stake(uint256 amount)
        public
        shouldAllowed(msg.sender, amount)
        returns (bool)
    {
        _stakes[msg.sender] = _stakes[msg.sender].add(amount);
        emit Stake(msg.sender, StakeType.STANDARD, amount);
        return true;
    }

    function providerStake(address user)
        public
        shouldAllowed(user, providerStakingAmount)
        addressAllowed(_microPoolContract)
        returns (bool)
    {
        _providerStakes[msg.sender] = _providerStakes[msg.sender].add(providerStakingAmount);
        emit Stake(msg.sender, StakeType.PROVIDER, providerStakingAmount);
        return true;
    }

    function poolStake(address user, uint256 amount)
        public
        shouldAllowed(user, amount)
        addressAllowed(_microPoolContract)
        returns (bool)
    {
        _poolStakes[msg.sender] = _poolStakes[msg.sender].add(amount);
        emit Stake(msg.sender, StakeType.POOL_FEE, amount);
        return true;
    }

    function poolFeeWithStake(address user, uint256 amount)
        public
        returns (bool)
    {
        _stakes[user] = _stakes[user].sub(amount, "Insufficient balance");
        _poolStakes[user] = _poolStakes[user].add(amount);

        emit Stake(msg.sender, StakeType.PROVIDER, amount);

        return true;
    }

    function updateAnkrContract(address ankrContract) public onlyGovernor {
        _ankrContract = ankrContract;
    }

    function updateMicroPoolContract(address microPoolContract)
        public
        onlyGovernor
    {
        _microPoolContract = microPoolContract;
    }

    function transferToken(address to, uint256 amount) private {
        require(IERC20(_ankrContract).transfer(to, amount), "Failed");
    }

    function unstake(uint256 amount) public returns (bool) {
        _stakes[msg.sender] = _stakes[msg.sender].sub(
            amount,
            "Insufficient balance"
        );

        transferToken(msg.sender, amount);

        emit Unstake(msg.sender, StakeType.STANDARD, amount);
        return true;
    }

    function poolUnstake(address addr, uint256 amount)
        public
        addressAllowed(_microPoolContract)
        returns (bool)
    {
        _poolStakes[addr] = _poolStakes[addr].sub(
            amount,
            "Insufficient balance"
        );

        transferToken(addr, amount);

        emit Unstake(addr, StakeType.POOL_FEE, amount);
        return true;
    }

    function totalStakes(address staker) public view returns(uint256) {
        return _stakes[staker] + _providerStakes[staker] + _poolStakes[staker];
    }

    function totalStakes() public view returns(uint256) {
        return _stakes[msg.sender] + _providerStakes[msg.sender] + _poolStakes[msg.sender];
    }
}
