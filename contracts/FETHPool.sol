// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.6.11;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "./lib/openzeppelin/ERC20UpgradeSafe.sol";
import "./lib/Lockable.sol";
import "./lib/Configurable.sol";
import "./lib/interfaces/IFETH.sol";

contract FETHPool is OwnableUpgradeSafe, Lockable, Configurable {

    using SafeMath for uint256;

    event Deposited(address user, uint256 amount);
    event Withdrawn(address user, uint256 amount);
    event PoolRewarded(uint256 rewardID, uint256 amount);

    event RewardClaimed(address user, uint256 amount);

    bytes32 constant _rewardID_ = "rewardID";
    bytes32 constant _rewardBlock_ = "rewardBlock";
    bytes32 constant _rewardAmount_ = "rewardAmount";
    // total stakes before reward
    bytes32 constant _stakeBeforeReward_ = "stakeBeforeReward";

    bytes32 constant _totalStakes_ = "totalStakes";

    bytes32 constant _userDeposit_ = "userDeposit";
    bytes32 constant _userDepositRewardId_ = "userDepositRewardId";
    bytes32 constant _userDepositClaimed_ = "userDepositClaimed";
    bytes32 constant _userTotalDeposits_ = "userTotalDeposits";

    bytes32 constant _lastClaimRewardID_ = "lastClaimRewardID";

    address private _operator;
    IFETH private _fethContract;

    mapping (address => uint256[]) _userDepositBlocks;

    modifier onlyOperator() {
        require(msg.sender == owner() || msg.sender == _operator, "Operator: not allowed");
        _;
    }

    function initialize(address fethContract) public initializer {
        _fethContract = IFETH(fethContract);
    }

    function reward(uint256 amount) public onlyOperator {
        uint256 id = getConfig(_rewardID_);
        // set new id for next rewarding
        _setConfig(_rewardID_, id + 1);

        // set reward amount
        _setConfig(_rewardAmount_, id, amount);
        // set current total stakes
        _setConfig(_stakeBeforeReward_, id, getConfig(_totalStakes_));

        // mint tokens
        _fethContract.mint(address(this), amount);

        emit PoolRewarded(id, amount);
    }

    function claim() public {
        address user = msg.sender;
        uint256 amount = 0;

        uint256 lastClaim = getConfig(_lastClaimRewardID_, user) + 1;

        uint256 rewardID = getConfig(_rewardID_);

        for (uint256 i = lastClaim; i <= rewardID; i++) {
            uint256 depositID = i ^ uint256(user);
            // if deposit id already claimed continue
            if (getConfig(_userDepositClaimed_, depositID) > 0) continue;
            // calculate claim amount
            // deposit amount * total reward / _stakeBeforeReward_
            amount += getConfig(_userDeposit_, depositID)
            .mul(getConfig(_rewardAmount_, i))
            .div(getConfig(_stakeBeforeReward_, i));

            // set deposit id to claimed
            _setConfig(_userDepositClaimed_, depositID, 1);
        }

        // send amount to user
        if (amount > 0) {
            _fethContract.transfer(user, amount);
            emit RewardClaimed(user, amount);
        }
    }

    function depositFor(address user, uint256 amount) external {
        _deposit(user, amount);
    }

    function deposit(uint256 amount) external {
        _deposit(msg.sender, amount);
    }

    function depositsOf(address user) external view returns(uint256 amount) {
        amount = getConfig(_userTotalDeposits_, user);
    }

    function _deposit(address user, uint256 amount) private {
        _fethContract.transferFrom(user, address(this), amount);

        uint256 id = getConfig(_rewardID_);

        uint256 depositID = id ^ uint256(user);

        // add amount to user's pending amount
        _setConfig(_userDeposit_, depositID, getConfig(_userDeposit_, user).add(amount));
        _setConfig(_userDepositRewardId_, user, id);
        // add to total deposits
        _setConfig(_totalStakes_, getConfig(_totalStakes_).add(amount));

        _setConfig(_userTotalDeposits_, user, getConfig(_userTotalDeposits_, user).add(amount));

        if (getConfig(_lastClaimRewardID_, user) == 0) {
            _setConfig(_lastClaimRewardID_, user, id);
        }

        emit Deposited(user, amount);
    }

    function claimableBalanceOf(address user) external view returns(uint256 amount) {
        amount = 0;
        address user = msg.sender;

        uint256 lastClaim = getConfig(_lastClaimRewardID_, user) + 1;

        uint256 rewardID = getConfig(_rewardID_);

        for (uint256 i = lastClaim; i <= rewardID; i++) {
            uint256 depositID = i ^ uint256(user);
            // if deposit id already claimed continue
            if (getConfig(_userDepositClaimed_, depositID) > 0) continue;
            // calculate claim amount
            // deposit amount * total reward / _stakeBeforeReward_
            amount += getConfig(_userDeposit_, depositID)
            .mul(getConfig(_rewardAmount_, i))
            .div(getConfig(_stakeBeforeReward_, i));
        }

    }

    function withdraw() public {
        address user = msg.sender;
        claim();
        uint256 balance = getConfig(_userTotalDeposits_, user);

        require(balance > 0, "balance must be greater than zero");

        _setConfig(_userTotalDeposits_, user, 0);
        _setConfig(_lastClaimRewardID_, user, 0);

        emit Withdrawn(user, balance);
    }

}