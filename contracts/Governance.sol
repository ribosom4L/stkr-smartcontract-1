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
    event ProposalFinished(bytes32 indexed ID, bool accepted, uint256 blockNum);
    event Vote(address indexed holder, bytes32 indexed ID, bytes32 vote, uint256 votes);
    event Propose(address indexed proposer, bytes32 proposeID, string topic, string content, uint span);

    IConfig private configContract;
    IStaking private depositContract;

    bytes32 internal constant _spanLo_ = "spanLo";
    bytes32 internal constant _spanHi_ = "spanHi";
    bytes32 internal constant _proposalMinimumThreshold_ = "proposalMinimumDepositThreshold";

    bytes32 internal constant _startBlock_ = "startBlock";

    bytes32 internal constant _proposeTopic_ = "proposeTopic";
    bytes32 internal constant _proposeContent_ = "proposeContent";
    bytes32 internal constant _timePropose_ = "timePropose";
    bytes32 internal constant _proposer_ = "proposer";

    bytes32 internal constant _totalProposes_ = "proposer";
    bytes32 internal constant _minimumVoteAcceptance_ = "minimumVoteAcceptance";

    bytes32 internal constant _proposeID_ = "proposeID";
    bytes32 internal constant _proposeStatus_ = "proposeStatus";

    bytes32 internal constant _votes_ = "votes";
    bytes32 internal constant _voteCount_ = "voteCount";

    uint256 internal constant PROPOSE_STATUS_VOTING = 1;
    uint256 internal constant PROPOSE_STATUS_FAIL = 2;
    uint256 internal constant PROPOSE_STATUS_PASS = 3;

    bytes32 internal constant VOTE_YES = "VOTE_YES";
    bytes32 internal constant VOTE_NO = "VOTE_NO";
    bytes32 internal constant VOTE_CANCEL = "VOTE_CANCEL";

    uint256 internal constant DIVISOR = 1 ether;

    function initialize(IStaking _depositContract) public initializer {
        __Ownable_init();

        depositContract = _depositContract;

        // minimum ankrs deposited needed for voting
        changeConfiguration(_proposalMinimumThreshold_, 5000000 ether);

        changeConfiguration("PROVIDER_MINIMUM_ANKR_STAKING", 100000 ether);
        changeConfiguration("PROVIDER_MINIMUM_ETH_TOP_UP", 0.1 ether);
        changeConfiguration("PROVIDER_MINIMUM_ETH_STAKING", 2 ether);
        changeConfiguration("REQUESTER_MINIMUM_POOL_STAKING", 500 finney);
        changeConfiguration("EXIT_BLOCKS", 24);

        changeConfiguration(_spanLo_, 24 * 60 * 60 * 3);
        // 3 days
        changeConfiguration(_spanHi_, 24 * 60 * 60 * 7);
        // 7 days
    }

    function propose(uint256 _timeSpan, string memory _topic, string memory _content) public {
        require(_timeSpan >= getConfig(_spanLo_), "Timespan lower than limit");
        require(_timeSpan <= getConfig(_spanHi_), "Timespan greater than limit");

        address sender = msg.sender;
        uint256 senderInt = uint(sender);
        uint256 totalProposes = getConfig(_totalProposes_);
        bytes32 _proposeID = bytes32(senderInt ^ totalProposes ^ block.number);
        uint256 idInteger = uint(_proposeID);
        setConfig(_totalProposes_, totalProposes.add(1));

        // lock user tokens
        require(depositContract.freeze(sender, getConfig(_proposalMinimumThreshold_)), "Dont have enough deposited or approved funds to lock");

        // set started block
        setConfig(_startBlock_, idInteger, block.number);
        setConfig(_proposer_, idInteger, senderInt);

        setConfigString(_proposeTopic_, idInteger, _topic);
        setConfigString(_proposeContent_, idInteger, _content);

        setConfig(_timePropose_, idInteger, _timeSpan.add(now));
        setConfig(_proposeStatus_, idInteger, PROPOSE_STATUS_VOTING);

        // set proposal status (pending)
        emit Propose(sender, _proposeID, _topic, _content, _timeSpan);
        vote(_proposeID, VOTE_YES);
    }

    function vote(bytes32 _ID, bytes32 _vote) public {
        uint256 ID = uint256(_ID);
        uint256 status = getConfig(_proposeStatus_, ID);
        require(status == PROPOSE_STATUS_VOTING, "Propose status is not VOTING");

        address _holder = msg.sender;
        uint256 _holderID = uint(_holder) ^ uint(ID);
        if (now <= getConfig(_timePropose_, ID)) {
            // previous vote type
            bytes32 voted = bytes32(getConfig(_votes_, _holderID));
            // previous vote count
            uint256 voteCount = getConfig(_voteCount_, _holderID);

            uint256 ID_voted = uint256(_ID ^ voted);
            // if this is a cancelling operation, set vote count to 0 for user and remove votes
            if ((voted == VOTE_YES || voted == VOTE_NO) && _vote == VOTE_CANCEL) {
                _setConfig(_votes_, ID_voted, getConfig(_votes_, ID_voted).sub(voteCount));
                _setConfig(_voteCount_, _holderID, 0);

                _setConfig(_votes_, _holderID, uint256(_vote));
                emit Vote(_holder, _ID, _vote, 0);
                return;
            }

            uint256 ID_vote = uint256(_ID ^ _vote);
            // get total stakes from deposit contract
            uint256 staked = depositContract.depositsOf(msg.sender);

            if ((voted == 0x0 || voted == VOTE_CANCEL) && (_vote == VOTE_YES || _vote == VOTE_NO)) {
                _setConfig(_votes_, ID_vote, getConfig(_votes_, ID_vote).add(staked.div(DIVISOR)));
            }
            _setConfig(_votes_, _holderID, uint256(_vote));
            emit Vote(_holder, _ID, _vote, staked);
        }
    }

    function depositAndPropose(uint256 _timeSpan, string memory _topic, string memory _content) external {
        depositContract.deposit(msg.sender);
        propose(_timeSpan, _topic, _content);
    }

    function depositAndVote(bytes32 _ID, bytes32 _vote) external {
        depositContract.deposit(msg.sender);
        vote(_ID, _vote);
    }

    //0xc7bc95c2
    function getVotes(bytes32 _ID, bytes32 _vote) public view returns (uint256) {
        return getConfig(_votes_, uint256(_ID ^ _vote));
    }

    event ProposalFinished(bytes32 indexed _proposeID, bool result, uint256 _yes, uint256 _no);

    function finishProposal(bytes32 _ID) public returns (bool result) {
        uint256 ID = uint256(_ID);
        require(getConfig(_timePropose_, ID) <= now, "There is still time for proposal");
        require(getConfig(_proposeStatus_, ID) == PROPOSE_STATUS_VOTING, "You cannot finish proposals that already finished");

        uint256 yes = 0;
        uint256 no = 0;

        (result, yes, no,,,) = proposal(_ID);

        _setConfig(_proposeStatus_, ID, result ? PROPOSE_STATUS_PASS : PROPOSE_STATUS_FAIL);
        emit ProposalFinished(_ID, result, yes, no);
    }

    function proposal(bytes32 _ID) public view returns (
        bool result,
        uint256 yes,
        uint256 no,
        string memory topic,
        string memory content,
        uint256 status
    ) {
        uint256 idInteger = uint(_ID);
        yes = getConfig(_votes_, uint256(_ID ^ VOTE_YES));
        no = getConfig(_votes_, uint256(_ID ^ VOTE_NO));

        result = yes > no && yes.add(no) > getConfig(_minimumVoteAcceptance_);

        topic = getConfigString(_proposeTopic_, idInteger);
        content = getConfigString(_proposeContent_, idInteger);

        status = getConfig(_proposeStatus_, idInteger);
    }

    function changeConfiguration(bytes32 key, uint256 value) public {
        uint256 oldValue = config[key];
        if (oldValue != value) {
            config[key] = value;
            emit ConfigurationChanged(key, oldValue, value);
        }
    }
}
