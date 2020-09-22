// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

interface GovernanceContract {
    function isGovernor(address addr) external virtual returns(bool);
}

contract OwnedByGovernor {
    address private _governanceContract;

    function updateGovernanceContract(address addr) external {
        _governanceContract = addr;
    }

    function governanceContract() external view returns(address) {
        return _governanceContract;
    }

    modifier onlyGovernor() {
//        require(
//            GovernanceContract(_governanceContract).isGovernor(msg.sender),
//            "Only a governor can call this function."
//        );
        _;
    }
}
