const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const Config = artifacts.require("Config");

const AETH = artifacts.require("AETH");
const AETH_R5 = artifacts.require("AETH_R5");

module.exports = async function(deployer, accounts) {
  const existing = await AETH.deployed();
  const instance = await upgradeProxy(existing.address, AETH_R5, { deployer });
};
