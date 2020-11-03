// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

import "./lib/interfaces/IDepositContract.sol";

interface IStkrPool {

    enum DistributionType {
        Provider,
        Requester,
        Staking,
        Developer
    }

    /* pool events */
    event PoolPushWaiting(uint256 indexed pool);
    event PoolOnGoing(uint256 indexed pool);
    event PoolCompleted(uint256 indexed pool);
    event PoolClosed(uint256 indexed pool);

    /* stake events */
    event StakePending(address indexed staker, uint32 pool, uint64 amount);
    event StakeConfirmed(address indexed staker, uint32 pool, uint64 amount);

    /* distribution events */
    event RewardDistributed (address user, DistributionType type, uint256 amount);

    function stake() public payable;
    function proposeRewardOrSlashing(uint32 pool, address user, int256 amount) public;
    function distributeRewards(uint32 pool, DistributionType type) public;
}

contract StkrPool is IStkrPool, OwnableUpgradeSafe {

    using SafeMath for uint256;

    enum PoolStatus {
        /* pending pool just doesn't exist */
        PushWaiting,
        OnGoing,
        Completed,
        Closed,
        /* QUESTION: does it possible to cancel pool? how does cancellation work? */
        Canceled
    }

    /* 1+6*8=49 (2 words, 40k/10k) */
    struct Pool {
        PoolStatus status;
        /* global pools don't need names */
        uint64 rewarded; /* its better to store balance in gwei because beacon chain also stores it in gwei */
        uint64 slashed;
        /* QUESTION: why do we need requester rewards because we can calculate it using our distribution formula? */
        mapping(address => uint64) totalRewards;
        /* we don't need provider with his staking amount also */
        /* we can collect gas from stakers and spend it on reward distribution */
        uint256[] gas;
    }

    /* list with active pools */
    Pool[] private _pools;

    /* this structure stores hash set */
    struct HashSet {
        mapping(address => uint256) index;
        address[] users;
    }
    /* (pool index => participants) */
    mapping(uint256 => HashSet) _participants;

    /* 20+8=28 (1 word, 20k/5k) */
    struct PendingStake {
        address staker;
        uint64 amount;
    }

    PendingStake[] _pendingStakes;
    /* current pending gwei amount for next pool */
    uint64 private _pendingAmount;

    /* 2*8=16 (1 word, 20k/5k), in reserve 16 bytes */
    struct Stake {
        uint64 amount; /* user can't stake less than 1 gwei */
        uint64 claimed; /* QUESTION: does claimed amount must be <= amount? (have not found this check in the code) */
    }

    mapping(address => Stake) private _stakes;

    function stake() public payable {
        _stakeUntilPossible(msg.value);
    }

    function _stakeUntilPossible(uint256 msgValue) private {
        require(msg.value % 1e9 == 0, "amount shouldn't have a remainder");
        /* check for min stake amount also here */
        while (msgValue > 0) {
            uint256 pendingPoolIndex = _pools.length;
            uint256 pendingRemained = 32e18 - _pendingAmount * 1e9;
            uint256 possibleStakeAmount = Math.min(pendingRemained, msgValue);
            /* QUESTION: should we reserve resources to compensate gas consumption for last player (who closed pool)? how to motivate players to close pools? */
            _pendingStakes.push({sender : msg.sender, amount : possibleStakeAmount});
            _pendingAmount += possibleStakeAmount / 1e9;
            /* lets remember this user as possible pool participant */
            _ensurePoolParticipation(pendingPoolIndex, msg.sender);
            emit StakePending(msg.sender, uint64(pendingPoolIndex), possibleStakeAmount / 1e9);
            /* check pool close condition */
            if (msgValue >= pendingRemained) {
                _closePendingPool();
            }
            msgValue -= possibleStakeAmount;
        }
    }

    function _ensurePoolParticipation(uint256 pool, address user) private {
        HashSet memory participants = _participants[pool];
        if (participants.index[user] > 0) return;
        participants.index[user] = participants.users.length + 1;
        participants.users.push(user);
        _participants[pool] = participants;
    }

    function _closePendingPool() private {
        uint256 nextPoolIndex = _pools.length;
        /* we pay only 20k+5k for creation (1 byte in reserve), tbh we pay additional 15k for length creation when length is 0 */
        _pools.push({status : PoolStatus.PushWaiting});
        for (uint i = 0; i < _pendingStakes.length; i++) {
            PendingStake memory pendingStake = _pendingStakes[i];
            _stakes[pendingStake.staker].amount += pendingStake.amount;
            /* QUESTION: do we need to emit AETH creation here? */
            emit StakeConfirmed(pendingStake.staker, uint64(nextPoolIndex), pendingStake.amount);
        }
        /* releases (N+1)*10k + 10k gas */
        delete _pendingStakes;
        _pendingAmount = 0;
        emit PoolPushWaiting(nextPoolIndex);
    }

    function proposeRewardOrSlashing(uint32 pool, address user, int256 amount) public {
        /* QUESTION: do we need to store proofs from beacon chain? (for example, transaction hash or slot number) */
        Pool memory thatPool = _pools[pool];
        require(thatPool.status == PoolStatus.OnGoing, "can't reward non-ongoing pool");
        require(amount % 1e9 == 0, "amount shouldn't have a remainder");
        /* increase total rewards */
        thatPool.totalRewards[user] += amount / 1e9;
        /* make sure provider has index */
        _ensurePoolParticipation(pool, user);
        if (amount > 0) {
            thatPool.rewarded += thatPool;
        } else {
            thatPool.slashed += - thatPool;
        }
        _pools[pool] = thatPool;
    }

    function distributeRewards(uint32 pool, DistributionType type) public {
        Pool memory thatPool = _pools[pool];
        require(thatPool.status == PoolStatus.Completed, "only completed pool can be distributed");
        thatPool.status = PoolStatus.Closed;
        HashSet memory participants = _participants[pool];
        uint256 providersReward = calculateRewardsForPool(pool, type);
        for (uint256 i = 0; i < participants.users.length; i++) {
            address provider = participants.users[i + 1];
            uint256 reward = thatPool.totalRewards[provider] / providersReward;
            /* QUESTION: how are we going to distribute it? */
            emit RewardDistributed(provider, DistributionType.Provider, reward * 1e9);
        }
        _pools[pool] = thatPool;
    }

    uint64 constant PROVIDER_REWARD_SHARE = 10;
    uint64 constant REQUESTER_REWARD_SHARE = 77;
    uint64 constant STAKING_REWARD_SHARE = 10;
    uint64 constant DEVELOPER_REWARD_SHARE = 3;

    function calculateRewardsForPool(uint32 pool, DistributionType type) pure public view returns (int64) {
        Pool memory thatPool = _pools[pool];
        uint256 totalRewards = thatPool.rewarded + thatPool.slashed;
        uint256 shareRatio = 0;
        if (type == DistributionType.Provider) {
            shareRatio = PROVIDER_REWARD_SHARE;
        } else if (type == DistributionType.Requester) {
            shareRatio = REQUESTER_REWARD_SHARE;
        } else if (type == DistributionType.Staking) {
            shareRatio = STAKING_REWARD_SHARE;
        } else if (type == DistributionType.Developer) {
            shareRatio = DEVELOPER_REWARD_SHARE;
        }
        return int64(totalRewards * shareRatio / 100);
    }
}
