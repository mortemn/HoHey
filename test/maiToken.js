const MaiContract = artifacts.require("Mai");

contract("MaiToken", () => {
  var tokenPrice = 1000000000;
  var tokensAvailable = 750000;
  it("Should deploy smart contract properly", async () => {
    const maiToken = MaiContract.deployed();
      .then(instance => instance.getBalance.call(accounts[0])
      .then(balance => {
        assert.equal(
          balance.valueOf(),
          10000,
          "10000 wasn't in the first account"
        );
  });
});
