const TokenContract = artifacts.require("AETH");

const { deployProxy } = require("@openzeppelin/truffle-upgrades");

module.exports = async (deployer) => {
  await deployProxy(TokenContract, ["AEthereum", "aEth"], { deployer });
};
