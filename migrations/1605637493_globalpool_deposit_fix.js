const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const GlobalPool = artifacts.require('GlobalPool');
const GlobalPool_R13 = artifacts.require('GlobalPool_R13');

module.exports = async function (deployer) {
  const existing = await GlobalPool.deployed();
  const instance = await upgradeProxy(existing.address, GlobalPool_R13, { deployer });
};