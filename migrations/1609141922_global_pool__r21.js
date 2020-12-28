const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const Config = artifacts.require("Config");

const GlobalPool = artifacts.require("GlobalPool");
const GlobalPool_R21 = artifacts.require("GlobalPool_R21");

module.exports = async function(deployer, accounts) {
  const existing = await GlobalPool.deployed();
  const instance = await upgradeProxy(existing.address, GlobalPool_R21, { deployer });
};
