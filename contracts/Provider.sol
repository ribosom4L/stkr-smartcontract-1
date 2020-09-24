// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;
pragma experimental ABIEncoderV2;

import "./lib/SafeMath.sol";
import "./lib/Ownable.sol";
import "./core/OwnedByGovernor.sol";


interface Staking {
    function providerStake(address user, uint256 amount) external;

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
    mapping(address => ProviderInfo) private _providers;

    constructor(address stakingContract) public {
        _stakingContract = stakingContract;
    }

    function isProvider(address addr) public view returns (bool) {
        return _providers[addr].addr == addr;
    }

    function saveProvider(
        bytes32 name,
        bytes32 website,
        bytes32 iconUrl,
        bytes32 email
    ) public payable returns(uint256) {
        require(!isProvider(msg.sender), "You are already a provider");
        uint256 feeMultiplier = 0;
        
        bytes32 zero = 0x0000000000000000000000000000000000000000000000000000000000000000;

        if (name != zero) {
            feeMultiplier++;
        }

        if (website != zero) {
            feeMultiplier++;
        }

        if (iconUrl != zero) {
            feeMultiplier++;
        }

        if (email != zero) {
            feeMultiplier++;
        }

        ProviderInfo memory p;
        p.name = name;
        p.website = website;
        p.iconUrl = iconUrl;
        p.email = email;
        p.addr = msg.sender;
        p.status = ProviderStatus.APPROVED;

        _providers[msg.sender] = p;

        // Staking(_stakingContract).providerStake(msg.sender, amount);
        emit Applied(msg.sender);
        // require(msg.value >= feeMultiplier * 21000, 'Need extra gas to end transaction');
    }


    function updateProvider(        
        address provider,
        bytes32 name,
        bytes32 website,
        bytes32 iconUrl,
        bytes32 email
    ) public onlyGovernor {
        require(isProvider(provider), "Address is not a provider");

        ProviderInfo memory p;
        p.name = name;
        p.website = website;
        p.iconUrl = iconUrl;
        p.email = email;
        p.addr = msg.sender;
        p.status = ProviderStatus.APPROVED;

        _providers[provider] = p;
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
