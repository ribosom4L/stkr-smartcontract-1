// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

// TODO: update this contract
contract Voting {

    enum Vote {Accept, Reject}

    struct Proposal {
        bytes32 name;
        uint256 accepts;
        uint256 rejects;
        uint256 endTime;
        mapping (address => Vote) votes;
    }

    Proposal[] private _proposals;

    // TODO only governance contract can call this
    function startVoting(bytes32 name) external {
        Proposal memory proposal;
        proposal.name = proposal;
        proposal.endTime = block.timestamp.add(2 days); // TODO: it can be dynamic.
    }
}