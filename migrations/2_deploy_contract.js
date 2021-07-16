const maiContract = artifacts.require("Mai");

module.exports = function (deployer) {
  deployer.deploy(maiContract);
};
