const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const Config = artifacts.require("Config");

const AETH = artifacts.require("AETH");
const AETH_R7 = artifacts.require("AETH_R7");

module.exports = async function(deployer, accounts) {
  const existing = await AETH.deployed();
  const ins = await upgradeProxy(existing.address, AETH_R7, { deployer });
  await ins.setNewNameAndSymbol()
};
