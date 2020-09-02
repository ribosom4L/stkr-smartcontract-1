// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "./lib/SafeMath.sol";
import "./OwnedByGovernor.sol";

abstract contract TokenContract {
    function mint(address account, uint256 amount) external virtual;
}

contract MicroPool is OwnedByGovernor {
    using SafeMath for uint256;

    enum PoolStatus {Initialized, Pending, OnGoing, Completed, Canceled}

    struct PoolStake {
        uint256 amount;
        uint256 fee;
        bool isClaimed;
    }

    struct Pool {
        PoolStatus status;
        uint256 startTime; // init time
        uint256 endTime; // canceled or completed time
        uint256 rewardBalance; // total balance after rewarded
        uint256 claimedBalance; // pool members' claimed amount
        uint256 providerOwe; // TODO: who will decide it? governor, this contract, etc.
        uint256 nodeFee; // eth price
        uint256 totalStakedAmount; // total amount of user stakes
        uint256 numberOfSlashing;
        address payable provider; // provider address
        address payable validator; // validator address
        // address payable[] members; // pool members
        mapping(address => PoolStake) stakes; // stakes of a pool members
    }

    Pool[] private _pools;
    bool private _claimable = false; // governors will make it true after ETH 2.0
    TokenContract private _tokenContract;

    event PoolCreated(
        uint256 indexed poolIndex,
        address payable indexed provider,
        address payable indexed validator,
        address creator
    );
    event UserStaked(
        uint256 indexed poolIndex,
        address indexed user,
        uint256 stakeAmount
    );
    event UserUnstaked(
        uint256 indexed poolIndex,
        address indexed user,
        uint256 unstakeAmount
    );

    constructor(
        TokenContract tokenContract
    ) public {
        _tokenContract = tokenContract;
    }

    /**
        Governor can call this function to create a new pool for given provider.
        @param provider address
        @param validator address
        @param providerOwe uint256
    */
    function initializePool(
        address payable provider,
        address payable validator,
        uint256 providerOwe
    ) external onlyGovernor {
        // TODO: validations
        // TODO: _nodeFee usd to eth
        Pool memory pool;
        pool.provider = provider;
        pool.validator = validator;
        pool.providerOwe = providerOwe;
        pool.startTime = block.timestamp;
        if (providerOwe > 0) {
            pool.status = PoolStatus.Initialized;
        } else {
            pool.status = PoolStatus.Pending;
        }
        _pools.push(pool);
        emit PoolCreated(_pools.length.sub(1), provider, validator, msg.sender);
    }

    /**
        Users can call to stake to given pool
        @param poolIndex uint256
    */
    // TODO: not mint AETH directly, wait for pool reach 32 eth.
    function stake(uint256 poolIndex) external payable {
        // TODO: validations

        Pool storage pool = _pools[poolIndex];
        uint256 fee = msg.value.div(32 ether).mul(pool.nodeFee);
        uint256 stakeAmount = msg.value.sub(fee);
        // TODO: min. stake amount
        require(stakeAmount > 0, "You don't have enough balance.");

        if (pool.status == PoolStatus.Initialized) {
            pool.status = PoolStatus.Pending;
        }

        uint256 newTotalAmount = stakeAmount.add(pool.totalStakedAmount);
        if (newTotalAmount >= 32 ether) {
            pool.status = PoolStatus.OnGoing;
            uint256 excessAmount = newTotalAmount.sub(32 ether);
            if (excessAmount > 0) {
                stakeAmount = stakeAmount.sub(excessAmount);
                msg.sender.transfer(excessAmount);
            }
        }
        pool.totalStakedAmount = pool.totalStakedAmount.add(stakeAmount);

        PoolStake storage userStake = pool.stakes[msg.sender];

        userStake.amount = userStake.amount.add(stakeAmount);
        userStake.fee = userStake.fee.add(fee);
        pool.stakes[msg.sender] = userStake;

        // Mint AEth for user
        _tokenContract.mint(msg.sender, stakeAmount.div(2));

        emit UserStaked(poolIndex, msg.sender, stakeAmount);
    }

    /**
        Users can call to unstake from given pool
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
        //     _tokenContract.burnFrom(
        //         msg.sender,
        //         pool.stakes[msg.sender].amount.div(2)
        //     ),
        //     "You need to approve this contract first."
        // );

        uint256 unstakeAmount = pool.stakes[msg.sender].amount.add(
            pool.stakes[msg.sender].fee
        );

        msg.sender.transfer(unstakeAmount);
        pool.totalStakedAmount = pool.totalStakedAmount.sub(pool.stakes[msg.sender].amount);
        delete pool.stakes[msg.sender];

        emit UserStaked(poolIndex, msg.sender, unstakeAmount);
    }

    /**
        Governer calls this function to change aEth token contract address
        @param tokenContract address
    */
    function updateTokenContract(TokenContract tokenContract)
        external
        onlyGovernor
    {
        _tokenContract = tokenContract;
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
            uint256 rewardBalance,
            uint256 claimedBalance,
            uint256 providerOwe,
            uint256 nodeFee,
            uint256 totalStakedAmount,
            address payable provider,
            address payable validator
        )
    //address payable[] memory members
    {
        Pool memory pool = _pools[poolIndex];
        status = pool.status;
        startTime = pool.startTime;
        endTime = pool.endTime;
        rewardBalance = pool.rewardBalance;
        claimedBalance = pool.claimedBalance;
        providerOwe = pool.providerOwe;
        nodeFee = pool.nodeFee;
        totalStakedAmount = pool.totalStakedAmount;
        provider = pool.provider;
        validator = pool.validator;
        //members = pool.members;
    }

    function claimable() public view returns (bool) {
        return _claimable;
    }
}
