// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Mai is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant VOTER_ROLE = keccak256("VOTER_ROLE");

    event _VoteMade(uint256 indexed pollID, uint256 votes, address indexed voter);
    event _PollCreated(uint voteQuorum, uint commitEndDate, uint revealEndDate, uint indexed pollID, address indexed creator);
    event _VotingRightsGranted(address indexed voter);
    event _VotingRightsRevoked(address indexed voter);

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
        mapping(address => uint256) _votesCommitted;
        mapping(address => uint256) _votes;
    }

    mapping (uint256 => Poll) public pollMapping;
    uint256 pollNonce = 0;

    function startPoll(uint256 _voteQuorum, uint256 _commitDuration) public returns (uint256 pollID) {
        uint commitEndDate = block.timestamp.add(_commitDuration);
        pollNonce = pollNonce.add(1);
        pollMapping[pollNonce] = Poll({
            voteQuorum: _voteQuorum,
            commitEndDate: commitEndDate,
            votesFor: 0,
            votesAgainst: 0
        });

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
        if (hasRole(VOTER_ROLE) == False && numOfTokens >= 1000) {
            voterAllocation(voter);
        }
        if (hasRole(VOTER_ROLE) == True && numOfTokens < 1000) {
           voteRevokation(voter); 
        }
        require(hasRole(VOTER_ROLE) || balanceOf(voter) >= 1000, "Only addresses that have balances of over 1000 tokens are able to vote");
    }

    function claimVote(address voter) public voterCheck {
        uint256 claimable = sub(_votesClaimed[voter], 999);
        require(claimable > 0, "Address has no votes available to claim");
        pollMapping[pollID]._votesClaimed[voter] = add(_votesClaimed[voter], claimable);
        pollMapping[pollID]._votes[voter] = add(_votes[voter], claimable);
    }

    function numOfVotes(address voter, uint256 pollID) public returns (uint256 votes) {
        return pollMapping[pollID]._votes[voter]; 
    }

    function makeVote(address voter, uint256 votesMade, uint256 pollID) public voterCheck {
        require(isNotExpired);
        require(pollMapping[pollID]._votes[voter] > 0, "Address has no votes currently, call function claimVote to claim a vote");
        require(votesMade <= _pollMapping[pollID].votes[voter]);
        pollMapping[pollID]._votes[voter] = sub(_pollMapping[pollID].votes[voter], votesMade);
        emit _VoteMade(pollID, votesMade, voter); 
    }

    function mint(address to, uint256 amount) public {
        require(hasRole(MINTER_ROLE, msg.sender));
        _mint(to, amount);
    }

    function pollExists(uint256 _pollID) public returns (bool exists) {
        return (_pollID != 0 && _pollID <= pollNonce);
    }

    function pollEnded(uint256 _pollID) public returns (bool ended) {
        require(pollExists(_pollID));

        return isExpired(pollMapping[_pollID].commitEndDate);
    }

    function isExpired(uint256 _terminationDate) public returns (bool expired) {
        return (block.timestamp > _terminationDate);
    }

}
