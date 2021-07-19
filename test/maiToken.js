const MaiContract = artifacts.require("Mai");

contract("MaiToken", async (accounts) => {
  it("Should deploy token", async () => {
    const instance = await MaiContract.deployed();
    console.log(instance.address);
    assert(instance !== "");
  });
  it("Should put 10000 Mai tokens in first account with aync await", async () => {
    const instance = await MaiContract.deployed();
    const balance = await instance.getBalance.call(accounts[0]);
    assert.equal(balance.valueOf(), 100000, "10000 wasn't in first account");
  });
  it("Should put 10000 Mai tokens in first account with promises", async () => {
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
