// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "./lib/SafeMath.sol";
import "./lib/Ownable.sol";
import "./core/OwnedByGovernor.sol";

interface Staking {
    function nodeStake(uint256 amount) external;
    function checkNodeStake(address addr) external returns(bool);
}

contract Node is Ownable, OwnedByGovernor {
    event NodeAdded(address indexed provider, address indexed node);
    event StatusChanged(address indexed governor, NodeStatus indexed newStatus);

    enum NodeStatus {PENDING, WORKING, REJECTED, REMOVED}

    struct NodeInfo {
        address addr;
        address provider;
        NodeStatus status;
    }

    mapping(address => NodeInfo) private _nodes; // node addr => node info

    address private _stakingContract;

    function providerNodes(address addr)
        public
        view
        returns (
            address,
            address,
            NodeStatus
        )
    {
        return (_nodes[addr].addr, _nodes[addr].provider, _nodes[addr].status);
    }

    function nodeExists(address addr) public view returns (bool) {
        return _nodes[addr].addr != address(0);
    }

    function request(address addr) public {
        require(_nodes[addr].addr == address(0), "Node already exists");

        NodeInfo memory n;
        n.addr = addr;
        n.provider = msg.sender;
        n.status = NodeStatus.PENDING;
        _nodes[addr] = n;

        emit NodeAdded(msg.sender, addr);
    }

    function approve(address addr) public onlyGovernor {
        require(_nodes[addr].status == NodeStatus.PENDING, "Node not pending");

        _nodes[addr].status = NodeStatus.WORKING;

        emit StatusChanged(msg.sender, _nodes[addr].status);
    }

    function reject(address addr) public onlyGovernor {
        require(_nodes[addr].status == NodeStatus.PENDING, "Node not pending");

        _nodes[addr].status = NodeStatus.REJECTED;

        emit StatusChanged(msg.sender, _nodes[addr].status);
    }

    // TODO: remove a node

    function updateStakingContract(address addr) public onlyGovernor {
        _stakingContract = addr;
    }
}
