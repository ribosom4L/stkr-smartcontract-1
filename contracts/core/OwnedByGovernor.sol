// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

abstract contract GovernanceContract {
    function isGovernor(address addr) external virtual returns(bool);
}

contract OwnedByGovernor {
    GovernanceContract private _governanceContract;

    function updateGovernanceContract(address addr) external {
        _governanceContract = GovernanceContract(addr);
    }

    function governanceContract() external view returns(GovernanceContract) {
        return _governanceContract;
    }

    modifier onlyGovernor() {
        require(
            _governanceContract.isGovernor(msg.sender),
            "Only a governor can call this function."
        );
        _;
    }
}