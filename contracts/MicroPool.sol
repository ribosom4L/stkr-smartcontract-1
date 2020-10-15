// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "./lib/SafeMath.sol";
import "./core/OwnedByGovernor.sol";

interface IDepositContract {
    /// @notice A processed deposit event.
    event DepositEvent(
        bytes pubkey,
        bytes withdrawal_credentials,
        bytes amount,
        bytes signature,
        bytes index
    );

    /// @notice Submit a Phase 0 DepositData object.
    /// @param pubkey A BLS12-381 public key.
    /// @param withdrawal_credentials Commitment to a public key for withdrawals.
    /// @param signature A BLS12-381 signature.
    /// @param deposit_data_root The SHA-256 hash of the SSZ-encoded DepositData object.
    /// Used as a protection against malformed input.
    function deposit(
        bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root
    ) external payable;

    /// @notice Query the current deposit root hash.
    /// @return The deposit root hash.
    function get_deposit_root() external view returns (bytes32);

    /// @notice Query the current deposit count.
    /// @return The deposit count encoded as a little endian 64-bit number.
    function get_deposit_count() external view returns (bytes memory);
}

interface TokenContract {
    function mint(address account, uint256 amount) external;

    function updateMicroPoolContract(address microPoolContract) external;
}

contract MicroPool is OwnedByGovernor {
    using SafeMath for uint256;

    enum PoolStatus {Pending, OnGoing, Completed, Canceled}

    struct PoolStake {
        uint256 amount;
        uint256 fee;
        bool isClaimed;
    }

    struct BeaconDeposit {
        bytes pubkey;
        bytes withdrawal_credentials;
        bytes signature;
        bytes32 deposit_data_root;
    }

    struct Pool {
        PoolStatus status;
        bytes32 name;
        uint256 startTime; // init time
        uint256 endTime; // canceled or completed time
        uint256 rewardBalance; // total balance after rewarded
        uint256 claimedBalance; // pool members' claimed amount
        uint256 compensatedBalance; // TODO: is required?
        uint256 providerOwe; // TODO: who will decide it? governor, this contract, etc.
        uint256 nodeFee; // eth price
        uint256 totalStakedAmount; // total amount of user stakes
        uint256 numberOfSlashing;
        uint256 totalSlashedAmount;
        address payable provider; // provider address
        address payable validator; // validator address
        // address payable[] members; // pool members
        mapping(address => PoolStake) stakes; // stakes of a pool members

        BeaconDeposit depositData;
    }

    Pool[] private _pools;
    bool private _claimable = false; // governors will make it true after ETH 2.0
    address private _tokenContract;
    address _insuranceContract;
    address _beaconContract = 0x07b39F4fDE4A38bACe212b546dAc87C58DfE3fDC;

    // 1000 ANKR
    // TODO: Change
    uint256 private CREATION_FEE = 1e21;

    // USDT
    // TODO: Change
    uint256 private PARTICIPATION_FEE = 10;

    event PoolCreated(
        uint256 indexed poolIndex,
        address payable indexed provider
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

    constructor(address tokenContract) public {
        _tokenContract = tokenContract;
        TokenContract(tokenContract).updateMicroPoolContract(address(this));
    }

    function pushToBeacon(uint256 poolIndex) public onlyGovernor {
        Pool storage pool = _pools[poolIndex];

        require(pool.validator != address(0), "Pool requires deposit data");
        require(pool.totalStakedAmount >= 32 ether && pool.status == PoolStatus.OnGoing, "Not enough ether");
        uint256 ethersToSend = pool.totalStakedAmount;

        pool.totalStakedAmount = 0;

        IDepositContract(_beaconContract).deposit{value : ethersToSend}(pool.depositData.pubkey, pool.depositData.withdrawal_credentials, pool.depositData.signature, pool.depositData.deposit_data_root);
    }

    function updatePoolData(
        uint256 poolIndex,
        address payable validator,
        bytes memory pubkey,
        bytes memory withdrawal_credentials,
        bytes memory signature,
        bytes32 deposit_data_root) public {

        BeaconDeposit memory d;
        Pool memory pool = _pools[poolIndex];
        d.pubkey = pubkey;
        d.withdrawal_credentials = withdrawal_credentials;
        d.signature = signature;
        d.deposit_data_root = deposit_data_root;

        pool.validator = validator;
        pool.depositData = d;
        // pool.providerOwe = providerOwe;
        pool.startTime = block.timestamp;
        _pools[poolIndex] = pool;
    }

    /**
        Providers can call this function to create a new pool.
    */
    function initializePool(bytes32 name) external {
        // TODO: validations
        // TODO: _nodeFee usd to eth
        Pool memory pool;

        pool.provider = msg.sender;
        pool.name = name;
        // pool.providerOwe = providerOwe;
        pool.startTime = block.timestamp;
        _pools.push(pool);

        emit PoolCreated(
            _pools.length.sub(1),
            msg.sender
        );
    }

    /**
        Users can call to stake to given pool
        @param poolIndex uint256
    */
    // TODO: not mint AETH directly, wait for pool reach 32 eth.
    function stake(uint256 poolIndex) external payable {
        Pool storage pool = _pools[poolIndex];
        require(pool.status == PoolStatus.Pending, "cannot stake to this pool");

        uint256 fee = msg.value.div(32 ether).mul(pool.nodeFee);
        uint256 stakeAmount = msg.value.sub(fee);
        // TODO: min. stake amount
        require(stakeAmount > 0, "You don't have enough balance.");

        pool.totalStakedAmount = pool.totalStakedAmount.add(stakeAmount);
        if (pool.totalStakedAmount >= 32 ether) {
            pool.status = PoolStatus.OnGoing;
            uint256 excessAmount = pool.totalStakedAmount.sub(32 ether);
            if (excessAmount > 0) {
                stakeAmount = stakeAmount.sub(excessAmount);
                msg.sender.transfer(excessAmount);
            }
        }


        PoolStake storage userStake = pool.stakes[msg.sender];

        userStake.amount = userStake.amount.add(stakeAmount);
        userStake.fee = userStake.fee.add(fee);
        pool.stakes[msg.sender] = userStake;

        emit UserStaked(poolIndex, msg.sender, stakeAmount);

        // Mint AEth for user
        // TokenContract(_tokenContract).mint(msg.sender, stakeAmount.div(2));
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
        //     TokenContract(_tokenContract).burnFrom(
        //         msg.sender,
        //         pool.stakes[msg.sender].amount.div(2)
        //     ),
        //     "You need to approve this contract first."
        // );

        uint256 unstakeAmount = pool.stakes[msg.sender].amount.add(
            pool.stakes[msg.sender].fee
        );

        msg.sender.transfer(unstakeAmount);
        pool.totalStakedAmount = pool.totalStakedAmount.sub(
            pool.stakes[msg.sender].amount
        );
        delete pool.stakes[msg.sender];

        emit UserStaked(poolIndex, msg.sender, unstakeAmount);
    }

    // TODO: only Insurance contract can call this
    function updateSlashingOfAPool(uint256 poolIndex, uint256 compensatedAmount)
    public
    returns (bool)
    {
        // TODO: validations

        Pool storage pool = _pools[poolIndex];
        pool.compensatedBalance = pool.compensatedBalance.add(
            compensatedAmount
        );

        return true;
    }

    /**
        Governer calls this function to change aEth token contract address
        @param tokenContract address
    */
    function updateTokenContract(address tokenContract) external onlyGovernor {
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
        bytes32 name,
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
        name = pool.name;
        //members = pool.members;
    }

    function updateInsuranceContract(address addr) public onlyGovernor {
        _insuranceContract = addr;
    }

    function claimable() public view returns (bool) {
        return _claimable;
    }

    // TODO: Only for development
    function getBack() public payable {
        msg.sender.transfer(address(this).balance);
    }
}
