pragma solidity ^0.6.11;
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";

interface IFETH is IERC20 {
    function mint(address account, uint256 amount) external returns(uint256);

    function depositFor(address user) external;

    function deposit() external;
}
