const MaiContract = artifacts.require("Mai");

contract("MaiToken", () => {
  it("Should deploy smart contract properly", async () => {
    MaiContract.deployed()
      .then((instance) => instance.getBalance.call(accounts[0]))
      .then((balance) => {
        assert.equal(
          balance.valueOf(),
          10000,
          "10000 wasn't in the first account"
        );
      });
  });
});
