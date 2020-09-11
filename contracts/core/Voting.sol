// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "../lib/SafeMath.sol";

// TODO: update this contract
contract Voting {

    using SafeMath for uint256;

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
    function _propose(bytes32 name) internal returns(bool) {
        Proposal memory proposal;
        proposal.name = name;
        proposal.endTime = block.timestamp.add(2 days); // TODO: it can be dynamic.
        _proposals.push(proposal);

        return true;
    }

    function _vote(uint256 index) public {}
}