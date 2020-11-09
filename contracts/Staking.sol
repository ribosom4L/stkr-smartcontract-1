// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.11;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "./lib/Lockable.sol";
import "./lib/interfaces/IAETH.sol";
import "./lib/interfaces/IMarketPlace.sol";

contract Staking is OwnableUpgradeSafe, Lockable {
    using SafeMath for uint256;

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
        address staker,
        uint256 amount
    );

    uint256 private _startBlock;

    // stakes of users
    mapping (address => uint256) private _stakes;
    // weight = stake * block number + previous weight
    // at the and of the staking, weight will be equal to last block * stake amount - current weight
    mapping (address => uint256) private _weight;
    mapping (address => uint256) private _frozen;
    // claimed reward amounts
    mapping (address => uint256) private _claimed;

    // rewards will be claimable after selected block, rewards will calculated based on this too
    uint256 private claimableAfter;

    IAETH private AETHContract;

    IMarketPlace _marketPlaceContract;

    IERC20 private _ankrContract;

    address private _globalPoolContract;

    address private _swapContract;

    uint256 private totalRewards;

    // real total weight = last block * totalStakes
    uint256 private totalWeight;

    uint256 private totalStakes;

    function initialize(address ankrContract, address globalPoolContract, address aethContract) public initializer {
        OwnableUpgradeSafe.__Ownable_init();

        _startBlock = block.number;

        _ankrContract = IERC20(ankrContract);
        _globalPoolContract = globalPoolContract;
        AETHContract = IAETH(aethContract);
    }

    modifier addressAllowed(address addr) {
        require(msg.sender == addr, "You are not allowed to run this function");
        _;
    }

    modifier onlyMicroPoolContract() {
        require(_globalPoolContract == _msgSender(), "Ownable: caller is not the micropool contract");
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

        uint256 blockNum = block.number;
        uint weight = allowance.mul(blockNum);

         _stakes[user] = _stakes[user].add(allowance);
        _weight[user] = _weight[user].add(weight);

        totalStakes = totalStakes.add(allowance);
        totalWeight = totalWeight.add(weight);
        emit Stake(user, block.number, allowance);
        return allowance;
    }

    // this function will called by micro pool contract to freeze staked balance and claim allowance if exists
    function freeze(address user, uint256 amount)
    public
    addressAllowed(_globalPoolContract)
    unlocked(msg.sender)
    returns (bool)
    {
        claimAnkrAndStake(user);
        _frozen[user] = _frozen[user].add(amount);

        emit Freeze(user, amount);
        return true;
    }

    function transferToken(address to, uint256 amount) private {
        require(_ankrContract.transfer(to, amount), "Failed token transfer");
    }

    function unstake() public unlocked(msg.sender) returns (bool) {
        uint256 stake = _stakes[msg.sender];
        uint256 frozen = _stakes[msg.sender];
        uint256 available = stake.sub(frozen);

        require(available > 0, "You dont have stake balance");

        uint256 weight = _weight[msg.sender];
        uint256 frozenWeight = weight.mul(frozen).div(stake);

        _stakes[msg.sender] = frozen;
        _weight[msg.sender] = frozenWeight;

        totalStakes = totalStakes.sub(available);

        transferToken(msg.sender, available);

        emit Unstake(msg.sender, available);

        return true;
    }

    function unfreeze(address addr, uint256 amount)
    public
    addressAllowed(_globalPoolContract)
    unlocked(addr)
    returns (bool)
    {
        _frozen[msg.sender] = _frozen[msg.sender].sub(amount, "Insufficient funds");

        emit Unfreeze(addr, amount);
        return true;
    }

    function setClaimed(address staker, uint256 amount) public addressAllowed(_swapContract) {
        _claimed[staker] = _claimed[staker].add(amount);

        emit RewardClaim(staker, amount);
    }

    //TODO: Reward from swap contract

    function compensateLoss(address provider, uint256 ethAmount) external onlyMicroPoolContract returns (bool result, uint256 ankrAmount, uint256 remainingEthAmount) {

    }

//    function compensatePoolLoss(address provider, uint256 amount, uint256 providerStakeAmount) external onlyMicroPoolContract returns (bool, uint256) {
//        UserStake storage stake = _stakes[provider];
//
//        // ankr amount equals to needed ether
//        uint256 ankrAmount = amount.mul(_marketPlaceContract.ankrEthRate());
//
//        if (stake.frozen >= amount) {
//            return (false, ankrAmount);
//        }
//
//        stake.frozen = stake.frozen.sub(providerStakeAmount);
//        stake.available = stake.available.add(providerStakeAmount).sub(ankrAmount);
//        stake.weight = stake.weight.mul(amount).div(totalStakesOf(provider));
//
//        totalStakes = totalStakes.sub(ankrAmount);
//
//        _ankrContract.transfer(address(_marketPlaceContract), ankrAmount);
//
//        _marketPlaceContract.burnAeth(amount);
//
//        emit Compensate(provider, ankrAmount, amount);
//
//        return (true, ankrAmount);
//    }

    function setClaimableBlock(uint256 blockNumber) public onlyOwner {
        claimableAfter = blockNumber;
    }

    function stakesOf(address staker) public view returns (uint256) {
        return _stakes[staker];
    }

    function frozenStakesOf(address staker) public view returns (uint256) {
        return _frozen[staker];
    }

    function rewardOf(address staker) public view returns (uint256) {
        return totalStakes.mul(stakerWeight(staker)).div(realWeight()).sub(_claimed[staker]);
    }

    function claimedOf(address staker) public view returns (uint256) {
        return _claimed[staker];
    }

    function updateGlobalPoolContract(address globalPoolContract)
    public
    onlyOwner
    {
        _globalPoolContract = globalPoolContract;
    }

    function updateSwapContract(address swapContract) public onlyOwner {
        _swapContract = swapContract;
    }

    function realWeight() public view returns(uint256) {
        return totalStakes.mul(block.number).sub(totalWeight);
    }

    function stakerWeight(address staker) public view returns(uint256) {
        return _stakes[staker].mul(block.number).sub(_weight[staker]);
    }

    function updateMarketPlaceContract(address marketPlaceContract) external onlyOwner {
        _marketPlaceContract = IMarketPlace(marketPlaceContract);
    }

    function updateAETHContract(address aethContract) public onlyOwner {
        AETHContract = IAETH(aethContract);
    }
}
