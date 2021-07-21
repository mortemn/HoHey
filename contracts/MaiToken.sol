// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
   

contract Mai is Context, ERC20, ERC20Burnable, ERC20Snapshot, AccessControl, Pausable {
    using SafeMath for uint256;
    bytes32 public constant VOTER_ROLE = keccak256("VOTER_ROLE");
    bytes32 public constant STAKER_ROLE = keccak256("STAKER_ROLE");
    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    
    event _VoteMade(uint256 indexed pollID, uint256 votes, address indexed voter, uint256 side);
    event _VoteClaimed(address indexed voter, uint256 amountClaimed);
    event _VoteRevoked(uint256 indexed pollID, uint256 votes, address indexed voter); 
    event _VoteEnded(uint256 indexed pollID);
    event _RewardsMinted(uint256 indexed pollID, uint256 indexed amount);
    event _RewardsBurned(uint256 indexed pollID, uint256 indexed amount);
    event _PollCreated(uint256 votedTokenAmount, uint256 end, uint256 indexed pollID, address indexed creator);
    event _VotingRightsGranted(address indexed voter);
    event _VotingRightsRevoked(address indexed voter);
    event _ResultsGenerated(uint256 amount, uint256 pollID);
    event _Minted(address indexed to, uint256 amount);

    constructor() ERC20("Mai", "MAI") {
        _mint(msg.sender, 10**12 * 10 ** decimals());
        _setupRole(STAKER_ROLE, msg.sender);
        _setupRole(OWNER_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _setupRole(SNAPSHOT_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    modifier onlyOwner() {
        require(hasRole(OWNER_ROLE, msg.sender) || msg.sender == stakingAddress);
        _;
    }

    modifier checkTime(uint256 pollID) {
      if (pollEnded(pollID) == true && pollMapping[pollID].ongoing == true) {
        pollMapping[pollID].ongoing = false;
      } 
      _;
    }
      

    function pause() onlyOwner internal {
        _pause();
    }

    function unpause() onlyOwner internal {
        _unpause();
    }

    function snapshot() public onlyOwner() {
        _snapshot();
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }

    // Staking

    event _StakerGranted(address to);
    event _StakerRoleRevoked(address account, uint256 amountReturned);
    event _StakesDeposited(address account, uint256 amount);
    event _StakesWithdrawn(address account, uint256 amount);
    event _MinimumStakeChanged(uint256 minStake);

    mapping(address => uint256) stakedBalance; // Maps user address to the total amount of staked tokens

    
    uint256 minStake = 1000;
    // uint256 minStakeTimeBeforeVoterRoleGranted = ;

    function changeMinimumStake(uint256 newMinAmount) onlyOwner public {
        require(newMinAmount != minStake);
        require(msg.sender == stakingAddress);
        minStake = newMinAmount;
        emit _MinimumStakeChanged(newMinAmount);
    }

    /**
    @dev sets staking address for testing only
    @param staking Staking Address
    */

    function setStakingAddress(address staking) onlyOwner public {
      stakingAddress = staking;
    }

    /**
    @dev Allows users to stake, adding their respective amount of tokens to the staked balance
    @param amount Amount of tokens used in the stake pool
    */

    function stake(uint256 amount) payable public {
        require(amount >= minStake, "Must have a staked balance of more than minStake MAI to become a staker");
        require(hasRole(STAKER_ROLE, msg.sender) == false, "You are already a staker");
        transferFrom(msg.sender, stakingAddress, amount);
        grantRole(STAKER_ROLE, msg.sender);
        stakedBalance[msg.sender] = stakedBalance[msg.sender].add(amount);
        emit _StakerGranted(msg.sender);
    }

    /**
    @dev Withdraws tokens from the stake pool back to the users account, the user must not be part of any active polls
    @param amount Amount of tokens the user wishes to withdraw
    */

    function withdraw(uint256 amount) payable public {
        require(hasRole(STAKER_ROLE, msg.sender), "Must have staker role to perform this action");
        require(amount <= stakedBalance[msg.sender], "Must withdraw amount within balance"); 
        require(stakedBalance[msg.sender].sub(amount) >= minStake, "A balance of higher than minStake is required to maintain role of staker, if you wish to revoke the role of staker, use revokeStaker() function");
        require(checkParticipation(msg.sender) == false, "You must not be participating in any vote in order to withdraw any staked tokens");
        transfer(msg.sender, amount);
        stakedBalance[msg.sender] = stakedBalance[msg.sender].sub(amount);
        emit _StakesWithdrawn(msg.sender, amount);
    }

    /**
    @dev Deposits tokens into the stake pool from the users account
    @param amount Amount of tokens the user wishes to deposit
    */

    function deposit(uint256 amount) payable public {
        require(hasRole(STAKER_ROLE, msg.sender), "Must have staker role to perform this action");
        transfer(stakingAddress, amount);
        stakedBalance[msg.sender] = stakedBalance[msg.sender].add(amount);
        emit _StakesDeposited(msg.sender, amount);
    }

    /**
    @dev Function for users to see the balance they currently have in the stake pool
    */

    function viewStakedBalance() view public returns (uint256 balance) {
        require(hasRole(STAKER_ROLE, msg.sender), "Must have staker role to perform this action");
        return (stakedBalance[msg.sender]);
    }

    /**
    @dev Revokes their staker role and returns all their tokens back to the user
    */
    
    function revokeStaker() public {
        require(hasRole(STAKER_ROLE, msg.sender), "Must have staker role to perform this action");
        revokeRole(STAKER_ROLE, msg.sender);
        transfer(msg.sender, stakedBalance[msg.sender]);
        stakedBalance[msg.sender] = 0;
        emit _StakerRoleRevoked(msg.sender, stakedBalance[msg.sender]); 
    }

    // Polls and votes

    struct Poll {
        address pollStarter; // initiator of the poll;
        uint256 start; // block start;
        uint256 end; // start + period (_commitDuration)
        // uint256 end; // Date when poll ends
        uint256 votedTokenAmount; // Amount of tokens minted/ burned if poll is passed
        bool quorumOption; // Allows option to judge voting process by percentage 
        uint256 voteQuorum; // The percentage of for votes required for poll to pass
        uint256 votesFor; // Amount of votes supporting the proposal 
        uint256 votesAgainst; // Amount of votes countering the proposal
        uint256 action; // action 1: Minting tokens; action 2: Burning tokens; action 3: Transfering tokens; action 4: snapshot;
        bool ongoing; // Returns true if poll is still active
        bool rewardsClaimed; // Stores if the rewards were already claimed
        mapping(address => uint256) _votesClaimed; // Amount of votes already claimed by the voter
        mapping(address => bool) _participant; // Maps address of user to whether they have voted in an active poll
        mapping(address => uint256) _votes; // Amount of votes placed by the voter
        mapping(address => uint256) _side; // The side the voter is on if they already voted
    }

    
    mapping (uint256 => Poll) public pollMapping; // Maps the pollID to the struct
    mapping (uint256 => uint256) public totalVotes; // Maps the pollID to its respective number of votes
    mapping (address => uint256) public stakedTotal; // Maps the user address to their total staked balance in all categories
    uint256 pollNonce = 0; // Counter for pollID
    address public stakingAddress; // Address used for storing staked tokens

    /**
    @dev Initiates poll and emits PollCreate event
    @param _quorumOption Users can decide if the winner is decided by the percentage majority out of 100 or whether the 'for' side has more votes than the 'against' side
    @param _voteQuorum Assumes that the _quorumOption is false, passes in the percentage majority out of 100 that is required to win the vote
    @param _votedTokenAmount The amount of tokens minted/burned if poll is successful 
    @param _commitDuration Length of the poll in days
    @param _action Type of poll, action 1 is for minting tokens, action 2 is for burning tokens, action 3 is for transfering tokens, action 4 is for taking a snapshot.
    */

    function startPoll(bool _quorumOption, uint256 _voteQuorum, uint256 _action, uint256 _votedTokenAmount, uint256 _commitDuration) public returns (uint256 pollID) {
        require(hasRole(STAKER_ROLE, msg.sender));
        require (((_quorumOption == false && _voteQuorum == 0) || (_quorumOption == true && _voteQuorum > 0)), "Quorum must either be allowed with a vote quorum number or disabled without a vote quorum number");
        require (_votedTokenAmount > 0, "The amount of tokens to be burned/ minted must be larger than 0");
        uint256 end = block.timestamp.add(_commitDuration.mul(1 days));
        pollNonce = pollNonce.add(1);
        Poll storage newPoll = pollMapping[pollNonce];
        newPoll.pollStarter = msg.sender;
        newPoll.start = block.timestamp;
        newPoll.action = _action;
        newPoll.quorumOption = _quorumOption;
        newPoll.voteQuorum = _voteQuorum;
        newPoll.votedTokenAmount = _votedTokenAmount;
        newPoll.rewardsClaimed = false;
        newPoll.end = end;
        newPoll.votesFor = 0;
        newPoll.votesAgainst = 0;
        newPoll.ongoing = true;

        emit _PollCreated(_votedTokenAmount, end, pollNonce, msg.sender);
        return pollNonce;
    }

    /**
    @dev Allocates voter role to stakers and emits event
    @param voter address of staker
    */

    function voterAllocation(address voter) public {  //thi
        require(hasRole(STAKER_ROLE, voter)); 

        grantRole(VOTER_ROLE, voter);       
        emit _VotingRightsGranted(voter);
    }

    /**
    @dev Revokes votes that are already made and returns the vote to msg.sender //B: to msg.sender? this does not make sense... 
        //B: is this talking about after a vote is completed or the scenario where a staker unstakes?
    @param amount Amount of votes to be revoked
    @param pollID ID of poll
    */
    
    /* B: this revokeVote 彈弓手 function is problematic, as it allows for one to votepump and mislead strategic voters of the other party. 
        Consider this analogy: you have three candidates: Biden, Sanders, and Trump, and their support numbers are 40%, 25%, and 35%.
        A significant number of Biden supporters support Sanders as well, and they only vote for Biden because they believe Sanders just hasn't got a chance
        With this revokeVote set-up, Trump supports can pump up Sanders's vote, say to 40% - in which the support numbers would be 40%, 40%, 20%.
            Biden-Sanders supporters would then be essentially offered a chance to switch to Sanders, and have the candidate of their desire actually win. 
            Suppose 6% of Biden supporters switched to sanders, giving us: 34%, 46%, 20%. Then it would appear that Sanders is winning. 
            At the very last moment, suppose Trump supporters revoke their vote, we'd be left with 34%, 31%, 35%. Trump wins. 
    */

    /*function revokeVote(uint256 amount, uint256 pollID) public {
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
    */


    /**
    @dev Function that takes away voter role from addresses when necessary
    @param voter Voter that is going to get their role revoked
    */

    function voterRevokation(address voter) public {
        require(hasRole(VOTER_ROLE, voter)); //msg.sender change to voter
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

    function claimVote(uint256 pollID, address voter) public checkTime(pollID) voterCheck(voter) {  // msg.sender is usually for contracts, not addresses. So here, it is change(d) to voter
        require(voter != address(0));
        uint256 claimable = stakedTotal[voter].sub(pollMapping[pollID]._votesClaimed[voter]).sub(minStake - 1);
        require(claimable > 0, "Address has no votes available to claim");
        pollMapping[pollID]._votesClaimed[voter] = pollMapping[pollID]._votesClaimed[voter].add(claimable);
        pollMapping[pollID]._votes[voter] = pollMapping[pollID]._votes[voter].add(claimable);
        emit _VoteClaimed(voter, claimable);
    }

    function mint(address account, uint256 amount) onlyOwner public {
        _mint(account, amount);
        emit _Minted(account, amount);
    }

    /**
    @dev Returns number of votes available to users
    @param voter Address of requested voter
    @param pollID ID of poll
    */

    function numOfVotes(address voter, uint256 pollID) public checkTime(pollID) returns  (uint256 votes) {
        require(voter != address(0));
        return pollMapping[pollID]._votes[voter]; 
    }

    /**
    @dev Voters makes votes on corresponding polls, deducting their _votes and emitting _VoteMade event
    @param votesMade Amount of votes going to be made
    @param pollID ID of the poll
    @param side The side of the poll the user wants to support (1: for; 2: against)
    */


    function makeVote(uint256 votesMade, uint256 pollID, uint256 side, address voter) public checkTime(pollID) voterCheck(voter) {
        require(voter != address(0), "Must be a non-zero address");
        require(pollMapping[pollID].ongoing = true, "Must be an ongoing poll");
        require(pollMapping[pollID]._votes[voter] > 0, "Address has no votes currently, call function claimVote to claim a vote");
        require(votesMade <= pollMapping[pollID]._votes[voter], "You do not have enough votes to do this action");
        require(pollMapping[pollID]._side[voter] == 0 || pollMapping[pollID]._side[voter] == side, "You have voted for another side before");
        require(side == 1 || side == 2, "Invalid side");
        if (side == 1) {
            pollMapping[pollID].votesFor = pollMapping[pollID].votesFor.add(1);
        } else if (side == 2) {
            pollMapping[pollID].votesAgainst = pollMapping[pollID].votesAgainst.add(1);
        }
        pollMapping[pollID]._side[voter] = side;
        pollMapping[pollID]._votes[voter] = pollMapping[pollID]._votes[voter].sub(votesMade);
        totalVotes[pollID] = totalVotes[pollID].add(1);
        pollMapping[pollID]._participant[voter] = true;
        emit _VoteMade(pollID, votesMade, voter, side); 
    }

    /**
    @dev Returns whether the poll/ proposal passed the voting
    @param pollID ID of the poll
    */
    // ties are understood as rejections

    function results(uint256 pollID) public checkTime(pollID) returns (bool passed) {
        endPoll(pollID);
        require(isNotExpired(pollID) == false);
        require(pollExists(pollID));
        if (pollMapping[pollID].quorumOption == false) {
            if (pollMapping[pollID].votesFor > pollMapping[pollID].votesAgainst) {
                return (true);
            } else if (pollMapping[pollID].votesFor < pollMapping[pollID].votesAgainst) {
                return (false);
            } else {
                return (false);
            }
        } else if (pollMapping[pollID].quorumOption == true) {
            if (quorumCalc(pollID) >= pollMapping[pollID].voteQuorum) {
                return (true);
            } else if (quorumCalc(pollID) < pollMapping[pollID].voteQuorum) {
                return  (false);
            } else {
                return (false);
            }
        }
    }

    /**
    @dev Calculates the percentage of voters that supports the proposal
    @param pollID ID of the poll
    */

    function quorumCalc(uint256 pollID) public checkTime(pollID) returns  (uint256 result) {
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

    function endPoll(uint pollID) onlyOwner checkTime(pollID) public {
        require(pollExists(pollID));
        pollMapping[pollID].ongoing = false;
    }

    /**
    @dev can be called by other claim mint, burn or transaction functions
    @param pollID ID of the poll
    */
    

    function _claimRewards(uint256 pollID) checkTime(pollID) public {
      require(pollMapping[pollID].rewardsClaimed == false, "Rewards already claimed");
      pollMapping[pollID].rewardsClaimed = true;
    }

    /**
    @dev Mints the proposed amount of tokens after the poll has ended and passed
    @param pollID ID of the poll
    */
        

    function mintRewards (uint256 pollID) checkTime(pollID) onlyOwner payable public {
        _claimRewards(pollID);
        require(pollMapping[pollID].action == 1);
        require(pollMapping[pollID].ongoing == false);
        _beforeTokenTransfer(address(0), msg.sender, pollMapping[pollID].votedTokenAmount);
        _mint(msg.sender, pollMapping[pollID].votedTokenAmount);
        emit _ResultsGenerated(pollMapping[pollID].votedTokenAmount, pollID);  
    }

    /**
    @dev Burns the proposed amount of tokens after the poll has ended and passed
    @param pollID ID of the poll
    */

    function burnRewards (uint256 pollID) checkTime(pollID) onlyOwner payable public { 
        _claimRewards(pollID);
        require(pollMapping[pollID].action == 2);
        require(pollMapping[pollID].ongoing == false);
        _beforeTokenTransfer(msg.sender, address(0), pollMapping[pollID].votedTokenAmount);
        burnFrom(msg.sender, pollMapping[pollID].votedTokenAmount);
        emit _ResultsGenerated(pollMapping[pollID].votedTokenAmount, pollID);
    }


    function transferRewards(uint256 pollID, address recipient) checkTime(pollID) onlyOwner public virtual {
        _claimRewards(pollID);
        require(pollMapping[pollID].action == 3);
        require(pollMapping[pollID].ongoing == false);
        _beforeTokenTransfer(msg.sender, address(0), pollMapping[pollID].votedTokenAmount);
        burn(pollMapping[pollID].votedTokenAmount);
        _transfer(_msgSender(), recipient, pollMapping[pollID].votedTokenAmount);
        
        emit _ResultsGenerated(pollMapping[pollID].votedTokenAmount, pollID);
    }

    function takeSnapshot(uint256 pollID) onlyOwner public virtual {
        require(pollMapping[pollID].action == 4);
        require(pollMapping[pollID].ongoing == false);
        snapshot();        
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

        return isNotExpired(pollMapping[_pollID].end);
    }

    /**
    @dev Checks if a date has expired or not
    @param _terminationDate The date for checking
    */

    function isNotExpired(uint256 _terminationDate) public view returns (bool expired) {
        return (block.timestamp < _terminationDate);
    }
}

