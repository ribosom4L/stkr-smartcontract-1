pragma solidity ^0.6.11;
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";

interface IFETH is IERC20 {
    function mint(address account, uint256 shares, uint256 sent) external;

    function updateReward(uint256 newReward) external returns(uint256);
}
