const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const Config      = artifacts.require("Config");

const GlobalPool = artifacts.require('GlobalPool');
const GlobalPool_R16 = artifacts.require('GlobalPool_R16');

module.exports = async function (deployer, accounts) {
  const existing = await GlobalPool.deployed();
  const instance = await upgradeProxy(existing.address, GlobalPool_R16, { deployer });
  // open claiming aeth
  await instance.togglePause(web3.utils.fromAscii('claim'))
};