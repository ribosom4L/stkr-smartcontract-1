const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const Config = artifacts.require("Config");

const GlobalPool = artifacts.require("GlobalPool");
const GlobalPool_R30 = artifacts.require("GlobalPool_R30");

module.exports = async function(deployer, accounts) {
  const existing = await GlobalPool.deployed();
  await upgradeProxy(existing.address, GlobalPool_R30, { deployer });
};
