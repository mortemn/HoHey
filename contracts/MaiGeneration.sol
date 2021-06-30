// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Mai is ERC20, ERC20Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant VOTER_ROLE = keccak256("VOTER_ROLE");

    event _VoteCommitted(uint indexed pollID, uint numTokens, address indexed voter);
    event _VoteRevealed(uint indexed pollID, uint numTokens, uint votesFor, uint votesAgainst, uint indexed choice, address indexed voter, uint salt);
    event _PollCreated(uint voteQuorum, uint commitEndDate, uint revealEndDate, uint indexed pollID, address indexed creator);
    event _VotingRightsGranted(uint numTokens, address indexed voter);
    event _VotingRightsWithdrawn(uint numTokens, address indexed voter);
    event _TokensRescued(uint indexed pollID, address indexed voter);

    uint256 constant public INITIAL_POLL_NONCE = 0;
    uint256 public pullNonce;

    constructor() ERC20("Mai", "MAI") {
        _mint(msg.sender, 10000 * 10 ** decimals());
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(VOTER_ROLE, msg.sender);
    }

    struct Poll {
        uint256 commitEndDate;
        uint256 revealEndDate;
        uint256 voteQuorum;
        uint256 votesFor;
        uint256 votesAgainst;
        mapping(address => uint256) _votesCommitted;
        mapping(address => uint256) _votes;
    }

    mapping (uint256 => Poll) public _mapToPoll;

    function voterAllocation(address voter) public {
        require(balanceOf(voter) >= 1000);
        add(VOTER_ROLE, voter);
    }

    modifier voterCheck(address voter) public {
        require(hasRole(VOTER_ROLE) || balanceOf(voter) >= 1000);
        if (hasRole(VOTER_ROLE) == False) {
            voterAllocation(voter);
        }
    }

    function claimVote(address voter) public voterCheck{
        uint256 claimable = sub(_votesClaimed[voter], 1000);
        require(claimable > 0, "Address has no votes available to claim");
        _votesClaimed[voter] = add(_votesClaimed[voter], claimable);
        _votes[voter] = add(_votes[voter], claimable);
    }

    function makeVote(address voter, uint256 votesMade, uint256 pollID) public voterCheck{
        require(_votes[voter] > 0, "Address has no votes current, call function claimVote to claim a vote");
        require(_votesMade <= _votes[voter]);
        _votes[voter] = sub(_votes[voter], votesMade);
        emit VoteCommitted(pollID, votesMade, voter);
    }

    function mint(address to, uint256 amount) public {
        require(hasRole(MINTER_ROLE, msg.sender));
        _mint(to, amount);
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    }
