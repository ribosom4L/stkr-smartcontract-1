pragma solidity ^0.6.8;

interface IStaking {
    function compensatePoolLoss(address provider, uint256 amount, uint256 providerStakeAmount) external returns (uint256);

    function compensateLoss(address provider, uint256 ethAmount) external returns (bool, uint256, uint256);

    function freeze(address user, uint256 amount) external returns (bool);

    function unfreeze(address user, uint256 amount) external returns (bool);

    function reward(uint256 poolIndex) payable external;

    function frozenStakesOf(address staker) external view returns (uint256);
}