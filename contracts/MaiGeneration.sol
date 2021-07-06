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
    bytes32 public constant STAKER_ROLE = keccak256("STAKER_ROLE");

    event _VoteMade(uint256 indexed pollID, uint256 votes, address indexed voter, uint256 side);
    event _VoteClaimed(address indexed voter, uint256 amountClaimed);
    event _VoteRevoked(uint256 indexed pollID, uint256 votes, address indexed voter); 
    event _VotingTimeAdded(uint256 indexed lengthExtended, uint256 indexed NewCommitDuration);
    event _VoteEnded(uint256 indexed pollID);
    event _RewardsMinted(uint256 indexed pollID, uint256 indexed amount);
    event _RewardsBurned(uint256 indexed pollID, uint256 indexed amount);
    event _PollCreated(uint voteAmount, uint commitEndDate, uint indexed pollID, address indexed creator);
    event _VotingRightsGranted(address indexed voter);
    event _VotingRightsRevoked(address indexed voter);
    event _resultsGenerated(uint256 amountMinted, uint256 pollID);

    constructor() ERC20("Mai", "MAI") {
        _mint(msg.sender, 1000 * 10 ** decimals());
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(VOTER_ROLE, msg.sender);
        _setupRole(STAKER_ROLE, msg.sender);
    }

    struct Poll {
        uint256 commitEndDate; // Date when poll ends
        uint256 voteAmount; // Amount of votes minted/ burned if poll is passed
        bool quorumOption; // Allows option to judge voting process by percentage 
        uint256 voteQuorum; // The percentage of for votes required for poll to pass
        uint256 votesFor; // Amount of votes supporting the proposal 
        uint256 votesAgainst; // Amount of votes countering the proposal
        uint256 option; // Option 1: Minting tokens; Option 2: Burning tokens
        bool ongoing; // Returns true if poll is still active
        mapping(address => uint256) _votesClaimed; // Amount of votes already claimed by the voter
        mapping(address => bool) _participant; // Maps address of user to whether they have voted in an active poll
        mapping(address => uint256) _votes; // Amount of votes placed by the voter
        mapping(address => uint256) _side; // The side the voter is on if they already voted
    }

    
    mapping (uint256 => Poll) public pollMapping; // Maps the pollID to the struct
    mapping (uint256 => uint256) public totalVotes; // Maps the pollID to its respective number of votes
    mapping (address => uint256) public stakedTotal; // Maps the user address to their total staked balance in all categories
    uint256 pollNonce = 0; // Counter for pollID
    address stakingAddress; // Address used for storing staked tokens

    /**
    @dev Initiates poll and emits PollCreate event
    @param _quorumOption Users can decide if the winner is decided by the percentage majority out of 100 or whether the 'for' side has more votes than the 'against' side
    @param _voteQuorum Assumes that the _quorumOption is false, passes in the percentage majority out of 100 that is required to win the vote
    @param _voteAmount The amount of tokens minted/burned if poll is successful 
    @param _commitDuration Length of the poll in seconds
    @param _option Type of poll, option 1 is for minting tokens, option 2 is for burning tokens 
    */

    function startPoll(bool _quorumOption, uint256 _voteQuorum, uint256 _voteAmount, uint256 _commitDuration, uint256 _option) public returns (uint256 pollID) {
        require ((_quorumOption == false && _voteQuorum == 0) || (_quorumOption == true && _voteQuorum > 0));
        require (_voteAmount > 0, "The amount of tokens to be burned/ minted must be larger than 0");
        uint256 commitEndDate = block.timestamp.add(_commitDuration);
        pollNonce = pollNonce.add(1);
        Poll storage newPoll = pollMapping[pollNonce];
        newPoll.option = _option;
        newPoll.quorumOption = _quorumOption;
        newPoll.voteQuorum = _voteQuorum;
        newPoll.voteAmount = _voteAmount;
        newPoll.commitEndDate = commitEndDate;
        newPoll.votesFor = 0;
        newPoll.votesAgainst = 0;
        newPoll.ongoing = true;

        emit _PollCreated(_voteAmount, commitEndDate, pollNonce, msg.sender);
        return pollNonce;
    }

    /**
    @dev Allocates voter role to stakers and emits event
    @param voter address of staker
    */

    function voterAllocation(address voter) public {
        require(hasRole(STAKER_ROLE, msg.sender));
        grantRole(VOTER_ROLE, voter);
        emit _VotingRightsGranted(voter);
    }

    /**
    @dev Revokes votes that are already made and returns the vote to msg.sender
    @param amount Amount of votes to be revoked
    @param pollID ID of poll
    */

    function revokeVote(uint256 amount, uint256 pollID) public {
        require(msg.sender != address(0));
        require(pollMapping[pollID].ongoing = true);
        require(isNotExpired(pollID));
        require(amount <= pollMapping[pollID]._votes[msg.sender]);
        pollMapping[pollID]._votes[msg.sender] = pollMapping[pollID]._votes[msg.sender].sub(amount);
        pollMapping[pollID]._votesClaimed[msg.sender] = pollMapping[pollID]._votesClaimed[msg.sender].add(amount);
        if (pollMapping[pollID]._votes[msg.sender] == 0) {
            pollMapping[pollID]._participant[msg.sender] = false;
        }
        totalVotes[pollID] = totalVotes[pollID].sub(amount);
    }

    /**
    @dev a random transfer function for no apparent reason
    */

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
    @dev Function that takes away voter role from addresses when necessary
    @param voter Voter that is going to get their role revoked
    */

    function voterRevokation(address voter) public {
        require(hasRole(VOTER_ROLE, msg.sender));
        require(voter != address(0));
        revokeRole(VOTER_ROLE, voter);
        emit _VotingRightsRevoked(voter);
    }

    /**
    @dev Checks if user has voter role
    @param voter Address of voter
    */

    modifier voterCheck(address voter) {
        require(hasRole(VOTER_ROLE, voter));
        _;
    }

    /**
    @dev Claims votes from existing staked tokens and stores available votes at _votes
    @param pollID ID of vote
    */

    function claimVote(uint256 pollID) public voterCheck(msg.sender) {
        require(msg.sender != address(0));
        uint256 claimable = stakedTotal[msg.sender].sub(pollMapping[pollID]._votesClaimed[msg.sender]).sub(999);
        require(claimable > 0, "Address has no votes available to claim");
        pollMapping[pollID]._votesClaimed[msg.sender] = pollMapping[pollID]._votesClaimed[msg.sender].add(claimable);
        pollMapping[pollID]._votes[msg.sender] = pollMapping[pollID]._votes[msg.sender].add(claimable);
        emit _VoteClaimed(msg.sender, claimable);
    }

    /**
    @dev Returns number of votes available to users
    @param voter Address of requested voter
    @param pollID ID of poll
    */

    function numOfVotes(address voter, uint256 pollID) public view returns (uint256 votes) {
        require(voter != address(0));
        return pollMapping[pollID]._votes[voter]; 
    }

    /**
    @dev Voters makes votes on corresponding polls, deducting their _votes and emitting _VoteMade event
    @param votesMade Amount of votes going to be made
    @param pollID ID of the poll
    @param side The side of the poll the user wants to support (1: for; 2: against)
    */


    function makeVote(uint256 votesMade, uint256 pollID, uint256 side) public voterCheck(msg.sender) {
        require(msg.sender != address(0));
        require(pollMapping[pollID].ongoing = true);
        require(isNotExpired(pollID));
        require(pollMapping[pollID]._votes[msg.sender] > 0, "Address has no votes currently, call function claimVote to claim a vote");
        require(votesMade <= pollMapping[pollID]._votes[msg.sender]);
        require(pollMapping[pollID]._side[msg.sender] == 0 || pollMapping[pollID]._side[msg.sender] == side);
        require(side == 1 || side == 2);
        if (side == 1) {
            pollMapping[pollID].votesFor = pollMapping[pollID].votesFor.add(1);
        } else if (side == 2) {
            pollMapping[pollID].votesAgainst = pollMapping[pollID].votesAgainst.add(1);
        }
        pollMapping[pollID]._side[msg.sender] = side;
        pollMapping[pollID]._votes[msg.sender] = pollMapping[pollID]._votes[msg.sender].sub(votesMade);
        totalVotes[pollID] = totalVotes[pollID].add(1);
        pollMapping[pollID]._participant[msg.sender] = true;
        emit _VoteMade(pollID, votesMade, msg.sender, side); 
    }

    /**
    @dev Returns whether the poll/ proposal passed the voting
    @param pollID ID of the poll
    */

    function results(uint256 pollID) public returns (bool passed) {
        endPoll(pollID);
        require(isNotExpired(pollID) == false);
        require(pollExists(pollID));
        if (pollMapping[pollID].quorumOption == false) {
            if (pollMapping[pollID].votesFor > pollMapping[pollID].votesAgainst) {
                return (true);
            } else if (pollMapping[pollID].votesFor < pollMapping[pollID].votesAgainst) {
                return (false);
            } else {
                whenTie(pollID);
            }
        } else if (pollMapping[pollID].quorumOption == true) {
            if (quorumCalc(pollID) >= pollMapping[pollID].voteQuorum) {
                return (true);
            } else if (quorumCalc(pollID) < pollMapping[pollID].voteQuorum) {
                return  (false);
            } else {
                whenTie(pollID);
            }
        }
    }

    /**
    @dev Calculates the percentage of voters that supports the proposal
    @param pollID ID of the poll
    */

    function quorumCalc(uint256 pollID) public view returns (uint256 result) {
        require (totalVotes[pollID] > 0);
        require (pollExists(pollID), "Poll does not exist");
        uint256 ans = pollMapping[pollID].votesFor.div(totalVotes[pollID]);
        ans = ans.mul(100);
        return ans;
    }

    /**
    @dev Ends the poll instantly if necessary
    @param pollID ID of the poll
    */

    function endPoll(uint pollID) public {
        require(hasRole(PAUSER_ROLE, msg.sender));
        require(pollExists(pollID));
        pollMapping[pollID].ongoing = false;
    }

    /**
    @dev Returns Poll Tied string if the poll is tied
    @param pollID ID of the poll
    */

    function whenTie(uint256 pollID) public view returns (string memory tied) {
        require(pollExists(pollID));
        if (pollMapping[pollID].quorumOption == false) {
            if (pollMapping[pollID].votesFor == pollMapping[pollID].votesAgainst) {
                return ("Poll tied");
            }
        } else if (pollMapping[pollID].quorumOption == true) {
            if (quorumCalc(pollID) == pollMapping[pollID].voteQuorum) {
                return ("Poll tied");
            }
        }
    } 

    /**
    @dev Burns the proposed amount of tokens after the poll has ended and passed
    @param pollID ID of the poll
    */

    function burnRewards (uint256 pollID) public payable {
        require(pollMapping[pollID].option == 2);
        require(pollMapping[pollID].ongoing == false);
        _beforeTokenTransfer(msg.sender, address(0), pollMapping[pollID].voteAmount);
        burn(pollMapping[pollID].voteAmount);
        emit _resultsGenerated(pollMapping[pollID].voteAmount, pollID);
    }

    /**
    @dev Mints the proposed amount of tokens after the poll has ended and passed
    @param pollID ID of the poll
    */
        

    function mintRewards (uint256 pollID) public payable {
        require(pollMapping[pollID].option == 1);
        require(pollMapping[pollID].ongoing == false);
        _beforeTokenTransfer(address(0), msg.sender, pollMapping[pollID].voteAmount);
        _mint(msg.sender, pollMapping[pollID].voteAmount);
        emit _resultsGenerated(pollMapping[pollID].voteAmount, pollID);  
    }

    /**
    @dev Adds time to the commit duration of the poll
    @param pollID ID of the poll
    @param timeAdded Amount of time to be added to the poll
    */
    
    function addTime(uint256 pollID, uint256 timeAdded) public {
        require (pollExists(pollID)); 
        require(timeAdded > 0, "Must add time greater than 0");
        pollMapping[pollID].commitEndDate = pollMapping[pollID].commitEndDate.add(timeAdded); 
    }

    /**
    @dev Checks if the address of the voter has participated in any active poll
    @param voter Address of the voter
    */

    function checkParticipation(address voter) public view returns(bool participating){
        for (uint256 i = 1; i < pollNonce; i++) {
            if (pollMapping[i].ongoing == true && pollMapping[i]._participant[voter] == true) {
                return true;
            }
        }
        return false;
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
        override
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    function mint(address to, uint256 amount) public {
        require(hasRole(MINTER_ROLE, msg.sender));
        _mint(to, amount);
        _beforeTokenTransfer(address(0), msg.sender, amount);
    }

    /**
    @dev Checks if poll exists and returns a boolean value
    @param _pollID ID of the poll
    */

    function pollExists(uint256 _pollID) public view returns (bool exists) {
        return (_pollID != 0 && _pollID <= pollNonce);
    }

    /**
    @dev Checks of poll has ended or not
    @param _pollID ID of the poll
    */

    function pollEnded(uint256 _pollID) public view returns (bool ended) {
        require(pollExists(_pollID));

        return isNotExpired(pollMapping[_pollID].commitEndDate);
    }

    /**
    @dev Checks if a date has expired or not
    @param _terminationDate The date for checking
    */

    function isNotExpired(uint256 _terminationDate) public view returns (bool expired) {
        return (block.timestamp < _terminationDate);
    }

}
