pragma solidity ^0.6.8;

interface IMarketPlace {
    function ethUsdRate() external returns (uint256);

    function ankrEthRate() external returns (uint256);

    function swapAndBurn(uint256 etherAmount) external returns (uint256);
}
