//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

contract SystemParameters {
    
    // Minimum ankr staking amount to be abel to initialize a pool
    uint256 public PROVIDER_MINIMUM_STAKING = 200;

    // Minimum staking amount for pool participants
    uint256 public REQUESTER_MINIMUM_POOL_STAKING = 100 finney; // 0.1 ETH
}