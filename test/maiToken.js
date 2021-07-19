const MaiContract = artifacts.require("Mai");

contract("MaiToken", async (accounts) => {
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
});
