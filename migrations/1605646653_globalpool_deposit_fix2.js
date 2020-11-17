const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const GlobalPool = artifacts.require('GlobalPool');
const GlobalPool_R15 = artifacts.require('GlobalPool_R15');

module.exports = async function (deployer) {
  const existing = await GlobalPool.deployed();
  const instance = await upgradeProxy(existing.address, GlobalPool_R15, { deployer });
};