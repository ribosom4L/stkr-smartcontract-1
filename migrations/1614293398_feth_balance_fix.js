const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const Config = artifacts.require("Config");

const FETH = artifacts.require("FETH");
const FETH_R1 = artifacts.require("FETH_R1");

const GlobalPool = artifacts.require("GlobalPool");
const GlobalPool_R28 = artifacts.require("GlobalPool_R28");


module.exports = async function(deployer, accounts) {
  let existing = await FETH.deployed();
  await upgradeProxy(existing.address, FETH_R1, { deployer });

  existing = await GlobalPool.deployed()
  await upgradeProxy(existing.address, GlobalPool_R28, { deployer });
};