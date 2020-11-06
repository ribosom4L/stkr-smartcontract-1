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
}

contract SimplePool is OwnableUpgradeSafe, Lockable {
    using SafeMath for uint256;

    event StakePending(address indexed staker, uint256 amount);
    event StakeConfirmed(address indexed staker, uint256 amount);

    /* pool events */
//    event PoolPushWaiting(bytes32 indexed pool); // we dont have pending pools anymore
    event PoolOnGoing(bytes32 indexed pool);
    event PoolCompleted(bytes32 indexed pool);
//    event PoolClosed(bytes32 indexed pool);

    event ProviderExited(address indexed provider, uint256 exitBlock);

    mapping (address => uint256) _pendingUserStakes;
    address[] private _pendingStakers;
    uint256 private _pendingAmount;

    mapping (address => uint256) private _userStakes;
    uint256 private _totalStakes;

    uint256 private _totalRewards;
    uint256 private _totalSlashings;

    function initialize() public initializer {
        __Ownable_init();
    }

    function pushToBeacon(uint256 poolIndex,
        bytes memory pubkey,
        bytes memory withdrawal_credentials,
        bytes memory signature,
        bytes32 deposit_data_root) public onlyOwner {
        require(_pendingAmount >= 32 ether, "pending ethers not enough");
        IDepositContract(_depositContract).deposit{value : ethersToSend}(pubkey, withdrawal_credentials, signature, deposit_data_root);

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
            emit StakeConfirmed(staker, userStake);
            _pendingUserStakes[staker] = 0;
            i++;
        }
        // we are deleting
        delete _pendingStakers;
        emit PoolOnGoing(deposit_data_root);
    }

    function stake() public payable {
        if (_pendingStakes[msg.sender] == 0) {
            _pendingStakers.push(msg.sender);
        }

        _pendingStakes[msg.sender] = _pendingStakes[msg.sender].add(msg.value);
        _pendingAmount = _pendingAmount.add(msg.value);

        _userStakes[msg.sender] = _userStakes[msg.sender].add(msg.value);

        emit StakePending(msg.sender, msg.value);
    }

    /**topUpETH*/

    /**topUpANKR*/

    /**slashProviderETH*/

    /**slashProviderANKR*/

    /**claimAeth*/

    /**providerExit*/

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