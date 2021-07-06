// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./MaiGeneration.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract HeyStake is Mai {
    using SafeMath for uint256;

    event _StakerGranted(address to);
    event _StakerRoleRevoked(address account, uint256 amountReturned);
    event _StakesDeposited(address account, uint256 amount);
    event _StakesWithdrawn(address account, uint256 amount);

    mapping(address => uint256) stakedBalance; // Maps user address to the total amount of staked tokens

    /**
    @dev Allows users to stake, adding their respective amount of tokens to the staked balance
    @param amount Amount of tokens used in the stake pool
    */

    function stake(uint256 amount) payable public {
        require(amount >= 1000, "Must have a staked balance of more than 1000 MAI to become a staker");
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
        require(stakedBalance[msg.sender].sub(amount) >= 1000, "A balance of higher than 1000 is required to maintain role of staker, if you wish to revoke the role of staker, use revokeStaker() function");
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
        transferFrom(msg.sender, stakingAddress, amount);
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
}


