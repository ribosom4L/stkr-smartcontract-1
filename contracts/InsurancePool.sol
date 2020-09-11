// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "./lib/SafeMath.sol";
import "./lib/Ownable.sol";
import "./core/OwnedByGovernor.sol";

interface MicroPool {
    function updateSlashingOfAPool(uint256, uint256) external payable returns(bool);
}

// TODO: update this contract
contract InsurancePool is Ownable, OwnedByGovernor {

    using SafeMath for uint256;

    event SlashingCompensated(uint256 indexed poolIndex, uint256 indexed amount);

    mapping (uint256 => uint256) private _compensatedSlashings; // poolIndex => amount
    MicroPool private _microPoolContract;

    // TODO: receive() external payable {}

    function updateSlashings(uint256 poolIndex, uint256 amount) public onlyGovernor {
        require(_microPoolContract.updateSlashingOfAPool{value: amount}(poolIndex, amount), "");
        
        _compensatedSlashings[poolIndex] = _compensatedSlashings[poolIndex].add(amount);

        emit SlashingCompensated(poolIndex, amount);
    }

    function updateMicroPoolContract(address payable addr) public onlyGovernor {
        _microPoolContract = MicroPool(addr);
    }

    function microPoolContract() external view returns(MicroPool) {
        return _microPoolContract;
    }
}