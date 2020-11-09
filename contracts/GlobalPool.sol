// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.11;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "./lib/interfaces/IDepositContract.sol";
import "./SystemParameters.sol";
import "./lib/Lockable.sol";
import "./lib/interfaces/IAETH.sol";
import "./lib/interfaces/IStaking.sol";
import "./lib/interfaces/IDepositContract.sol";
import "./lib/Pausable.sol";

contract GlobalPool is Lockable, Pausable {

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

    mapping (address => uint256) private _pendingUserStakes;
    mapping (address => uint256) private _userStakes;

    mapping (address => uint256) private _rewards;
    mapping (address => uint256) private _claims;

    mapping(address => uint256) private _etherBalances;
    mapping(address => uint256) private _slashings;

    mapping (address => uint256) private _exits;

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
        require(block.number > _exits[provider].add(_systemParameters.EXIT_BLOCKS()), "Recently exited");
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

        IDepositContract(_depositContract).deposit{value : 32 ether}(pubkey, withdrawal_credentials, signature, deposit_data_root);

        // substract 32 ether from pending amount
        _pendingAmount = _pendingAmount.sub(32 ether);

        uint256 _amount = 0;
        uint256 i = 0;

        _aethContract.mint(address(this), 32 ether);

        while (_amount < 32 ether) {
            address staker = _pendingStakers[i];
            uint256 userStake = _pendingUserStakes[staker];
            _amount = _amount.add(userStake);

            // if amount bigger then 32 ethereum, give back remaining user amount to pending
            if (_amount >= 32 ether) {
                uint256 remained = _amount.sub(32 ether);
                // set pending user stakes to zero
                _pendingUserStakes[staker] = remained;
                // add reward for staker
                _rewards[staker] = _rewards[staker].add(userStake.sub(remained));

                emit StakeConfirmed(staker, userStake.sub(remained));
                break;
            }
            // set pending user stakes to zero
            _pendingUserStakes[staker] = 0;
            // add reward for staker
            _rewards[staker] = _rewards[staker].add(userStake);

            i++;
            emit StakeConfirmed(staker, userStake);
        }

        // we should remove stakers from pending array length is: i
        for (uint256 j = i; j < _pendingStakers.length; j++) {
            _pendingTemp.push(_pendingStakers[j]);
        }

        _pendingStakers = _pendingTemp;
        delete _pendingTemp;
        emit PoolOnGoing(pubkey);
    }

    function stake() public notExitRecently(msg.sender) unlocked(msg.sender) payable {
        _stake(msg.sender, msg.value);
    }

    function _stake(address staker, uint256 value) private {
        require(value > 0, "Value must be greater than zero");
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
        _etherBalances[msg.sender] = _etherBalances[msg.sender].add(msg.value);
        _stake(msg.sender, msg.value);
        emit ProviderToppedUpEth(msg.sender, msg.value);
    }

    function topUpANKR(uint256 amount) public whenNotPaused("topUpANKR") notExitRecently(msg.sender) payable {
        /* Approve ankr & freeze ankr */
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
        require(_availableEtherBalanceOf(msg.sender) > 0, "Provider balance should be positive for exit");
        _exits[msg.sender] = block.number;
        emit ProviderExited(msg.sender);
    }

    function claim() public notExitRecently(msg.sender) {
        _claim(msg.sender);
    }

    function claimFor(address staker) public notExitRecently(staker) {
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

    function unstake() public payable unlocked(msg.sender) notExitRecently(msg.sender) {
        uint256 pendingStakes = _pendingUserStakes[msg.sender];
        require(pendingStakes > 0, "No pending stakes");

        _pendingUserStakes[msg.sender] = 0;
        require(msg.sender.send(pendingStakes), "could not send ethers");
        emit StakeRemoved(msg.sender, pendingStakes);
    }

    function _availableEtherBalanceOf(address provider) private view returns (int256) {
        return int256(_etherBalanceOf(provider) - _slashingsOf(provider));
    }

    function _etherBalanceOf(address provider) private view returns (uint256) {
        return _etherBalances[provider];
    }

    function _slashingsOf(address provider) private view returns (uint256) {
        return _slashings[provider];
    }

    function _ankrBalanceOf(address provider) private view returns (uint256) {
        return _stakingContract.frozenStakesOf(provider);
    }

    /**
        Slash eth, returns remaining needs to be slashed
    */
    function _slashETH(address provider, uint256 amount) private returns (uint256 remaining) {

        uint256 available = _availableEtherBalanceOf(provider) > 0 ? uint256(_availableEtherBalanceOf(provider)) : 0;

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

    function updateParameterContract(address paramContract) external onlyOwner {
        _systemParameters = SystemParameters(paramContract);
    }

    function updateStakingContract(address stakingContract) external onlyOwner {
        _stakingContract = IStaking(stakingContract);
    }

    uint256[50] private __gap;
}