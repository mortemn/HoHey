const { accounts, contract, web3 } = require("@openzeppelin/test-environment");
const { expect } = require("chai");
require("chai").should();
const MaiContract = contract.fromArtifact("Mai");

describe("MaiContract", function () {
  const [owner, recipient] = accounts;
  beforeEach(async function () {
    this.mai = await MaiContract.new({ from: owner });
  });
  it("should deploy token", async function () {
    const instance = await this.mai.transfer(recipient, 1000, { from: owner });
    console.log(instance);
  });
});
