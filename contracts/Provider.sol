// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./lib/SafeMath.sol";
import "./lib/Ownable.sol";
import "./core/OwnedByGovernor.sol";

interface StakingContract {
    function providerStake(address user) external;

    function checkProviderStake(address addr) external returns (bool);
}

contract Provider is Ownable, OwnedByGovernor {
    using SafeMath for uint256;

    event Applied(address indexed provider);
    event StatusChanged(address indexed governor, address indexed provider, ProviderStatus indexed newStatus);

    enum ProviderStatus {APPROVED, BANNED}

    struct ProviderInfo {
        bytes32 website;
        bytes32 name;
        bytes32 iconUrl;
        bytes32 email;
        address addr;
        ProviderStatus status;
    }

    address private _stakingContract;
    address private _micropoolContract;
    mapping(address => ProviderInfo) private _providers;

    constructor(address stakingContract, address micropoolContract) public {
        _stakingContract = stakingContract;
        _micropoolContract = micropoolContract;
    }

    function isProvider(address addr) public view returns (bool) {
        return _providers[addr].addr == addr;
    }

    function saveProvider(bytes32 name) public payable returns(uint256) {
        require(!isProvider(msg.sender), "You are already a provider");
        uint256 feeMultiplier = 0;

        bytes32 zero = 0x0000000000000000000000000000000000000000000000000000000000000000;

        if (name != zero) {
            feeMultiplier++;
        }

        ProviderInfo memory p;
        p.name = name;
        p.addr = msg.sender;
        p.status = ProviderStatus.APPROVED;

        _providers[msg.sender] = p;

        emit Applied(msg.sender);
        // StakingContract(_stakingContract).providerStake(msg.sender);
        // require(msg.value >= feeMultiplier * 21000, 'Need extra gas to end transaction');
    }
    
    function ban(address addr) public onlyGovernor {
        require(isProvider(addr), "Not a provider");

        _providers[addr].status = ProviderStatus.BANNED;
        emit StatusChanged(msg.sender, addr, _providers[addr].status);
    }

    function getProviderInfo(address addr) public view returns (ProviderInfo memory) {
        return _providers[addr];
    }

    // TODO: OnlyGovernor -> Governors by voting
    function updateStakingContract(address addr) public onlyGovernor {
        _stakingContract = addr;
    }
}
