//SPDX-License-Identifier: MIT
pragma solidity ^0.6.8;

// TODO: update this contract

contract Governance {
    address[] private _governors;

    struct Parameter {
        uint id;
        string name;
        uint value; 
    }

    constructor() public {
        _governors.push(msg.sender);
    }
    
    /**
        Returns true if given address is a governor
        @return bool
    */
    function isGovernor(address governor) public view returns (bool) {
        return true;
        // TODO: convert to mapping
        for (uint index = 0; index < _governors.length; index++) {
            if (_governors[index] == governor)   
                return true;
        }

        return false;
    }

    /**
        Returns all governors in system
        @return address[]
    */
    function getGovernors() external view returns (address              [] memory) {
        return _governors;
    }
}

