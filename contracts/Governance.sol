pragma solidity ^0.6.11;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "./lib/Pausable.sol";
import "./lib/interfaces/IConfig.sol";
import "./lib/interfaces/IStaking.sol";
import "./lib/Configurable.sol";
import "./Config.sol";

contract Governance is Pausable, Configurable {
    using SafeMath for uint256;

    event ConfigurationChanged(bytes32 indexed key, uint256 oldValue, uint256 newValue);
    event ProposalFinished(uint64 indexed proposalId, bool accepted, uint256 blockNum);
    event Vote(address indexed _holder, bytes32 indexed _ID, bytes32 _vote, uint256 _votes);
    event Propose(address indexed _proposer, bytes32 _proposeID, string _subject, string _content, uint _span);

    IConfig private configContract;
    IStaking private depositContract;

    bytes32 internal constant _spanLo_                      = "spanLog";
    bytes32 internal constant _spanHi_                      = "spanHi";
    bytes32 internal constant _proposalMinimumThreshold_ 	= "proposalMinimumDepositThreshold";

    bytes32 internal constant _startBlock_                  = "startBlock";

    bytes32 internal constant _proposeTopic_				= "proposeTopic";
    bytes32 internal constant _proposeContent_				= "proposeContent";
    bytes32 internal constant _timePropose_					= "timePropose";
    bytes32 internal constant _proposer_                    = "proposer";

    bytes32 internal constant _totalProposes_               = "proposer";
    bytes32 internal constant _minimumVoteAcceptance_       = "minimumVoteAcceptance";

    bytes32 internal constant _proposeID_					= "proposeID";
    bytes32 internal constant _proposeStatus_				= "proposeStatus";

    bytes32 internal constant _votes_						= "votes";
    bytes32 internal constant _voteCount_					= "voteCount";

    uint256 internal constant PROPOSE_STATUS_VOTING			= uint256(bytes32("PROPOSE_STATUS_VOTING"));
    uint256 internal constant PROPOSE_STATUS_FAIL			= uint256(bytes32("PROPOSE_STATUS_FAIL"));
    uint256 internal constant PROPOSE_STATUS_PASS			= uint256(bytes32("PROPOSE_STATUS_PASS"));

    bytes32 internal constant VOTE_YES                      = "VOTE_YES";
    bytes32 internal constant VOTE_NO                       = "VOTE_NO";
    bytes32 internal constant VOTE_CANCEL                   = "VOTE_CANCEL";

    uint256 internal constant DIVISOR                       = 18 ether;

    function initialize(IConfig _configContract, IStaking _depositContract) public initializer {
        __Ownable_init();

        configContract = _configContract;
        depositContract = _depositContract;

        // minimum ankrs deposited needed for voting
        changeConfiguration(_proposalMinimumThreshold_, 5000000 ether);

        changeConfiguration("PROVIDER_MINIMUM_ANKR_STAKING", 100000 ether);
        changeConfiguration("PROVIDER_MINIMUM_ETH_TOP_UP", 0.1 ether);
        changeConfiguration("PROVIDER_MINIMUM_ETH_STAKING", 2 ether);
        changeConfiguration("REQUESTER_MINIMUM_POOL_STAKING", 500 finney);
        changeConfiguration("EXIT_BLOCKS", 600); // 2 hours in blocks
    }

    function propose(uint256 _timeSpan, string memory _topic, string memory _content) external {
        require(_timeSpan >= getConfig(_spanLo_) && _timeSpan <= getConfig(_spanHi_), "Timespan not in limits");
        address sender = msg.sender;
        uint256 senderInt = uint(sender);
        uint256 totalProposes = getConfig(_totalProposes_);
        bytes32 _proposeID = bytes32(senderInt ^ totalProposes ^ block.number);
        uint256 idInteger = uint(_proposeID);
        setConfig(_totalProposes_, (totalProposes.add(1)));

        // lock user tokens
        depositContract.freeze(sender, getConfig("PROPOSAL_MINIMUM_DEPOSIT"));

        // set started block
        setConfig(_startBlock_, idInteger, block.number);
        setConfig(_proposer_, idInteger, senderInt);

        setConfigString(_proposeTopic_, idInteger, _topic);
        setConfigString(_proposeContent_, idInteger, _content);

        setConfig(_timePropose_, idInteger, _timeSpan.add(now));
        setConfig(_proposeID, idInteger, PROPOSE_STATUS_VOTING);

        // set proposal status (pending)
        emit Propose(sender, _proposeID, _topic, _content, _timeSpan);
        vote(_proposeID, VOTE_YES);
    }

    function vote(bytes32 _ID, bytes32 _vote) public {
        uint256 ID = uint256(_ID);
        uint256 status = getConfig(_proposeStatus_, ID);
        require(status == PROPOSE_STATUS_VOTING, "Propose status is not VOTING");

        address _holder = msg.sender;
        uint256 _holderID = uint(_holder)^uint(ID);
        if(now <= getConfig(_timePropose_, ID)) {
            // previous vote type
            bytes32 voted = bytes32(getConfig(_votes_, _holderID));
            // previous vote count
            uint256 voteCount = getConfig(_voteCount_, _holderID);

            uint256 ID_voted = uint256(_ID^voted);
            // if this is a cancelling operation, set vote count to 0 for user and remove votes
            if((voted == VOTE_YES || voted == VOTE_NO) && _vote == VOTE_CANCEL) {
                _setConfig(_votes_, ID_voted, getConfig(_votes_, ID_voted).sub(voteCount));
                _setConfig(_voteCount_, _holderID, 0);

                _setConfig(_votes_, _holderID, uint256(_vote));
                emit Vote(_holder, _ID, _vote, 0);
                return;
            }

            uint256 ID_vote = uint256(_ID^_vote);
            // get total stakes from deposit contract
            uint256 staked = depositContract.stakesOf(msg.sender);

            if((voted == 0x0 || voted == VOTE_CANCEL) && (_vote == VOTE_YES || _vote == VOTE_NO)) {
                _setConfig(_votes_, ID_vote, getConfig(_votes_, ID_vote).add(staked.div(DIVISOR)));
            }
            _setConfig(_votes_, _holderID, uint256(_vote));
            emit Vote(_holder, _ID, _vote, staked);
        }
    }

    //0xc7bc95c2
    function getVotes(bytes32 _ID, bytes32 _vote) public view returns(uint256) {
        return getConfig(_votes_, uint256(_ID^_vote));
    }

    event ProposalFinished(bytes32 indexed _proposeID, bool result, uint256 _yes, uint256 _no);
    function finishProposal(bytes32 _ID) public returns(bool result) {
        uint256 ID = uint256(_ID);
        require(getConfig(_timePropose_, ID) <= now, "There is still time for proposal");
        require(getConfig(_proposeStatus_, ID) == PROPOSE_STATUS_VOTING, "You cannot finish proposals that already finished");

        uint256 yes = 0;
        uint256 no = 0;

        (result, yes, no) = proposalStatus(_ID);

        _setConfig(_proposeStatus_, ID, result ? PROPOSE_STATUS_PASS : PROPOSE_STATUS_FAIL);
        emit ProposalFinished(_ID, result, yes, no);
    }

    function proposalStatus(bytes32 _ID) public view returns(bool result, uint256 yes, uint256 no) {
        yes = getConfig(_votes_, uint256(_ID^VOTE_YES));
        no = getConfig(_votes_, uint256(_ID^VOTE_NO));

        result = yes > no && yes.add(no) > getConfig(_minimumVoteAcceptance_);
    }

    function changeConfiguration(bytes32 key, uint256 value) public  {
        uint256 oldValue = config[key];
        if(oldValue != value) {
            config[key] = value;
            emit ConfigurationChanged(key, oldValue, value);
        }
    }
}
