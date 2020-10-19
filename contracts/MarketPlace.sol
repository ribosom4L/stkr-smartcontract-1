//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "./lib/interfaces/IAETH.sol";

contract MarketPlace is OwnableUpgradeSafe {
    using SafeMath for uint256;

    // ETH-USD
    // ANKR-ETH
    uint256 private _ethUsd;
    uint256 private _ankrEth;

    // TODO: Funders
    // mapping (address => uint256) public _funders;

    IAETH public AETHContract;

    function initialize(address aethContract) public initializer {
        OwnableUpgradeSafe.__Ownable_init();
        AETHContract = IAETH(aethContract);
    }

    function updateEthUsdRate(uint256 ethUsd) public onlyOwner {
        _ethUsd = ethUsd;
    }

    function updateAnkrEthRate(uint256 ankrEth) public onlyOwner {
        _ankrEth = ankrEth;
    }

    function ethUsdRate() external returns (uint256 ethUsd) {
        ethUsd = _ethUsd;
    }

    function ankrEthRate() external returns (uint256 ankrEth) {
        ankrEth = _ankrEth;
    }

    function updateAETHContract(address aethContract) public onlyOwner {
        AETHContract = IAETH(aethContract);
    }

    // TODO: Only staking contract
    function burnAeth(uint256 etherAmount) external returns (uint256) {
        AETHContract.burn(etherAmount);

        return etherAmount;
    }
}
