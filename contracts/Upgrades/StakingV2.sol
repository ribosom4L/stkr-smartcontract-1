// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SignedSafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "../lib/Lockable.sol";
import "../lib/interfaces/IAETH.sol";
import "../lib/interfaces/IMarketPlace.sol";

// TODO: user can join late (reward should be reduced)
contract StakingV2 is OwnableUpgradeSafe, Lockable {
    using SafeMath for uint256;
    using SignedSafeMath for int256;

    event Stake(
        address indexed staker,
        uint256 blockNumber,
        uint256 value
    );

    event Freeze(
        address indexed staker,
        uint256 value
    );

    event Unfreeze(
        address indexed staker,
        uint256 value
    );

    event Unstake(
        address indexed staker,
        uint256 value
    );

    event RewardIncome(
        uint256 poolIndex,
        uint256 amount
    );

    event Compensate(address indexed provider, uint256 ankrAmount, uint256 etherAmount);

    event RewardClaim(
        address payable staker,
        uint256 amount
    );

    struct UserStake {
        uint256 available;
        uint256 frozen;
        uint256 lastBlock;
        uint256 weight;

        uint256 claimedRewardAmount;
    }

    // rewards will be claimable after selected block, rewards will calculated based on this too
    uint256 public claimableAfter;

    // start of contract
    uint256 public startBlock;

    IAETH public AETHContract;

    IMarketPlace _marketPlaceContract;

    IERC20 public _ankrContract;

    address public _microPoolContract;

    mapping(address => UserStake) public _stakes;

    uint256 public totalRewards;
    uint256 public totalStakes;

    function initialize(address ankrContract, address microPoolContract, address aethContract) public initializer {
        OwnableUpgradeSafe.__Ownable_init();

        startBlock = block.number;

        _ankrContract = IERC20(ankrContract);
        _microPoolContract = microPoolContract;
        AETHContract = IAETH(aethContract);
    }

    modifier addressAllowed(address addr) {
        require(msg.sender == addr, "You are not allowed to run this function");
        _;
    }

    modifier onlyMicroPoolContract() {
        require(_microPoolContract == _msgSender(), "Ownable: caller is not the micropool contract");
        _;
    }

    /*
        This function used to stake ankr
    */
    function claimAnkrAndStake(address user) public unlocked(user) returns (uint256) {
        uint256 allowance = _ankrContract.allowance(user, address(this));

        if (allowance == 0) {
            return 0;
        }

        require(_ankrContract.transferFrom(user, address(this), allowance), "Allowance Claim Error: Tokens could not transferred from ankr contract");


        UserStake storage stake = _stakes[user];

        // FIXME
        stake.weight = allowance;

        //        if (stake.weight > 0) {
        //            stake.weight = stake.weight.mul(block.number).add(allowance.mul(stake.lastBlock)) / stake.lastBlock.add(block.number);
        //        }
        //        else {
        //            stake.weight = allowance;
        //        }

        stake.lastBlock = stake.lastBlock.add(block.number);
        stake.available = stake.available.add(allowance);

        totalStakes = totalStakes.add(allowance);

        emit Stake(user, block.number, allowance);

        return allowance;
    }

    // this function will called by micro pool contract to freeze staked balance and claim allowance if exists
    function freeze(address user, uint256 amount)
    public
    addressAllowed(_microPoolContract)
    unlocked(msg.sender)
    returns (bool)
    {
        claimAnkrAndStake(user);
        UserStake storage userStake = _stakes[user];

        userStake.available = userStake.available.sub(amount, "Staking: Insufficient funds");

        userStake.frozen = userStake.frozen.add(amount);

        emit Freeze(user, amount);
        return true;
    }

    function updateAnkrContract(address ankrContract) public onlyOwner {
        _ankrContract = IERC20(ankrContract);
    }

    function updateMicroPoolContract(address microPoolContract)
    public
    onlyOwner
    {
        _microPoolContract = microPoolContract;
    }

    function transferToken(address to, uint256 amount) private {
        require(_ankrContract.transfer(to, amount), "Failed token transfer");
    }

    function unstake() public unlocked(msg.sender) returns (bool) {
        UserStake storage stake = _stakes[msg.sender];
        require(stake.available > 0, "You dont have stake balance");

        uint256 available = stake.available.add(stake.frozen);

        stake.available = 0;

        if (stake.frozen > 0) {
            stake.weight = stake.weight.mul(stake.available.div(available.add(stake.frozen)));
        }
        else {
            stake.weight = 0;
            stake.lastBlock = 0;
        }

        totalStakes = totalStakes.sub(available);

        transferToken(msg.sender, available);

        emit Unfreeze(msg.sender, available);

        return true;
    }

    function unfreeze(address addr, uint256 amount)
    public
    addressAllowed(_microPoolContract)
    unlocked(addr)
    returns (bool)
    {
        UserStake storage userStake = _stakes[addr];
        userStake.frozen = userStake.frozen.sub(amount, "Insufficient funds");
        userStake.available = userStake.available.add(amount);

        emit Unfreeze(addr, amount);
        return true;
    }

    function reward(uint256 poolIndex) payable external onlyMicroPoolContract {
        totalRewards = totalRewards.add(msg.value);

        emit RewardIncome(poolIndex, msg.value);
    }

    function compensatePoolLoss(address provider, uint256 amount, uint256 providerStakeAmount) external onlyMicroPoolContract returns (uint256) {
        UserStake storage stake = _stakes[provider];

        // ankr amount equals to needed ether
        uint256 ankrAmount = amount.mul(_marketPlaceContract.ankrEthRate());

        // TODO: this should be solved
        require(stake.frozen >= amount, "Insufficient staking balance");

        stake.frozen = stake.frozen.sub(providerStakeAmount);
        stake.available = stake.available.add(providerStakeAmount).sub(ankrAmount);
        stake.weight = stake.weight.mul(amount).div(totalStakesOf(provider));

        totalStakes = totalStakes.sub(ankrAmount);

        _ankrContract.transfer(address(_marketPlaceContract), ankrAmount);

        _marketPlaceContract.burnAeth(amount);

        emit Compensate(provider, ankrAmount, amount);

        return ankrAmount;
    }

    function totalStakesOf(address staker) public view returns (uint256) {
        return _stakes[staker].available.add(_stakes[staker].frozen);
    }

    function claimableStakerReward(address _staker) public view returns (uint256) {
        UserStake memory staker = _stakes[_staker];

        // TODO: Time based calculation

        uint256 totalEarned = totalRewards.mul(totalStakesOf(_staker)).div(totalStakes);
        return totalEarned.sub(staker.claimedRewardAmount);
    }

    function claimRewards() public payable unlocked(msg.sender) {
        require(claimableAfter > 0, "Contract not claimable yet");

        uint256 claimableReward = claimableStakerReward(msg.sender);

        require(claimableReward > 0, "There is no rewards to claim");

        UserStake storage stake = _stakes[msg.sender];
        stake.claimedRewardAmount = stake.claimedRewardAmount.add(claimableReward);

        require(msg.sender.send(claimableReward), "Rewards could not sent");

        emit RewardClaim(msg.sender, claimableReward);
    }

    function updateMarketPlaceContract(address marketPlaceContract) external onlyOwner {
        _marketPlaceContract = IMarketPlace(marketPlaceContract);
    }

    function updateAETHContract(address aethContract) public onlyOwner {
        AETHContract = IAETH(aethContract);
    }

    function setClaimableBlock(uint256 blockNumber) public onlyOwner {
        claimableAfter = blockNumber;
    }
    uint256 test222;
    function test() public {
        test222++;
    }
}
