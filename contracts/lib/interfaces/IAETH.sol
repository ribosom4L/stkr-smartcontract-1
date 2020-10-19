pragma solidity ^0.6.8;
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";

interface IAETH is IERC20 {
    function burn(uint256 amount) external;

    function updateMicroPoolContract(address microPoolContract) external;

    function mintFrozen(address account, uint256 amount) external;

    function mint(address account, uint256 amount) external;

    function mintPool() payable external;

    function fundPool(uint256 poolIndex, uint256 amount) external;
}