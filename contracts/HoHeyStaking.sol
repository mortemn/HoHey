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

    mapping(address => uint256) stakedBalance;

    function stake(uint256 amount) payable public {
        require(amount >= 1000, "Must have a staked balance of more than 1000 MAI to become a staker");
        require(hasRole(STAKER_ROLE, msg.sender) == false, "You are already a staker");
        transferFrom(msg.sender, stakingAddress, amount);
        grantRole(STAKER_ROLE, msg.sender);
        stakedBalance[msg.sender] = stakedBalance[msg.sender].add(amount);
        emit _StakerGranted(msg.sender);
    }

    function withdraw(uint256 amount) payable public {
        require(hasRole(STAKER_ROLE, msg.sender), "Must have staker role to perform this action");
        require(amount <= stakedBalance[msg.sender], "Must withdraw amount within balance"); 
        require(stakedBalance[msg.sender].sub(amount) >= 1000, "A balance of higher than 1000 is required to maintain role of staker, if you wish to revoke the role of staker, use revokeStaker() function");
        require(checkParticipation() == false, "You must not be participating in any vote in order to withdraw any staked tokens");
        transfer(msg.sender, amount);
        stakedBalance[msg.sender] = stakedBalance[msg.sender].sub(amount);
        emit _StakesWithdrawn(msg.sender, amount);
    }

    function deposit(uint256 amount) payable public {
        require(hasRole(STAKER_ROLE, msg.sender), "Must have staker role to perform this action");
        transferFrom(msg.sender, stakingAddress, amount);
        stakedBalance[msg.sender] = stakedBalance[msg.sender].add(amount);
        emit _StakesDeposited(msg.sender, amount);
    }

    function viewStakedBalance() view public returns (uint256 balance) {
        require(hasRole(STAKER_ROLE, msg.sender), "Must have staker role to perform this action");
        return (stakedBalance[msg.sender]);
    }
    
    function revokeStaker() public {
        require(hasRole(STAKER_ROLE, msg.sender), "Must have staker role to perform this action");
        revokeRole(STAKER_ROLE, msg.sender);
        transfer(msg.sender, stakedBalance[msg.sender]);
        stakedBalance[msg.sender] = 0;
        emit _StakerRoleRevoked(msg.sender, stakedBalance[msg.sender]); 
    }
}


