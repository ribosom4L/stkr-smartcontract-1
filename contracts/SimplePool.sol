// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/Math.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "./lib/interfaces/IDepositContract.sol";
import "./SystemParameters.sol";
import "./lib/Lockable.sol";
import "./lib/interfaces/IAETH.sol";
import "./lib/interfaces/IStaking.sol";

import "./lib/interfaces/IDepositContract.sol";

interface IStkrPool {
}

contract SimplePool is OwnableUpgradeSafe, Lockable {
    using SafeMath for uint256;
    using Math for uint256;

    event StakePending(address indexed staker, uint256 amount);
    event StakeConfirmed(address indexed staker, uint256 amount);

    /* pool events */
    //    event PoolPushWaiting(bytes32 indexed pool); // we dont have pending pools anymore
    event PoolOnGoing(bytes indexed pool);
    event PoolCompleted(bytes indexed pool);
    //    event PoolClosed(bytes32 indexed pool);

    event ProviderExited(address indexed provider, uint256 exitBlock);
    event ProviderANKRSlash(address indexed provider, uint256 ankrAmount, uint256 etherEquivalence);
    event ProviderETHSlash(address indexed provider, uint256 amount);

    event TopUpETH(address indexed provider, uint256 amount);
    event TopUpANKR(address indexed provider, uint256 amount);

    mapping(address => uint256) private _pendingUserStakes;
    mapping(address => uint256) private _userStakes;

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

    modifier notExitRecently(address provider) {
        require(block.number > _exits[provider].add(_systemParameters.EXIT_BLOCKS()), "Recently exited");
        _;
    }

    function initialize() public initializer {
        __Ownable_init();

        _depositContract = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
    }

    function pushToBeacon(uint256 poolIndex,
        bytes memory pubkey,
        bytes memory withdrawal_credentials,
        bytes memory signature,
        bytes32 deposit_data_root) public onlyOwner {

        require(_pendingAmount >= 32 ether, "pending ethers not enough");

        IDepositContract(_depositContract).deposit{value : 32 ether}(pubkey, withdrawal_credentials, signature, deposit_data_root);

        // substract 32 ether from pending amount
        _pendingAmount = _pendingAmount.sub(32 ether);

        uint256 _amount = 0;
        uint256 i = 0;

        while (_amount < 32 ether) {
            address staker = _pendingStakers[i];
            uint256 userStake = _pendingUserStakes[staker];
            _amount = _amount.add(userStake);

            /**Make aeth claimable*/

            // if amount bigger then 32 ethereum, give bak remaining user amount to pending
            if (_amount >= 32 ether) {
                uint256 remained = _amount.sub(32 ether);
                _pendingUserStakes[staker] = remained;
                emit StakeConfirmed(staker, userStake.sub(remained));
                break;
            }
            _pendingUserStakes[staker] = 0;
            i++;
            emit StakeConfirmed(staker, userStake);
        }

        uint256[] memory newPendingArray;

        // we should remove stakers from pending array length is: i
        for (uint256 j = i; j < _pendingUserStakes.length; j++) {
            newPendingArray.push(_pendingUserStakes[j]);
        }
        // we are deleting
        delete _pendingStakers;
        delete _pendingUserStakes;
        _pendingUserStakes = newPendingArray;

        emit PoolOnGoing(deposit_data_root);
    }

    function stake() notExitRecently(msg.sender) public payable {
        _stake(msg.sender, msg.value);
    }

    function _stake(address staker, uint256 value) private {
        require(value > 0, "Value must be greater than zero");
        if (_pendingStakes[staker] == 0) {
            _pendingStakers.push(staker);
        }

        _pendingStakes[staker] = _pendingStakes[staker].add(value);
        _pendingAmount = _pendingAmount.add(value);

        _userStakes[staker] = _userStakes[staker].add(value);

        emit StakePending(staker, value);
    }

    function topUpETH() public notExitRecently(msg.sender) payable {
        _etherBalances[msg.sender] = _etherBalances[msg.sender].add(msg.value);
        _stake(msg.value, msg.sender);
        emit TopUpETH(msg.sender, msg.value);
    }

    function topUpANKR(uint256 amount) public notExitRecently(msg.sender) payable {
        /* Approve ankr & freeze ankr */
        require(_stakingContract.freeze(msg.sender, amount), "Could not freeze ANKR tokens");
        emit TopUpANKR(amount, msg.value);
    }

    // slash provider with ethereum balance
    function slash(address provider, uint256 amount) public onlyOwner {
        require(amount > 0, "Amount should be greater than zero");
        uint256 remaining = _slashETH(provider, amount);

        if (remaining == 0) {
            return;
        }

        remaining = _slashANKR(remaining);
        /*Do we need event if remaining balance higher than zero?*/
    }

    function claimableAETH() public view returns (uint256) {
        return 0;
    }

    /**
        Slash eth, returns remaining needs to be slashed
    */
    function _slashETH(address provider, uint256 amount) private returns (uint256 remaining) {
        uint256 toBeSlashed = amount.min(_availableEtherBalanceOf(provider));
        _slashings[provider] = _slashings[provider].add(toBeSlashed);
        remaining = amount.sub(toBeSlashed);

        emit ProviderETHSlash(provider, toBeSlashed);
    }

    function _slashANKR(address provider, uint256 amount) private returns (uint256 remaining) {
//        _stakingContract.compensatePoolLoss()
//        emit ProviderANKRSlash(provider, ankrAmount, amount);
        remaining = 0;
    }

    function providerExit() public {
        _exits[msg.sender] = block.number;
    }

    function claimAETH() {
        /*...*/
    }

    function _availableEtherBalanceOf(address provider) private view returns (int256) {
        return _etherBalanceOf(provider) - _slashingsOf(provider);
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

    function poolCount() public view returns (uint256) {
        return _totalStakes % 32;
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