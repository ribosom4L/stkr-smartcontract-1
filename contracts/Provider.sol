// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.8;

import "./lib/SafeMath.sol";
import "./lib/Ownable.sol";
import "./core/OwnedByGovernor.sol";

abstract contract Staking {
    function providerStake(address user, uint256 amount) external virtual;
    function checkProviderStake(address addr) external virtual returns(bool);
}

contract Provider is Ownable, OwnedByGovernor {
    using SafeMath for uint256;

    event Applied(address indexed provider);
    event StatusChanged(address indexed governor, ProviderStatus indexed newStatus);

    enum ProviderStatus {PENDING, APPROVED, BANNED, REJECTED}

    struct ProviderInfo {
        bytes32 website;
        bytes32 name;
        bytes32 iconUrl;
        bytes32 email;
        address addr;
        ProviderStatus status;
    }

    Staking private _stakingContract;
    mapping(address => ProviderInfo) private _providers;

    constructor(Staking stakingContract) public {
        _stakingContract = stakingContract;
    }

    function isProvider(address addr) public view returns (bool) {
        return _providers[addr].status == ProviderStatus.APPROVED;
    }

    function applyToBeProvider(
        bytes32 name,
        bytes32 website,
        bytes32 iconUrl,
        bytes32 email
    ) public payable {
        require(!isProvider(msg.sender), "You are already a provider");
        // TODO: name required

        ProviderInfo memory p;
        p.name = name;
        p.website = website;
        p.iconUrl = iconUrl;
        p.email = email;
        p.addr = msg.sender;
        p.status = ProviderStatus.PENDING;

        _providers[msg.sender] = p;

        _stakingContract.providerStake(msg.sender, msg.value);
        emit Applied(msg.sender);
    }

    function approve(address addr) public onlyGovernor {
      require(!isProvider(addr), "Already a provider");
      // TODO: require(_stakingContract.checkProviderStake(addr), "Provider not staked requirements");

      _providers[addr].status = ProviderStatus.APPROVED;
      emit StatusChanged(msg.sender, _providers[addr].status);
    }

    function ban(address addr) public onlyGovernor {
      require(isProvider(addr), "Not a provider");

      _providers[addr].status = ProviderStatus.BANNED;
      emit StatusChanged(msg.sender, _providers[addr].status);
    }

    // TODO: OnlyGovernor -> Governors by voting
    function updateStakingContract(Staking addr) public onlyGovernor {
        _stakingContract = addr;
    }
}
