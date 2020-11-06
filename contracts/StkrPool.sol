// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "./lib/interfaces/IDepositContract.sol";
import "./SystemParameters.sol";
import "./lib/Lockable.sol";
import "./lib/interfaces/IAETH.sol";
import "./lib/interfaces/IStaking.sol";

import "./lib/interfaces/IDepositContract.sol";

interface IStkrPool {

    //    function createETHPool() external payable;
    //    function createANKRPool() external payable;

    //    function stake() external payable;
    //
    //    function proposeRewardOrSlashing(uint32 pool, address user, int256 amount) external;
    //
    //    function claimStakerRewards(uint32 pool) external;


}

contract StkrPool is OwnableUpgradeSafe, Lockable {
    using SafeMath for uint;

    /* stake events */
    event StakePending(address indexed staker, uint32 pool, uint64 amount);
    event StakeConfirmed(address indexed staker, uint32 pool, uint64 amount);

    /* provider events (once provider reach PROVIDER_SLASH_THRESHOLD negative balance we must slash him) */
    event ProviderSlashed(address indexed provider);

    /* pool events */
    event PoolPushWaiting(uint256 indexed pool);
    event PoolOnGoing(uint256 indexed pool);
    event PoolCompleted(uint256 indexed pool);
    event PoolClosed(uint256 indexed pool);

    /* distribution events */
    event RewardClaimed (uint32 pool, address user, uint256 amount);

    enum PoolStatus {
        /* pending pool just doesn't exist */
        PushWaiting,
        OnGoing,
        Completed,
        /* QUESTION: does it possible to cancel pool? how does cancellation work? */
        Canceled
    }

    enum PoolType {ANKR, ETH}

    uint256 private PROVIDER_SLASH_THRESHOLD = 2 ether;
    address private DEVELOPER_ADDRESS = 0xb827bCA9CF96f58a7BEd49D9b5cbd84fEd72b03F;
    uint64 private PROVIDER_REWARD_SHARE = 10;
    uint64 private REQUESTER_REWARD_SHARE = 77;
    uint64 private STAKING_REWARD_SHARE = 10;
    uint64 private DEVELOPER_REWARD_SHARE = 3;

    IAETH private _aethContract;

    IStaking private _stakingContract;

    SystemParameters private _systemParameters;

    /* list with active pools */
    Pool[] private _pools;

    /* (pool index => participants) */
    mapping(uint256 => HashSet) _participants;

    /* this structure stores hash set */
    struct HashSet {
        mapping(address => uint256) index;
        address[] users;
    }

    /* 20+8=28 (1 word, 20k/5k) */
    struct PendingStake {
        address staker;
        uint64 amount;
    }

    PendingStake[] private _pendingStakes;
    /* current pending gwei amount for next pool */
    uint64 private _pendingAmount;

    /* 1+8*2=17 (1 word, 20k/5k), 32-17=15 bytes */
    struct Pool {
        PoolStatus status;
        uint64 rewarded; /* its better to store balance in gwei because beacon chain also stores it in gwei */
        uint64 slashed;
        // Question: we should know the provider before deposit on contract. because
        mapping(address => uint64) providerETHShare; // might be negative
        mapping(address => uint64) stakerShare; // +2 eth
        mapping(address => uint64) claimedRewards;

        mapping(address => uint64) providerANKRShare; // might be negative
        // providerShare+stakerShare = -1.5+2 = 0.5

        /* we don't need provider with his staking amount also */
    }

    function stake() public payable {
        _stakeUntilPossible(msg.value);
    }

    // TODO: implement
    function topUpSecureDepositWithAnkr() {}

    function topUpSecureDepositWithEth(uint64 poolIndex) public payable {
        require(value % 1e9 == 0, "amount shouldn't have a remainder");
        _pools[poolIndex].providerETHShare += msg.value;
    }

    function _stakeUntilPossible(uint256 msgValue) private {
        require(msg.value % 1e9 == 0, "amount shouldn't have a remainder");
        /* check for min stake amount also here */
        PendingStake memory _stake;
        while (msgValue > 0) {
            uint256 pendingPoolIndex = _pools.length;
            uint256 pendingRemained = 32e18 - _pendingAmount * 1e9;
            uint256 possibleStakeAmount = Math.min(pendingRemained, msgValue);
            _stake.staker = msg.sender;
            _stake.amount = uint64(possibleStakeAmount.div(1e9));

            _pendingStakes.push(_stake);
            /* QUESTION: should we reserve resources to compensate gas consumption for last player (who closed pool)? how to motivate players to close pools? */
            _pendingAmount += _stake.amount;
            /* lets remember this user as possible pool participant */
            emit StakePending(msg.sender, uint32(pendingPoolIndex), _stake.amount);
            /* check pool close condition */
            if (msgValue >= pendingRemained) {
                _closePendingPool();
            }
            msgValue -= possibleStakeAmount;
        }
    }

    function _ensurePoolParticipation(uint256 pool, address user) private {
        HashSet storage participants = _participants[pool];
        if (participants.index[user] > 0) return;
        participants.index[user] = participants.users.length + 1;
        participants.users.push(user);
    }

    function _closePendingPool() private {
        uint256 nextPoolIndex = _pools.length;
        /* we pay only 20k+5k for creation (1 byte in reserve), tbh we pay additional 15k for length creation when length is 0 */
        Pool memory _pool;
        _pool.status = PoolStatus.PushWaiting;
        _pools.push(_pool);

        Pool storage newPool = _pools[_pools.length - 1];

        for (uint i = 0; i < _pendingStakes.length; i++) {
            PendingStake memory pendingStake = _pendingStakes[i];
            newPool.stakerShare[pendingStake.staker] += pendingStake.amount;
            /* QUESTION: do we need to emit AETH creation here? */
            emit StakeConfirmed(pendingStake.staker, uint32(nextPoolIndex), pendingStake.amount);
        }
        /* releases (N+1)*10k + 10k gas */
         delete _pendingStakes;
        _pendingAmount = 0;
        emit PoolPushWaiting(nextPoolIndex);
    }

    function proposeRewardOrSlashing(uint32 pool, address user, uint64 rewarded, uint64 slashed, bytes32 transactionHash) public onlyOwner {
        /* QUESTION: do we need to store proofs from beacon chain? (for example, transaction hash or slot number) */
        Pool storage thatPool = _pools[pool];
        require(thatPool.status == PoolStatus.OnGoing, "can't reward non-ongoing pool");
        require(rewarded % 1e9 == 0, "rewarded amount shouldn't have a remainder");
        require(slashed % 1e9 == 0, "slashed amount shouldn't have a remainder");
        /* increase total rewards */
        // Question: why we have provider share here? share must exists before rewarding
        thatPool.providerShare[user] += uint64((rewarded - slashed) / 1e9);
        /* make sure provider has index */
        thatPool.rewarded += rewarded / 1e9;
        thatPool.slashed += slashed / 1e9;
        _pools[pool] = thatPool;
        /* implement provider ban logic */
        /* emit reward or slashing proposed event */
        /* add aeth migration logic */
    }

    function calcStakerRewards(address user, uint32 pool) public view returns (uint64) {
        Pool storage thatPool = _pools[pool];
        uint256 poolRewards = thatPool.rewarded + thatPool.slashed;
        /* stakers can get only 77% of their stakes */
        uint256 totalProviderRewards = PROVIDER_REWARD_SHARE * poolRewards / 100;
        uint256 totalStakerRewards = REQUESTER_REWARD_SHARE * poolRewards / 100;
        /* calculate total rewards = provider rewards + staker rewards - claimed rewards */
        uint256 providerReward = thatPool.providerShare[user] / totalProviderRewards;
        uint256 stakerReward = thatPool.stakerShare[user] / totalStakerRewards;
        uint256 claimedReward = thatPool.claimedRewards[user];
        /* return user rewards in gwei */
        return uint64(providerReward + stakerReward - claimedReward);
    }

    function claimStakerRewards(address user, uint32 pool) public {
        Pool storage thatPool = _pools[pool];
        uint64 totalRewards = calcStakerRewards(user, pool);
        /* increase total claimed amount and fire events */
        thatPool.claimedRewards[user] += totalRewards;
        uint256 aethToDistribute = totalRewards * 1e9;
        /* distribute AETH tokens */
        emit RewardClaimed(pool, user, aethToDistribute);
    }

    function calcDeveloperRewards(uint32 pool) public view returns (uint64) {
        Pool storage thatPool = _pools[pool];
        require(thatPool.status == PoolStatus.Completed, "only completed pool can be distributed");
        uint256 poolRewards = thatPool.rewarded + thatPool.slashed;
        /* developers get 3% of all rewards */
        uint256 developerReward = DEVELOPER_REWARD_SHARE * poolRewards / 100;
        uint256 claimedReward = thatPool.claimedRewards[DEVELOPER_ADDRESS];
        /* return user rewards in gwei */
        return uint64(developerReward - claimedReward);
    }

    function claimDeveloperRewards(uint32 pool) public onlyOwner {
        Pool storage thatPool = _pools[pool];
        uint64 totalRewards = calcStakerRewards(DEVELOPER_ADDRESS, pool);
        /* increase total claimed amount and fire events */
        thatPool.claimedRewards[DEVELOPER_ADDRESS] += totalRewards;
        uint256 aethToDistribute = totalRewards * 1e9;
        /* distribute AETH tokens */
        emit RewardClaimed(pool, DEVELOPER_ADDRESS, aethToDistribute);
    }

    function poolCount() public view returns (uint256) {
        return _pools.length;
    }

    function updateAETHContract(address payable tokenContract) external onlyOwner {
        _aethContract = IAETH(tokenContract);
    }

    function updateParameterContract(address paramContract) external onlyOwner {
        _systemParameters = SystemParameters(paramContract);
    }

    function updateStakingContract(address stakingContract) external onlyOwner {
        _stakingContract = IStaking(stakingContract);
    }
}
