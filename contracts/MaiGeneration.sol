// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract Mai is ERC20, ERC20Burnable, AccessControl, Pausable{
    using SafeMath for uint256;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant VOTER_ROLE = keccak256("VOTER_ROLE");

    event _VoteMade(uint256 indexed pollID, uint256 votes, address indexed voter);
    event _PollCreated(uint voteQuorum, uint commitEndDate, uint indexed pollID, address indexed creator);
    event _VotingRightsGranted(address indexed voter);
    event _VotingRightsRevoked(address indexed voter);
    event _resultsGenerated(uint256 amountMinted, uint256 pollID);

    constructor() ERC20("Mai", "MAI") {
        _mint(msg.sender, 1000 * 10 ** decimals());
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(VOTER_ROLE, msg.sender);
    }

    struct Poll {
        uint256 commitEndDate;
        uint256 voteQuorum;
        uint256 votesFor;
        uint256 votesAgainst;
        bool ongoing;
        mapping(address => uint256) _votesClaimed;
        mapping(address => uint256) _votes;
    }

    mapping (uint256 => Poll) public pollMapping;
    uint256 pollNonce = 0;

    function startPoll(uint256 _voteQuorum, uint256 _commitDuration) public returns (uint256 pollID) {
        uint256 commitEndDate = block.timestamp.add(_commitDuration);
        pollNonce = pollNonce.add(1);
        Poll storage newPoll = pollMapping[pollNonce];
        newPoll.voteQuorum = _voteQuorum;
        newPoll.commitEndDate = commitEndDate;
        newPoll.votesFor = 0;
        newPoll.votesAgainst = 0;
        newPoll.ongoing = true;

        emit _PollCreated(_voteQuorum, commitEndDate, pollNonce, msg.sender);
        return pollNonce;
    }

    function voterAllocation(address voter) public {
        require(balanceOf(voter) >= 1000);
        grantRole(VOTER_ROLE, voter);
        emit _VotingRightsGranted(voter);
    }

    function voteRevokation(address voter) public {
        revokeRole(VOTER_ROLE, voter);
        emit _VotingRightsRevoked(voter);
    }

    modifier voterCheck(address voter) {
        if (hasRole(VOTER_ROLE, voter) == false && balanceOf(voter) >= 1000) {
            voterAllocation(voter);
        }
        if (hasRole(VOTER_ROLE, voter) == true && balanceOf(voter) < 1000) {
           voteRevokation(voter); 
        }
        require(hasRole(VOTER_ROLE, voter) || balanceOf(voter) >= 1000, "Only addresses that have balances of over 1000 tokens are able to vote");
        _;
    }

    function claimVote(address voter, uint256 pollID) public whenNotPaused voterCheck(voter) {
        uint256 claimable = pollMapping[pollID]._votesClaimed[voter].sub(999);
        require(claimable > 0, "Address has no votes available to claim");
        pollMapping[pollID]._votesClaimed[voter] = pollMapping[pollID]._votesClaimed[voter].add(claimable);
        pollMapping[pollID]._votes[voter] = pollMapping[pollID]._votes[voter].add(claimable);
    }

    function numOfVotes(address voter, uint256 pollID) public view returns (uint256 votes) {
        return pollMapping[pollID]._votes[voter]; 
    }

    function makeVote(address voter, uint256 votesMade, uint256 pollID, uint256 side) public whenNotPaused voterCheck(voter) {
        require(pollMapping[pollID].ongoing = true);
        require(isNotExpired(pollID));
        require(pollMapping[pollID]._votes[voter] > 0, "Address has no votes currently, call function claimVote to claim a vote");
        require(votesMade <= pollMapping[pollID]._votes[voter]);
        require(side == 1 || side == 2);
        if (side == 1) {
            pollMapping[pollID].votesFor = pollMapping[pollID].votesFor.add(1);
        } else if (side == 2) {
            pollMapping[pollID].votesAgainst = pollMapping[pollID].votesAgainst.add(1);
        }
        pollMapping[pollID]._votes[voter] = pollMapping[pollID]._votes[voter].sub(votesMade);
        emit _VoteMade(pollID, votesMade, voter); 
    }

    function results(uint256 pollID) public returns (bool passed) {
        endPoll(pollID);
        require(isNotExpired(pollID) == false);
        require(pollExists(pollID));
        if (pollMapping[pollID].votesFor > pollMapping[pollID].votesAgainst) {
            return (true);
        } else if (pollMapping[pollID].votesFor < pollMapping[pollID].votesAgainst) {
            return (false);
        } else {
            whenTie(pollID);
        }
    }

    function endPoll(uint pollID) public {
        require(hasRole(PAUSER_ROLE, msg.sender));
        require(pollExists(pollID));
        pollMapping[pollID].ongoing = false;
    }

    function whenTie(uint256 pollID) public view returns (string memory tied) {
        require(pollExists(pollID));
        if (pollMapping[pollID].votesFor == pollMapping[pollID].votesAgainst) {
            return ("Poll tied");
        }
    }

    function mintRewards (uint256 pollID) public payable {
        require(pollMapping[pollID].ongoing == false);
        _mint(msg.sender, pollMapping[pollID].voteQuorum);
        emit _resultsGenerated(pollMapping[pollID].voteQuorum, pollID);  
    }
        
    
    function addTime(uint256 pollID, uint256 timeAdded) public {
        require (pollExists(pollID)); 
        require(timeAdded > 0, "Must add time greater than 0");
        pollMapping[pollID].commitEndDate = pollMapping[pollID].commitEndDate.add(timeAdded); 
    }


    function pause() public {
        require(hasRole(PAUSER_ROLE, msg.sender));
        _pause();
    }

    function unpause() public {
        require(hasRole(PAUSER_ROLE, msg.sender));
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function mint(address to, uint256 amount) public {
        require(hasRole(MINTER_ROLE, msg.sender));
        _mint(to, amount);
    }

    function pollExists(uint256 _pollID) public view returns (bool exists) {
        return (_pollID != 0 && _pollID <= pollNonce);
    }

    function pollEnded(uint256 _pollID) public view returns (bool ended) {
        require(pollExists(_pollID));

        return isNotExpired(pollMapping[_pollID].commitEndDate);
    }

    function isNotExpired(uint256 _terminationDate) public view returns (bool expired) {
        return (block.timestamp > _terminationDate);
    }

}
