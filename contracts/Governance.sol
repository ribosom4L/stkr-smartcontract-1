pragma solidity ^0.6.11;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "./lib/Pausable.sol";
import "./lib/interfaces/IConfig.sol";
import "./lib/interfaces/IStaking.sol";
import "./lib/Configurable.sol";
import "./Config.sol";

contract Governance is Pausable, Configurable {
    using SafeMath for uint256;

    event ProposalFinished(uint64 indexed proposalId, bool accepted, uint256 blockNum);
    event Vote(address indexed _holder, bytes32 indexed _ID, bytes32 _vote, uint256 _votes);
    event Propose(address indexed _proposer, bytes32 _proposeID, string _subject, string _content, uint _span);

    IConfig private configContract;
    IStaking private depositContract;

    bytes32 internal constant _spanLo_                      = "spanLog";
    bytes32 internal constant _spanHi_                      = "spanHi";
    bytes32 internal constant _proposalMinimumThreshold_ 	= "proposalMinimumDepositThreshold";
    bytes32 internal constant _waitBlocksAfterProposal_    	= "proposalMinimumDepositThreshold";

    bytes32 internal constant _startBlock_                  = "startBlock";

    bytes32 internal constant _proposeTopic_				= "proposeTopic";
    bytes32 internal constant _proposeContent_				= "proposeContent";
    bytes32 internal constant _timePropose_					= "timePropose";
    bytes32 internal constant _proposer_                    = "proposer";

    bytes32 internal constant _totalProposes_               = "proposer";

    bytes32 internal constant _proposeID_					= "proposeID";
    bytes32 internal constant _proposeStatus_				= "proposeStatus";

    bytes32 internal constant _votes_						= "votes";

    uint256 internal constant PROPOSE_STATUS_VOTING			= uint256(bytes32("PROPOSE_STATUS_VOTING"));
    uint256 internal constant PROPOSE_STATUS_FAIL			= uint256(bytes32("PROPOSE_STATUS_FAIL"));
    uint256 internal constant PROPOSE_STATUS_PASS			= uint256(bytes32("PROPOSE_STATUS_PASS"));

    bytes32 internal constant VOTE_YES                      = "VOTE_YES";
    bytes32 internal constant VOTE_NO                       = "VOTE_NO";
    bytes32 internal constant VOTE_CANCEL                   = "VOTE_CANCEL";

    bytes32 private lastProposeId;

    function initialize(IConfig _configContract, IStaking _depositContract) public initializer {
        __Ownable_init();

        configContract = _configContract;
        depositContract = _depositContract;

        // minimum ankrs deposited needed for voting
        _setConfig(_proposalMinimumThreshold_, 100000 ether);
        // blocks lock after propose
        _setConfig(_waitBlocksAfterProposal_, 1200);

        _setConfig("PROVIDER_MINIMUM_ANKR_STAKING", 100000 ether);
        _setConfig("PROVIDER_MINIMUM_ETH_STAKING", 2 ether);
        _setConfig("REQUESTER_MINIMUM_POOL_STAKING", 500 finney);
        _setConfig("EXIT_BLOCKS", 24);
    }

    function propose(uint256 _votingDays, string memory _topic, string memory _content) external {
        require(_votingDays >= getConfig(_spanLo_) && _votingDays <= getConfig(_spanHi_), "Timespan not in limits");
        address sender = msg.sender;
        uint256 totalProposes = getConfig(_totalProposes_);
        bytes32 _proposeID = bytes32(uint(sender) ^ totalProposes);
        setConfig(_totalProposes_, (totalProposes + 1));
        lastProposeId = _proposeID;

        // lock user tokens
        depositContract.freeze(sender, minimumAnkrForProposal());

        // set started block
        setConfig(_proposeID, uint(_startBlock_), block.number);
        setConfig(_proposeID, uint(_proposer_), uint(sender));
        _setConfigString(_proposeID, uint(_proposeTopic_), _topic);
        _setConfigString(_proposeID, uint(_proposeContent_), _content);
        setConfig(_proposeID, uint(_timePropose_), _votingDays);
        setConfig(_proposeStatus_, uint(_proposeID), PROPOSE_STATUS_VOTING);

        // set proposal status (pending)
        emit Propose(sender, _proposeID, _topic, _content, _votingDays);
        vote(_proposeID, VOTE_YES);
    }

    function vote(bytes32 _ID, bytes32 _vote) public {
        uint256 ID = uint256(_ID);
        uint256 status = getConfig(_proposeStatus_, ID);
        require(status == PROPOSE_STATUS_VOTING, "Propose status is not VOTING");

        address _holder = msg.sender;

        if(now <= getConfig(_timePropose_, ID)) {
            uint256 staked = depositContract.stakesOf(msg.sender);
            bytes32 voted = bytes32(getConfig(_votes_, uint(_holder)^uint(ID)));
            uint256 ID_voted = uint256(_ID^voted);
            if((voted == VOTE_YES || voted == VOTE_NO) && _vote == VOTE_CANCEL || voted ^ _vote == VOTE_YES ^ VOTE_NO) {
                _setConfig(_votes_, ID_voted, getConfig(_votes_, ID_voted).sub(staked));
            }
            uint256 ID_vote = uint256(_ID^_vote);
            if((voted == 0x0 || voted == VOTE_CANCEL) && (_vote == VOTE_YES || _vote == VOTE_NO) || voted ^ _vote == VOTE_YES ^ VOTE_NO) {
                _setConfig(_votes_, ID_vote, getConfig(_votes_, ID_vote).add(staked));
            }
            _setConfig(_votes_, uint(_holder)^uint(ID), uint256(_vote));
            emit Vote(_holder, _ID, _vote, staked);
        }
    }

    //0xc7bc95c2
    function getVotes(bytes32 _ID, bytes32 _vote) public view returns(uint256) {
        return getConfig(_votes_, uint256(_ID^_vote));
    }

    event VoteResult(bytes32 indexed _ID, bytes32 indexed _proposeID, bool result, uint256 _yes, uint256 _no);
    function voteResult(bytes32 _ID) internal returns(bool result) {

    }

    function minimumAnkrForProposal() public view returns(uint256) {
        return getConfig("PROPOSAL_MINIMUM_DEPOSIT");
    }

    function spanLow() public view returns(uint256) {
        return getConfig("LOW_TIME_SPAN_FOR_PROPOSAL");
    }

    function spanHigh() public view returns(uint256) {
        return getConfig("HIGH_TIME_SPAN_FOR_PROPOSAL");
    }
}
