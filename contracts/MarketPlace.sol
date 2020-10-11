//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "./core/OwnedByGovernor.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract MarketPlace is OwnedByGovernor {
    using SafeMath for uint256;
    // ETH-USD
    // ANKR-ETH
    uint256 private _ethUsd;
    uint256 private _ankrEth;

    uint256 private MULTIPLIER = 1e10;

    function updateEthUsdRate(uint256 ethUsd) public onlyGovernor {
        _ethUsd = ethUsd;
    }

    function updateAnkrEthRate(uint256 ankrEth) public onlyGovernor {
        _ankrEth = ankrEth;
    }

    // 1 eth  = x usd
    function ethUsdRate() public view returns (uint256) {
        return _ethUsd;
    }

    // 1 eth = x ankr
    function ethAnkrRate() public view returns (uint256) {
        return _ankrEth;
    }

    // x ankr (as wei)  = x usd
    function ankrUsdRate(uint256 ankrAmount) public view returns (uint256) {
        return ankrAmount.mul(MULTIPLIER).div(_ankrEth).mul(_ethUsd);
    }
}
