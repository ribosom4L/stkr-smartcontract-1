//SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

// TODO: update this contract
contract Governance {

    address payable[] private _governors;
    
    /**
        Returns true if given address is a governor
        @return bool
    */
    function isGovernor(address governor) external view returns (bool) {
        // TODO: commented temporarily for testing
//        for (uint8 i = 0; i < _governors.length; i++) {
//            if (_governors[i] == governor) return true;
//        }

//        return false;
        return true;
    }

    /**
        Returns all governors in system
        @return address[]
    */
    function getGovernors() external view returns (address payable[] memory) {
        return _governors;
    }
}

