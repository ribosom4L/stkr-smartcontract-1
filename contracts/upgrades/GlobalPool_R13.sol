// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.11;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "../lib/interfaces/IDepositContract.sol";
import "../SystemParameters.sol";
import "../lib/Lockable.sol";
import "../lib/interfaces/IAETH.sol";
import "../lib/interfaces/IConfig.sol";
import "../lib/interfaces/IStaking.sol";
import "../lib/interfaces/IDepositContract.sol";
import "../lib/Pausable.sol";

contract GlobalPool_R13 is Lockable, Pausable {

    using SafeMath for uint256;
    using Math for uint256;

    /* staker events */
    event StakePending(address indexed staker, uint256 amount);
    event StakeConfirmed(address indexed staker, uint256 amount);
    event StakeRemoved(address indexed staker, uint256 amount);

    /* pool events */
    event PoolOnGoing(bytes pool);
    event PoolCompleted(bytes pool);

    /* provider events */
    event ProviderSlashedAnkr(address indexed provider, uint256 ankrAmount, uint256 etherEquivalence);
    event ProviderSlashedEth(address indexed provider, uint256 amount);
    event ProviderToppedUpEth(address indexed provider, uint256 amount);
    event ProviderToppedUpAnkr(address indexed provider, uint256 amount);
    event ProviderExited(address indexed provider);

    /* rewards (AETH) */
    event RewardClaimed(address indexed staker, uint256 amount);

    mapping(address => uint256) private _pendingUserStakes;
    mapping(address => uint256) private _userStakes;

    mapping(address => uint256) private _rewards;
    mapping(address => uint256) private _claims;

    mapping(address => uint256) private _etherBalances;
    mapping(address => uint256) private _slashings;

    mapping(address => uint256) private _exits;

    // Pending staker list
    address[] private _pendingStakers;
    // total pending amount
    uint256 private _pendingAmount;
    // total stakes of all users
    uint256 private _totalStakes;
    // total rewards for all stakers
    uint256 private _totalRewards;

    IAETH private _aethContract;

    IStaking private _stakingContract;

    SystemParameters private _systemParameters;

    address _depositContract;

    address[] private _pendingTemp;

    modifier notExitRecently(address provider) {
        require(block.number > _exits[provider].add(_configContract.getConfig("EXIT_BLOCKS")), "Recently exited");
        _;
    }

    function initialize(IAETH aethContract, SystemParameters parameters, address depositContract) public initializer {
        __Ownable_init();

        _depositContract = depositContract;
        _aethContract = aethContract;
        _systemParameters = parameters;
        _paused["topUpETH"] = true;
        _paused["topUpANKR"] = true;
    }

    function pushToBeacon(bytes calldata pubkey,
        bytes calldata withdrawal_credentials,
        bytes calldata signature,
        bytes32 deposit_data_root) public onlyOwner {

        require(_pendingAmount >= 32 ether, "pending ethers not enough");
        // substract 32 ether from pending amount
        _pendingAmount = _pendingAmount.sub(32 ether);

        // mint aETH
        uint256 mintAmount = _aethContract.mint(address(this), 32 ether);

        uint256 _amount = 0;
        uint256 i = _pendingStakers.length >= _lastPendingStakerPointer ? _lastPendingStakerPointer : _lastPendingStakerPointer.sub(1);

        while (_amount < 32 ether) {
            address staker = _pendingStakers[i];
            i++;
            uint256 userStake = _pendingUserStakes[staker];
            // if user dont have any stake...
            if (userStake == 0) continue;

            uint256 providerStake = _pendingEtherBalances[staker];

            _amount = _amount.add(userStake);

            // if amount bigger then 32 ethereum, give back remaining user amount to pending
            if (_amount > 32 ether) {
                i--;
                uint256 remained = _amount.sub(32 ether);
                uint256 sent = userStake.sub(remained);
                // set pending user stakes to zero
                _pendingUserStakes[staker] = remained;

                if (providerStake > 0) {
                    _pendingEtherBalances[staker] = providerStake > sent ? remained : 0;
                    _etherBalances[staker] = providerStake.sub(_pendingEtherBalances[staker]);
                }

                // add reward for staker
                _rewards[staker] = _rewards[staker].add(sent.mul(mintAmount).div(32 ether));

                emit StakeConfirmed(staker, sent);
                break;
            }
            // set pending user stakes to zero
            _pendingUserStakes[staker] = 0;
            _etherBalances[staker] = _etherBalances[staker].add(_pendingEtherBalances[staker]);

            _pendingEtherBalances[staker] = 0;
            // add reward for staker
            _rewards[staker] = _rewards[staker].add(userStake.mul(mintAmount).div(32 ether));
            emit StakeConfirmed(staker, userStake);
        }

        // clear pending stakers
        _clearPendingStakers(i);

        // send funds to deposit contract
        IDepositContract(_depositContract).deposit{value : 32 ether}(pubkey, withdrawal_credentials, signature, deposit_data_root);

        emit PoolOnGoing(pubkey);
    }

    function stake() public whenNotPaused("stake") notExitRecently(msg.sender) unlocked(msg.sender) payable {
        _stake(msg.sender, msg.value);
    }

    function _stake(address staker, uint256 value) private {
        uint256 minimumStaking = _configContract.getConfig("REQUESTER_MINIMUM_POOL_STAKING");

        require(value >= minimumStaking, "Value must be greater than zero");
        require(value % minimumStaking == 0, "Value must be multiple of minimum staking amount");

        if (_pendingUserStakes[staker] == 0) {
            _pendingStakers.push(staker);
        }

        _pendingUserStakes[staker] = _pendingUserStakes[staker].add(value);
        _pendingAmount = _pendingAmount.add(value);

        _userStakes[staker] = _userStakes[staker].add(value);

        _totalStakes = _totalStakes.add(msg.value);

        emit StakePending(staker, value);
    }

    function topUpETH() public whenNotPaused("topUpETH") notExitRecently(msg.sender) payable {
        require(_configContract.getConfig("PROVIDER_MINIMUM_ETH_STAKING") <= msg.value, "Value must be greater than minimum amount");
        delete _exits[msg.sender];

        _pendingEtherBalances[msg.sender] = _pendingEtherBalances[msg.sender].add(msg.value);
        _etherBalances[msg.sender] = _etherBalances[msg.sender].add(msg.value);

        _stake(msg.sender, msg.value);

        emit ProviderToppedUpEth(msg.sender, msg.value);
    }

    function topUpANKR(uint256 amount) public whenNotPaused("topUpANKR") notExitRecently(msg.sender) payable {
        /* Approve ankr & freeze ankr */
        require(_configContract.getConfig("PROVIDER_MINIMUM_ANKR_STAKING") <= amount, "Value must be greater than minimum amount");
        require(_stakingContract.freeze(msg.sender, amount), "Could not freeze ANKR tokens");
        emit ProviderToppedUpAnkr(msg.sender, msg.value);
    }

    // slash provider with ethereum balance
    function slash(address provider, uint256 amount) public unlocked(provider) onlyOwner {
        require(amount > 0, "Amount should be greater than zero");
        uint256 remaining = _slashETH(provider, amount);

        if (remaining == 0) {
            return;
        }

        remaining = _slashANKR(provider, remaining);

        _slashings[provider] = _slashings[provider].add(remaining);
        /*Do we need event if remaining balance higher than zero?*/
    }

    function providerExit() public {
        require(availableEtherBalanceOf(msg.sender) > 0, "Provider balance should be positive for exit");
        _exits[msg.sender] = block.number;
        emit ProviderExited(msg.sender);
    }

    function claim() public whenNotPaused("claim") notExitRecently(msg.sender) {
        _claim(msg.sender);
    }

    function claimFor(address staker) public whenNotPaused("claim") notExitRecently(staker) {
        _claim(staker);
    }

    function claimableRewardOf(address staker) public view returns (uint256) {
        uint256 blocked = _etherBalances[staker];
        uint256 reward = _rewards[staker].sub(_claims[staker]);

        return blocked >= reward ? 0 : reward.sub(blocked);
    }

    function _claim(address staker) private {
        uint256 claimable = claimableRewardOf(staker);
        require(claimable > 0, "claimable reward zero");

        _rewards[staker] = _rewards[staker];
        _claims[staker] = _claims[staker].add(claimable);

        _aethContract.transfer(staker, claimable);

        emit RewardClaimed(staker, claimable);
    }

    function unstake() public whenNotPaused("unstake") payable unlocked(msg.sender) notExitRecently(msg.sender) {
        require(_etherBalances[msg.sender] >= 0, "You have negative provider balance");

        uint256 pendingStakes = pendingStakesOf(msg.sender);

        if (_exits[msg.sender] > 0) {
            _etherBalances[msg.sender] = 0;
            _exits[msg.sender] = 0;
        }

        require(pendingStakes > 0, "No pending stakes");

        _pendingUserStakes[msg.sender] = 0;
        _pendingEtherBalances[msg.sender] = 0;

        require(msg.sender.send(pendingStakes), "could not send ethers");

        emit StakeRemoved(msg.sender, pendingStakes);
    }

    function availableEtherBalanceOf(address provider) public view returns (int256) {
        return int256(etherBalanceOf(provider) - _slashingsOf(provider));
    }

    function etherBalanceOf(address provider) public view returns (uint256) {
        return _etherBalances[provider];
    }

    function pendingEtherBalanceOf(address provider) public view returns (uint256) {
        return _pendingEtherBalances[provider];
    }

    function _slashingsOf(address provider) private view returns (uint256) {
        return _slashings[provider];
    }

    function _ankrBalanceOf(address provider) private view returns (uint256) {
        return _stakingContract.frozenStakesOf(provider);
    }

    /**
        @dev Slash eth, returns remaining needs to be slashed
    */
    function _slashETH(address provider, uint256 amount) private returns (uint256 remaining) {

        uint256 available = availableEtherBalanceOf(provider) > 0 ? uint256(availableEtherBalanceOf(provider)) : 0;

        uint256 toBeSlashed = amount.min(available);
        if (toBeSlashed == 0) return amount;

        _slashings[provider] = _slashings[provider].add(toBeSlashed);
        remaining = amount.sub(toBeSlashed);

        emit ProviderSlashedEth(provider, toBeSlashed);
    }

    function _slashANKR(address provider, uint256 amount) private returns (uint256 ankrAmount) {
        bool result;
        uint256 remaining;
        (result, ankrAmount, remaining) = _stakingContract.compensateLoss(provider, amount);
        emit ProviderSlashedAnkr(provider, ankrAmount, amount.sub(remaining));
    }

    function poolCount() public view returns (uint256) {
        return _totalStakes.div(32 ether);
    }

    function pendingStakesOf(address staker) public view returns (uint256) {
        return _pendingUserStakes[staker];
    }

    function updateAETHContract(address payable tokenContract) external onlyOwner {
        _aethContract = IAETH(tokenContract);
    }

    function updateConfigContract(address configContract) external onlyOwner {
        _configContract = IConfig(configContract);
    }

    function updateStakingContract(address stakingContract) external onlyOwner {
        _stakingContract = IStaking(stakingContract);
    }

    function _clearPendingStakers(uint256 i) private {
        uint256 arrLen = _pendingStakers.length;
        if (arrLen.sub(i) > 5) {
            _lastPendingStakerPointer = i;
            return;
        }
        // we should remove stakers from pending array length is: i
        for (uint256 j = i; j < _pendingStakers.length; j++) {
            _pendingTemp.push(_pendingStakers[j]);
        }

        _pendingStakers = _pendingTemp;
        delete _pendingTemp;
        delete _lastPendingStakerPointer;
    }

    uint256[50] private __gap;

    uint256 private _lastPendingStakerPointer;

    IConfig private _configContract;

    mapping(address => uint256) private _pendingEtherBalances;
}