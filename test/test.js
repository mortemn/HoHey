const { accounts, contract, web3 } = require("@openzeppelin/test-environment");
const { expect } = require("chai");
require("chai").should();
const MaiContract = contract.fromArtifact("Mai");
const {
  BN, // Big Number support
  constants, // Common constants, like the zero address and largest integers
  expectEvent, // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
  time,
} = require("@openzeppelin/test-helpers");
const DEFAULT_ADMIN_ROLE =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const STAKER_ROLE = web3.utils.soliditySha3("STAKER_ROLE");
const OWNER_ROLE = web3.utils.soliditySha3("OWNER_ROLE");
const PAUSER_ROLE = web3.utils.soliditySha3("PAUSER_ROLE");
const SNAPSHOT_ROLE = web3.utils.soliditySha3("SNAPSHOT_ROLE");
const VOTER_ROLE = web3.utils.soliditySha3("VOTER_ROLE");

describe("mai contract testing", function () {
  describe("transactions", function () {
    const [owner, sender, receiver] = accounts;
    beforeEach(async function () {
      this.value = new BN(1);
      this.mai = await MaiContract.new({ from: owner });
    });
    it("should revert when transferring tokens to the zero address", async function () {
      await expectRevert(
        this.mai.transfer(constants.ZERO_ADDRESS, this.value, { from: sender }),
        "ERC20: transfer to the zero address"
      );
    });
    it("should emit a Transfer event on successful transfers", async function () {
      const receipt = await this.mai.transfer(receiver, this.value, {
        from: owner,
      });
      expectEvent(receipt, "Transfer", {
        from: owner,
        to: receiver,
        value: this.value,
      });
    });
    it("should update balances on successful transfers (big numbers)", async function () {
      this.mai.transfer(receiver, this.value, { from: owner });

      // BN assertions are automatically available via chai-bn (if using Chai)
      expect(await this.mai.balanceOf(receiver)).to.be.bignumber.equal(
        this.value
      );
    });
  });
  describe("minting", function () {
    const [owner, sender, receiver] = accounts;
    beforeEach(async function () {
      this.value = new BN(1);
      this.mai = await MaiContract.new({ from: owner });
    });
    const amount = new BN(50);
    it("should revert when minting to a zero address", async function () {
      await expectRevert(
        this.mai.mint(constants.ZERO_ADDRESS, amount, { from: owner }),
        "ERC20: mint to the zero address"
      );
    });

    describe("should work for a non zero account", function () {
      beforeEach("minting", async function () {
        const receipt = await this.mai.mint(receiver, amount, {
          from: owner,
        });
        this.receipt = receipt;
      });
      it("should increment receiver balance", async function () {
        expect(await this.mai.balanceOf(receiver)).to.be.bignumber.equal(
          amount
        );
      });

      it("should emit transfer event", async function () {
        const event = expectEvent(this.receipt, "Transfer", {
          from: constants.ZERO_ADDRESS,
          to: receiver,
        });

        expect(event.args.value).to.be.bignumber.equal(amount);
      });
    });
  });
  describe("polls", function () {
    const [owner, sender, receiver, staking] = accounts;
    beforeEach(async function () {
      this.value = new BN(1);
      this.mai = await MaiContract.new({ from: owner });
      this.receipt = await this.mai.startPoll(false, 0, 1, 1000, 5, {
        from: owner,
      });
      await this.mai.setStakingAddress(staking, { from: owner });
    });
    const amount = new BN(50);
    it("should start a poll", async function () {
      expectEvent(this.receipt, "_PollCreated", {
        votedTokenAmount: "1000",
        pollID: "1",
        creator: owner,
      });
    });
    it("should increment and start another poll", async function () {
      const receipt = await this.mai.startPoll(false, 0, 1, 1000, 1000, {
        from: owner,
      });
      expectEvent(receipt, "_PollCreated", {
        pollID: "2",
      });
    });
    it("should input 0 votedTokenAmount", async function () {
      await expectRevert(
        this.mai.startPoll(false, 0, 1, 0, 1000, { from: owner }),
        "The amount of tokens to be burned/ minted must be larger than 0"
      );
    });
    it("should pass in true quorum option with voteQuorum equal to 1", async function () {
      await expectRevert(
        this.mai.startPoll(true, 0, 1, 1000, 1000, { from: owner }),
        "Quorum must either be allowed with a vote quorum number or disabled without a vote quorum number"
      );
    });
    it("should pass in false quorum option with voteQuorum larger than 1", async function () {
      await expectRevert.unspecified(
        this.mai.startPoll(false, 60, 1, 1000, 1000, { from: owner })
      );
    });
    it("owner should have a staker role", async function () {
      await this.mai.hasRole(STAKER_ROLE, owner);
    });
    it("should be able to allocate voter", async function () {
      await this.mai.voterAllocation(owner, { from: owner });
      await expect(await this.mai.hasRole(VOTER_ROLE, owner)).equal(true);
    });
    it("should claim a vote", async function () {
      await this.mai.voterAllocation(owner, { from: owner });
      await this.mai.deposit(1001, { from: owner });
      await this.mai.claimVote(1, owner, { from: owner });
    });
    it("should make a vote", async function () {
      await this.mai.voterAllocation(owner, { from: owner });
      await this.mai.deposit(2000, { from: owner });
      await this.mai.claimVote(1, owner, { from: owner });
      await this.mai.makeVote(1, 1, 1, owner, { from: owner });
    });
    it("should be able to mint rewards", async function () {
      await this.mai.voterAllocation(owner, { from: owner });
      await this.mai.deposit(2000, { from: owner });
      await this.mai.claimVote(1, owner, { from: owner });
      await this.mai.makeVote(1, 1, 1, owner, { from: owner });
      await time.increase(5);
      await this.mai.mintRewards(1, { from: owner });
    });
    it("should only be able to claim reward once", async function () {
      await this.mai.voterAllocation(owner, { from: owner });
      await this.mai.deposit(1001, { from: owner });
      await this.mai.claimVote(1, owner);
      await this.mai.makeVote(1, 1, 1, owner, { from: owner });
      await time.increase(5);
      await this.mai.mintRewards(1, { from: owner });
      await expectRevert(
        this.mai.mintRewards(1, { from: owner }),
        "Rewards already claimed"
      );
    });
  });
  describe("roles", function () {
    const [owner, sender, receiver] = accounts;
    beforeEach(async function () {
      this.value = new BN(1);
      this.mai = await MaiContract.new({ from: owner });
    });
    it("deployer should have default admin role", async function () {
      await expect(await this.mai.hasRole(DEFAULT_ADMIN_ROLE, owner)).to.equal(
        true
      );
    });
    it("owner should have every role", async function () {
      await expect(await this.mai.hasRole(DEFAULT_ADMIN_ROLE, owner)).to.equal(
        true
      );
      await expect(await this.mai.hasRole(STAKER_ROLE, owner)).equal(true);
      await expect(await this.mai.hasRole(PAUSER_ROLE, owner)).equal(true);
      await expect(await this.mai.hasRole(OWNER_ROLE, owner)).equal(true);
      await expect(await this.mai.hasRole(SNAPSHOT_ROLE, owner)).equal(true);
    });
  });
  describe("staking", function () {
    const [owner, sender, receiver, staking] = accounts;
    beforeEach(async function () {
      this.value = new BN(1);
      this.mai = await MaiContract.new({ from: owner });
      this.receipt = await this.mai.startPoll(false, 0, 1, 1000, 5, {
        from: owner,
      });
      await this.mai.setStakingAddress(staking, { from: owner });
    });
    const amount = new BN(50);
    it("should deposit 50 tokens to staking address", async function () {
      const stakeReceipt = await this.mai.deposit(amount, { from: owner });
      await expectEvent(stakeReceipt, "_StakesDeposited", {
        account: owner,
        amount: amount,
      });
      await expect(
        await this.mai.viewStakedBalance({ from: owner })
      ).to.be.bignumber.equal(amount);
      await expect(
        await this.mai.viewStakedTotal({ from: owner })
      ).to.be.bignumber.equal(amount);
    });
  });
});
