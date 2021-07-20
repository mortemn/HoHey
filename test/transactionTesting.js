const { accounts, contract } = require("@openzeppelin/test-environment");

const {
  BN, // Big Number support
  constants, // Common constants, like the zero address and largest integers
  expectEvent, // Assertions for emitted events
  expectRevert, // Assertions for transactions that should fail
} = require("@openzeppelin/test-helpers");

const MaiContract = contract.fromArtifact("Mai");

describe("Transactions", function () {
  const [sender, receiver] = accounts;
  beforeEach(async function () {
    // The bundled BN library is the same one web3 uses under the hood
    this.value = new BN(1);

    this.erc20 = await MaiContract.new();
  });
  it("Should deploy token", async () => {
    const instance = await MaiContract.deployed();
    console.log(instance.address);
    assert(instance !== "");
  });
  it("Should send 10 tokens", async () => {
    MaiContract.deployed()
      .then(async (instance) => {
        const balance = await instance.balanceOf(
          "0x7b7e056cca92a7a6f464e171c096646cce71914b"
        );
      })
      .catch((err) => {
        console.log("Error: " + err);
      });
  });
  it("emits a Transfer event on successful transfers", async function () {
    const receipt = await this.erc20.transfer(receiver, this.value, {
      from: sender,
    });

    // Event assertions can verify that the arguments are the expected ones
    expectEvent(receipt, "Transfer", {
      from: sender,
      to: receiver,
      value: this.value,
    });
  });
  it("Should deploy token", async () => {
    const instance = await MaiContract.deployed();
    console.log(instance.address);
    assert(instance !== "");
  });
  it("Should start poll", async () => {
    const instance = await MaiContract.deployed();
    const pollID = await instance.startPoll(false, 0, 1, 10000, 10000);
  });
  it("Should start poll with quorum", async () => {
    const instance = await MaiContract.deployed();
    const pollID = await instance.startPoll(true, 60, 1, 10000, 10000);
  });
  it("the deployer is the owner", async function () {
    expect(await this.myContract.owner()).to.equal(owner);
  });
});
