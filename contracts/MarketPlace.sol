pragma solidity ^0.4.0;

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
