// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "./lib/interfaces/IDepositContract.sol";
import "./SystemParameters.sol";
import "./lib/Lockable.sol";
import "./lib/interfaces/IAETH.sol";

interface IStaking {
    function compensatePoolLoss(address provider, uint256 amount, uint256 providerStakeAmount) external returns (uint256);

    function freeze(address user, uint256 amount) external returns (bool);

    function unfreeze(address user, uint256 amount) external returns (bool);

    function reward(uint256 poolIndex) payable external;
}

contract MicroPool is OwnableUpgradeSafe, Lockable {
    using SafeMath for uint256;

    enum PoolStatus {Pending, PushWaiting, OnGoing, Completed, Canceled}


    // claimable amount = amount + reward - claimedAmount
    struct PoolStake {
        uint256 amount;
        uint256 reward;
        uint256 claimedAmount;
    }

    struct Migration {
        address payable previousProvider;
        address payable newProvider;
        uint256 rewardForPreviousProvider;
        bool rewardClaimed;
    }

    struct Pool {
        PoolStatus status;
        bytes32 name;
        uint256 startTime; // init time
        uint256 endTime; // canceled or completed time
        bool claimable;
        uint256 claimed; // total claimed balance
        uint256 balance; // total amount of user stakes
        uint256 lastSlashings; // current updated slashings
        uint256 lastReward; // current updated reward
        uint256 requesterRewards;
        uint8 migrationCount;
        // Provider default staking amount can change on process
        // in case of migrations, we have to store current provider's ankr staking amount
        uint256 providerTokenStakeAmount;

        address validator; // validator address
        address payable provider; // provider address
        //        address payable[] members; // pool members
        mapping(address => PoolStake) stakes; // stakes of a pool members
    }

    Pool[] private _pools;
    mapping(address => uint256) public pendingPools; // provider -> pool ID

    IAETH public _aethContract;

    IStaking public _stakingContract;

    SystemParameters public _systemParameters;

    address payable _depositContract;

    event PoolCreated(
        uint256 indexed poolIndex,
        address payable indexed provider
    );

    event PoolOnGoing(
        uint256 indexed poolIndex
    );

    event PoolMigrated(
        uint256 indexed poolIndex,
        address payable indexed newProvider,
        address payable indexed previousProvider,
        uint256 slashings,
        uint256 poolBalance,
        uint256 compensated
    );

    event UserStaked(
        uint256 indexed poolIndex,
        address indexed user,
        uint256 stakeAmount
    );

    event UserUnstaked(
        uint256 indexed poolIndex,
        address indexed staker,
        uint256 unstakeAmount
    );

    event PoolReward(
        uint256 indexed poolIndex,
        uint256 reward,
        uint256 slashings
    );

    event AETHClaim(uint256 indexed poolIndex, address staker, uint256 amount);

    function initialize(address payable aethContract, address systemParameters, address payable beaconContract) public initializer {
        OwnableUpgradeSafe.__Ownable_init();

        _aethContract = IAETH(aethContract);

        _systemParameters = SystemParameters(systemParameters);

        // this is for initialization
        // to avoid index 0 pool
        Pool memory pool;
        pool.status = PoolStatus.Canceled;
        _pools.push(pool);

        _depositContract = beaconContract;
    }

    function pushToBeacon(uint256 poolIndex,
        bytes memory pubkey,
        bytes memory withdrawal_credentials,
        bytes memory signature,
        bytes32 deposit_data_root) public onlyOwner {

        Pool storage pool = _pools[poolIndex];

        require(pool.status == PoolStatus.PushWaiting, "Pool status not allow to push");
        require(pool.balance >= 32 ether, "Not enough ether");

        pool.status = PoolStatus.OnGoing;

        address validator = address(bytes20(keccak256(pubkey)));

        uint256 ethersToSend = pool.balance;

        pool.balance = 0;
        pool.validator = validator;
        pool.startTime = block.timestamp;

        _aethContract.mint(address(this), ethersToSend);

        pendingPools[msg.sender] = 0;

        IDepositContract(_depositContract).deposit{value : ethersToSend}(pubkey, withdrawal_credentials, signature, deposit_data_root);
        emit PoolOnGoing(poolIndex);
    }

    /**
        Providers can call this function to create a new pool.
    */
    function initializePool(bytes32 name) external {
        require(pendingPools[msg.sender] == 0, "User already have a pending pool");
        uint256 minimumStakingAmount = _systemParameters.PROVIDER_MINIMUM_STAKING();
        // freeze staked ankr
        require(_stakingContract.freeze(msg.sender, minimumStakingAmount));

        Pool memory pool;

        pool.provider = msg.sender;
        pool.name = name;
        pool.startTime = block.timestamp;
        pool.providerTokenStakeAmount = minimumStakingAmount;
        _pools.push(pool);

        uint256 index = _pools.length.sub(1);
        pendingPools[msg.sender] = index;

        emit PoolCreated(
            index,
            msg.sender
        );
    }

    /**
        Users can call to stake to given pool
        @param poolIndex uint256
    */
    function stake(uint256 poolIndex) payable external {
        Pool storage pool = _pools[poolIndex];

        // Pool must be pending status to participate
        require(pool.status == PoolStatus.Pending, "Cannot stake to this pool");

        uint256 stakeAmount = msg.value;

        // value must be greater than minimum staking amount
        require(stakeAmount >= _systemParameters.REQUESTER_MINIMUM_POOL_STAKING(), "Ethereum value must be greater than minimum staking amount");

        pool.balance = pool.balance.add(stakeAmount);
        if (pool.balance >= 32 ether) {

            pool.status = PoolStatus.PushWaiting;

            pendingPools[msg.sender] = 0;

            uint256 excessAmount = pool.balance.sub(32 ether);

            if (excessAmount > 0) {
                stakeAmount = stakeAmount.sub(excessAmount);
                pool.balance = pool.balance.sub(excessAmount);
                msg.sender.transfer(excessAmount);
            }
        }


        PoolStake storage userStake = pool.stakes[msg.sender];

        userStake.amount = userStake.amount.add(stakeAmount);
        pool.stakes[msg.sender] = userStake;

        emit UserStaked(poolIndex, msg.sender, stakeAmount);
    }

    /**
        Users can call to unstake from given pool
        until pool start
        @param poolIndex uint256
    */
    function unstake(uint256 poolIndex) external payable {
        Pool storage pool = _pools[poolIndex];
        // TODO: validations
        require(
            pool.status == PoolStatus.Pending,
            "You can only cancel your stake from a pending pool."
        );
        require(
            pool.stakes[msg.sender].amount > 0,
            "You don't have staked balance in this pool"
        );
        // require(
        //     IAETH(_aethContract).burnFrom(
        //         msg.sender,
        //         pool.stakes[msg.sender].amount.div(2)
        //     ),
        //     "You need to approve this contract first."
        // );

        uint256 unstakeAmount = pool.stakes[msg.sender].amount;

        msg.sender.transfer(unstakeAmount);
        pool.balance = pool.balance.sub(
            pool.stakes[msg.sender].amount
        );
        delete pool.stakes[msg.sender];

        emit UserStaked(poolIndex, msg.sender, unstakeAmount);
    }

    function rewardMicropool(uint256 poolIndex, uint256 slashings)
    public
    payable
    onlyOwner {
        Pool storage pool = _pools[poolIndex];
        require(pool.status == PoolStatus.OnGoing, "Pool cannot be rewarded");

        pool.status = PoolStatus.Completed;

        require(slashings >= pool.lastSlashings, "Current slashings cannot be smaller than last slashings");

        uint256 slash = slashings - pool.lastSlashings;

        uint256 totalReward = msg.value > 32 ether ? msg.value.sub(32 ether) : 0;

        uint256 currentReward = msg.value.add(slashings).sub(32 ether);

        uint256 reward = currentReward.sub(pool.lastReward);

        uint256 providerReward = currentReward.sub(pool.lastReward).div(10);

        // TODO: what if staked ankr cannot compensate the loss ?
        if (slash > providerReward) {
            uint256 difference = slash - providerReward;

            _stakingContract.compensatePoolLoss(pool.provider, difference, pool.providerTokenStakeAmount);
            providerReward = 0;
        } else if (slash < providerReward) {
            // if provider has positive balance in reward
            providerReward = providerReward - slash;
            // mint aeth
            _aethContract.mintFrozen(pool.provider, providerReward);
        }

        pool.lastSlashings = slashings;
        pool.lastReward = currentReward;

        // requesters
        uint256 requesterRewards = pool.lastReward.mul(77).div(100);
        uint256 stakingRewards = pool.lastReward.mul(10).div(100);
        uint256 developerRewards = pool.lastReward.mul(3).div(100);

        pool.requesterRewards = requesterRewards;
        pool.status = PoolStatus.Completed;

        _stakingContract.reward{value : stakingRewards}(poolIndex);

        // TODO: Developer rewards

        _aethContract.mintPool{value : requesterRewards}();

        emit PoolReward(poolIndex, pool.lastReward, slashings);
    }

    function migrate(uint256 poolIndex, uint256 currentPoolBalance, uint256 currentSlashings, address payable newProvider) public onlyOwner {
        Pool storage pool = _pools[poolIndex];

        require(currentSlashings >= pool.lastSlashings, "Current slashings cannot be smaller than last slashings");

        address payable oldProvider = pool.provider;

        pool.provider = newProvider;

        uint256 minimumStakingAmount = _systemParameters.PROVIDER_MINIMUM_STAKING();

        require(_stakingContract.freeze(pool.provider, minimumStakingAmount));

        uint256 slash = currentSlashings - pool.lastSlashings;

        require(slash >= _systemParameters.SLASHINGS_FOR_MIGRATION(), "Slashing amount lower than system parameter");

        uint256 currentReward = currentPoolBalance.add(currentSlashings).sub(32 ether, "Current reward: substraction");

        uint256 reward = currentReward.sub(pool.lastReward, "Reward: substraction");

        uint256 providerReward = reward.div(10);

        uint256 compensatedAnkrAmount = 0;

        // TODO: what if staked ankr cannot compensate the loss ?
        if (slash > providerReward) {
            uint256 difference = slash - providerReward;

            compensatedAnkrAmount = _stakingContract.compensatePoolLoss(oldProvider, difference, pool.providerTokenStakeAmount);
        } else if (slash < providerReward) {
            // if provider has positive balance in reward
            uint256 difference = providerReward - slash;
            // unfreeze frozen staking amount
            _stakingContract.unfreeze(oldProvider, pool.providerTokenStakeAmount);
            // mint frozen aeth for provider
            _aethContract.mintFrozen(oldProvider, difference);
        }

        pool.lastSlashings = currentSlashings;
        pool.lastReward = currentReward;
        pool.providerTokenStakeAmount = minimumStakingAmount;
        pool.migrationCount++;

        emit PoolMigrated(poolIndex, newProvider, oldProvider, currentSlashings, currentPoolBalance, compensatedAnkrAmount);
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

    function claimAeth(uint256 poolIndex) unlocked(msg.sender) external {
        Pool storage pool = _pools[poolIndex];

        require(pool.status == PoolStatus.Completed || pool.status == PoolStatus.OnGoing, "Pool not claimable");

        PoolStake storage poolStake = pool.stakes[msg.sender];

        uint256 claimable = poolStake.amount.add(pool.requesterRewards).mul(poolStake.amount).div(32 ether).sub(poolStake.claimedAmount);

        require(claimable > 0, "Claimable amount must be bigger than zero");

        poolStake.claimedAmount = poolStake.claimedAmount.add(claimable);

        _aethContract.transfer(msg.sender, claimable);

        emit AETHClaim(poolIndex, msg.sender, claimable);
    }

    /**
        Get pool details for given pool array index

        @param poolIndex uint256
    */
    function poolDetails(uint256 poolIndex)
    public
    view
    returns (
        PoolStatus status,
        uint256 startTime,
        uint256 endTime,
        uint256 lastReward,
        uint256 lastSlashings,
        bytes32 name,
        uint256 balance,
        address validator,
        address payable provider
    )
        //address payable[] memory members
    {
        Pool memory pool = _pools[poolIndex];
        status = pool.status;
        startTime = pool.startTime;
        endTime = pool.endTime;
        lastReward = pool.lastReward;
        lastSlashings = pool.lastSlashings;
        balance = pool.balance;
        provider = pool.provider;
        validator = pool.validator;
        name = pool.name;
        //members = pool.members;
    }

    function poolCount() public view returns (uint256) {
        return _pools.length;
    }

    function userStakeAmount(uint256 poolIndex, address addr) public view returns (uint256) {
        return _pools[poolIndex].stakes[addr].amount;
    }

    function changeDepositContract(address payable depositContract) public onlyOwner {
        _depositContract = depositContract;
    }

    // TODO: Only for development
    function getBack() public payable {
        msg.sender.transfer(address(this).balance);
    }
}
