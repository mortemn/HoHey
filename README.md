# MaiContract  
### Contract 1: Mai Generation  
This contract contains 2 main functionalities. 1: to generate MAI token; 2: to allow users to set up polls for other users to vote on. The polls can be about minting tokens, burning tokens etc.  
The contract is still under constant development, and the polls currently only allow for users to vote for minting purposes.  
Voting: When polls are created, users are allowed to vote for their corresponding stance using their votes. Users with 1000 or more tokens are given votes according to how many MAI tokens they have. The number of votes of a user is incremented by 1 on each addition unit of MAI token they have after the initial requirement of 1000 tokens.  
For example, of a user has 1000 MAI tokens, they would have 1 vote for every poll. If a user has 1500 MAI tokens, they would have 501 votes for every poll.  
####Basic Functions  
`startPoll(uint256 _voteQuorum, uint256 _commitDuration) public returns (uint256 pollID)`  
Users are able to start a poll, by passing in the vote quorum and commit duration as paramiters.  
`claimVote(address voter, uint256 pollID)`  
Users are require to claim their votes first in order to get votes.  
`numOfVotes(address voter, uint256 pollID) public view returns (uint256 votes)`  
Checks how many available votes a user has in a specific poll.  
`makeVote(address voter, uint256 votesMade, uint256 pollID, uint256 side) public whenNotPaused voterCheck(voter)`   
User makes vote, passing in their address, the amount of votes they want to make, the ID of the poll and their side.  
####To-do  
1. Add additional options for polls  
2. Increase or decrease amount of votes depending on transactions  
3. Edit function keywords (public, private, etc.)  
4. Allow for users to takeback their vote  
5. Security check and testing  
6. deployment  

