pragma solidity ^0.6.8;

interface IMarketPlace {
    function ethUsdRate() external returns (uint256);

    function ankrEthRate() external returns (uint256);

    function burnAeth(uint256 etherAmount) external returns (uint256);
}
