//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;


contract SystemParameters {

    // TODO: Discuss, variables or mapping? Are parameters static?
    // If variable, should we update per parameter with different function
    // or with assembly in a single function ?

    // User usdt fee
    uint256 private _poolFee = 0; 
    
    // Fee for applying to be a provider
    uint256 private _providerFee = 200; 
    
    // Minimum and maximum that providers offers to auction
    uint256[2] private _auctionLimits = [100, 300]; 
    
    // ANKR Stakng to be a provider 
    uint256 private _providerMinimumStake = 200; 

    // users can pay fee with ankr staking.
    uint256 private _ankrStakePerWei = 1e9; 

    // Maximum slashings allowed for a pool
    // TODO: if reached to limit provider needs to be changed with a trusted node
    uint256 private _maximumSlashingsAllowed = 500 finney;
}