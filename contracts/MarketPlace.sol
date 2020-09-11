//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "./core/OwnedByGovernor.sol";

contract MarketPlace is OwnedByGovernor {
    // ETH-USD
    // ANKR-ETH
    uint256 private _ethUsd;
    uint256 private _ankrEth;

    function updateEthUsdRate(uint256 ethUsd) external onlyGovernor {
        _ethUsd = ethUsd;
    }

    function updateAnkrEthRate(uint256 ankrEth) external onlyGovernor {
        _ankrEth = ankrEth;
    }

    function ethUsdRate() public view returns (uint256) {
        return _ethUsd;
    }

    function ankrEthRate() public view returns (uint256) {
        return _ankrEth;
    }
}
