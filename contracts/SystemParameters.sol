//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";

contract SystemParameters is OwnableUpgradeSafe {

    // Minimum ankr staking amount to be abel to initialize a pool
    uint256 public PROVIDER_MINIMUM_STAKING;

    // Minimum staking amount for pool participants
    uint256 public REQUESTER_MINIMUM_POOL_STAKING; // 0.1 ETH

    // Minimum slashing amount for migration as ether
    uint256 public SLASHINGS_FOR_MIGRATION;

    // TODO: allow only multiplies of requester minimum staking amount

    function initialize() external initializer {
        PROVIDER_MINIMUM_STAKING = 100000 ether;
        REQUESTER_MINIMUM_POOL_STAKING = 100 finney; // 0.1 ETH
        SLASHINGS_FOR_MIGRATION = 0.1 ether;
    }
}