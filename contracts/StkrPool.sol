// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

import "./lib/interfaces/IDepositContract.sol";

interface IStkrPool {

    uint256 constant public PROVIDER_SLASH_THRESHOLD = 2 ether;
    address constant public DEVELOPER_ADDRESS = 0xb827bCA9CF96f58a7BEd49D9b5cbd84fEd72b03F;

    /* pool events */
    event PoolPushWaiting(uint256 indexed pool);
    event PoolOnGoing(uint256 indexed pool);
    event PoolCompleted(uint256 indexed pool);
    event PoolClosed(uint256 indexed pool);

    /* stake events */
    event StakePending(address indexed staker, uint32 pool, uint64 amount);
    event StakeConfirmed(address indexed staker, uint32 pool, uint64 amount);

    /* provider events (once provider reach PROVIDER_SLASH_THRESHOLD negative balance we must slash him) */
    event ProviderSlashed(address indexed provider);

    /* distribution events */
    event RewardClaimed (uint32 pool, address user, uint256 amount);

    function stake() public payable;

    function proposeRewardOrSlashing(uint32 pool, address user, int256 amount) public;

    function distributeStakerRewards(uint32 pool) public;
}

contract StkrPool is IStkrPool, OwnableUpgradeSafe {

    using SafeMath for uint256;

    enum PoolStatus {
        /* pending pool just doesn't exist */
        PushWaiting,
        OnGoing,
        Completed,
        /* QUESTION: does it possible to cancel pool? how does cancellation work? */
        Canceled
    }

    /* 1+8*2=17 (1 word, 20k/5k), 32-17=15 bytes */
    struct Pool {
        PoolStatus status;
        /* global pools don't need names */
        uint64 rewarded; /* its better to store balance in gwei because beacon chain also stores it in gwei */
        uint64 slashed;
        /* QUESTION: why do we need requester rewards because we can calculate it using our distribution formula? */
        mapping(address => uint64) providerShare; // might be negative
        mapping(address => uint64) stakerShare; // +2 eth
        mapping(address => uint64) claimedRewards;
        // providerShare+stakerShare = -1.5+2 = 0.5

        /* we don't need provider with his staking amount also */
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
        Pool memory newPool = _pools[_pools.length - 1];
        for (uint i = 0; i < _pendingStakes.length; i++) {
            PendingStake memory pendingStake = _pendingStakes[i];
            newPool.stakerShare[pendingStake.staker] += pendingStake.amount;
            /* QUESTION: do we need to emit AETH creation here? */
            emit StakeConfirmed(pendingStake.staker, uint64(nextPoolIndex), pendingStake.amount);
        }
        /* releases (N+1)*10k + 10k gas */
        delete _pendingStakes;
        _pendingAmount = 0;
        emit PoolPushWaiting(nextPoolIndex);
    }

    function proposeRewardOrSlashing(uint32 pool, address user, uint256 rewarded, uint256 slashed, bytes32 transactionHash) public onlyOwner {
        /* QUESTION: do we need to store proofs from beacon chain? (for example, transaction hash or slot number) */
        Pool memory thatPool = _pools[pool];
        require(thatPool.status == PoolStatus.OnGoing, "can't reward non-ongoing pool");
        require(rewarded % 1e9 == 0, "rewarded amount shouldn't have a remainder");
        require(slashed % 1e9 == 0, "slashed amount shouldn't have a remainder");
        /* increase total rewards */
        thatPool.providerShare[user] += (rewarded - slashed) / 1e9;
        /* make sure provider has index */
        thatPool.rewarded += rewarded / 1e9;
        thatPool.slashed += slashed / 1e9;
        _pools[pool] = thatPool;
        /* implement provider ban logic */
        /* emit reward or slashing proposed event */
        /* add aeth migration logic */
    }

    uint64 constant PROVIDER_REWARD_SHARE = 10;
    uint64 constant REQUESTER_REWARD_SHARE = 77;
    uint64 constant STAKING_REWARD_SHARE = 10;
    uint64 constant DEVELOPER_REWARD_SHARE = 3;

    function calcStakerRewards(address user, uint32 pool) public pure view returns (uint64) {
        Pool memory thatPool = _pools[pool];
        uint256 poolRewards = thatPool.rewarded + thatPool.slashed;
        /* stakers can get only 77% of their stakes */
        uint256 totalProviderRewards = PROVIDER_REWARD_SHARE * poolRewards / 100;
        uint256 totalStakerRewards = REQUESTER_REWARD_SHARE * poolRewards / 100;
        /* calculate total rewards = provider rewards + staker rewards - claimed rewards */
        uint256 providerReward = thatPool.providerShare[user] / totalProviderRewards;
        uint256 stakerReward = thatPool.stakerShare[user] / totalStakerRewards;
        uint256 claimedReward = thatPool.claimedRewards[user];
        /* return user rewards in gwei */
        return providerReward + stakerReward - claimedReward;
    }

    function claimStakerRewards(address user, uint32 pool) {
        uint64 totalRewards = calcStakerRewards(user, pool);
        /* increase total claimed amount and fire events */
        thatPool.claimedRewards[user] += totalRewards;
        uint256 aethToDistribute = totalRewards * 1e9;
        /* distribute AETH tokens */
        emit RewardClaimed(pool, user, aethToDistribute);
    }

    function calcDeveloperRewards() public pure view returns (uint64) {
        Pool memory thatPool = _pools[pool];
        require(thatPool.status == PoolStatus.Completed, "only completed pool can be distributed");
        uint256 poolRewards = thatPool.rewarded + thatPool.slashed;
        /* developers get 3% of all rewards */
        uint256 developerReward = DEVELOPER_REWARD_SHARE * poolRewards / 100;
        uint256 claimedReward = thatPool.claimedRewards[DEVELOPER_ADDRESS];
        /* return user rewards in gwei */
        return developerReward - claimedReward;
    }

    function claimDeveloperRewards(uint32 pool) onlyOwner {
        uint64 totalRewards = calcStakerRewards(DEVELOPER_ADDRESS, pool);
        /* increase total claimed amount and fire events */
        thatPool.claimedRewards[DEVELOPER_ADDRESS] += totalRewards;
        uint256 aethToDistribute = totalRewards * 1e9;
        /* distribute AETH tokens */
        emit RewardClaimed(pool, DEVELOPER_ADDRESS, aethToDistribute);
    }
}
