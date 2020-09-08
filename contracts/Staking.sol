// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "./lib/IERC20.sol";
import "./lib/SafeMath.sol";

// TODO: user can join late (reward will be reduce)
// TODO: if quit early will not earn reward
contract Staking {
    using SafeMath for uint256;

    event Stake(address indexed staker, StakeType indexed stakeType, uint256 value);

    enum StakeType {
        STANDART,
        PROVIDER,
        NODE
    }

    // TODO: Set
    address private _ankrContract;
    address private _nodeContract;
    address private _providerContract;

    mapping(address => uint256) _stakes;
    mapping(address => uint256) _providerStakes;
    mapping(address => uint256) _nodeStakes;

    modifier shouldAllowed(uint256 amount) {
        // TODO: Error msg        
        require(IERC20(_ankrContract).transferFrom(msg.sender, address(this), amount), "Allowance");
        _;
    }

    modifier addressAllowed(address addr) {
        require(msg.sender == addr, "Allowance");
        _;
    }
    
    function stake(uint256 amount) public shouldAllowed(amount) returns(bool) {
        _stakes[msg.sender] = _stakes[msg.sender].add(amount);
        emit Stake(msg.sender, StakeType.STANDART, amount);
        return true;
    }

    function nodeStake(uint256 amount) public shouldAllowed(amount) addressAllowed(_nodeContract) returns(bool) {
        _nodeStakes[msg.sender] = _nodeStakes[msg.sender].add(amount);
        emit Stake(msg.sender, StakeType.NODE, amount);
        return true;
    }

    function providerStake(uint256 amount) public shouldAllowed(amount) addressAllowed(_providerContract) returns(bool) {
        _providerStakes[msg.sender] = _providerStakes[msg.sender].add(amount);
        emit Stake(msg.sender, StakeType.PROVIDER, amount);
        return true;
    }

    function poolStake() {}
}