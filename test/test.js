const { accounts, contract, web3 } = require("@openzeppelin/test-environment");
const { expect } = require("chai");
require("chai").should();
const MaiContract = contract.fromArtifact("Mai");
const {
  BN, // Big Number support
  constants, // Common constants, like the zero address and largest integers
  expectEvent, // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
} = require("@openzeppelin/test-helpers");

describe("mai contract testing", function () {
  describe("transactions", function () {
    const [owner, sender, receiver] = accounts;
    beforeEach(async function () {
      this.value = new BN(1);
      this.mai = await MaiContract.new({ from: owner });
    });
    it("reverts when transferring tokens to the zero address", async function () {
      await expectRevert(
        this.mai.transfer(constants.ZERO_ADDRESS, this.value, { from: sender }),
        "ERC20: transfer to the zero address"
      );
    });
    it("emits a Transfer event on successful transfers", async function () {
      const receipt = await this.mai.transfer(receiver, this.value, {
        from: owner,
      });
      expectEvent(receipt, "Transfer", {
        from: owner,
        to: receiver,
        value: this.value,
      });
    });
    it("updates balances on successful transfers", async function () {
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
    it("rejects a null account", async function () {
      await expectRevert(
        this.mai.mint(constants.ZERO_ADDRESS, amount, { from: owner }),
        "ERC20: mint to the zero address"
      );
    });

    describe("for a non zero account", function () {
      beforeEach("minting", async function () {
        const { logs } = await this.mai.mint(receiver, amount, {
          from: owner,
        });
        this.logs = logs;
      });
      it("increments receiver balance", async function () {
        expect(await this.mai.balanceOf(receiver)).to.be.bignumber.equal(
          amount
        );
      });

      it("emits Transfer event", async function () {
        const event = expectEvent.inLogs(this.logs, "Transfer", {
          from: constants.ZERO_ADDRESS,
          to: receiver,
        });

        expect(event.args.value).to.be.bignumber.equal(amount);
      });
    });
  });
});
