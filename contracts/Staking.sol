// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "./lib/IERC20.sol";
import "./lib/SafeMath.sol";
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

    enum StakeType {STANDART, PROVIDER, NODE, POOL_FEE}

    // TODO: Set
    address private _ankrContract;
    address private _nodeContract;
    address private _providerContract;
    address private _microPoolContract;

    mapping(address => uint256) _stakes;
    mapping(address => uint256) _providerStakes;
    mapping(address => uint256) _nodeStakes;
    mapping(address => uint256) _poolStakes;

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

    function stake(address user, uint256 amount)
        public
        shouldAllowed(user, amount)
        returns (bool)
    {
        _stakes[msg.sender] = _stakes[msg.sender].add(amount);
        emit Stake(msg.sender, StakeType.STANDART, amount);
        return true;
    }

    function nodeStake(address user, uint256 amount)
        public
        shouldAllowed(user, amount)
        addressAllowed(_nodeContract)
        returns (bool)
    {
        _nodeStakes[msg.sender] = _nodeStakes[msg.sender].add(amount);
        emit Stake(msg.sender, StakeType.NODE, amount);
        return true;
    }

    function providerStake(address user, uint256 amount)
        public
        shouldAllowed(user, amount)
        addressAllowed(_providerContract)
        returns (bool)
    {
        _providerStakes[msg.sender] = _providerStakes[msg.sender].add(amount);
        emit Stake(msg.sender, StakeType.PROVIDER, amount);
        return true;
    }

    function poolStake(address user, uint256 amount)
        public
        shouldAllowed(user, amount)
        addressAllowed(_microPoolContract)
        returns (bool)
    {
        _poolStakes[msg.sender] = _providerStakes[msg.sender].add(amount);
        emit Stake(msg.sender, StakeType.PROVIDER, amount);
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

    function updateNodeContract(address nodeContract) public onlyGovernor {
        _nodeContract = nodeContract;
    }

    function updateProviderContract(address providerContract)
        public
        onlyGovernor
    {
        _providerContract = providerContract;
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

        emit Unstake(msg.sender, StakeType.STANDART, amount);
        return true;
    }

    function nodeUnstake(address addr, uint256 amount)
        public
        addressAllowed(_nodeContract)
        returns (bool)
    {
        _nodeStakes[addr] = _nodeStakes[addr].sub(
            amount,
            "Insufficient balance"
        );

        transferToken(addr, amount);

        emit Unstake(addr, StakeType.NODE, amount);
        return true;
    }

    function providerUnstake(address addr, uint256 amount)
        public
        addressAllowed(_providerContract)
        returns (bool)
    {
        _providerStakes[addr] = _providerStakes[addr].sub(
            amount,
            "Insufficient balance"
        );

        transferToken(addr, amount);

        emit Unstake(addr, StakeType.PROVIDER, amount);
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
}
