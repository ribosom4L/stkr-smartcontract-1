//SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

// TODO: update this contract

contract Governance {

    address payable[] private _governors;

    struct Parameter {
        uint id;
        string name;
        uint value; 
    }

    Parameter[] private paremeters;
    
    /**
        Returns true if given address is a governor
        @return bool
    */
    function isGovernor(address governor) external view returns (bool) {
        // TODO: commented temporarily for testing
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

