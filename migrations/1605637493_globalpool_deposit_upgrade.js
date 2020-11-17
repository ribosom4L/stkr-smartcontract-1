const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const GlobalPool = artifacts.require('GlobalPool');
const GlobalPool_R14 = artifacts.require('GlobalPool_R14');

module.exports = async function (deployer) {
  const existing = await GlobalPool.deployed();
  const instance = await upgradeProxy(existing.address, GlobalPool_R14, { deployer });
};