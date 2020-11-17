const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const GlobalPool = artifacts.require('GlobalPool');
const GlobalPool_R16 = artifacts.require('GlobalPool_R16');

module.exports = async function (deployer, accounts) {
  const existing = await GlobalPool.deployed();
  const instance = await upgradeProxy(existing.address, GlobalPool_R16, { deployer });
  // await instance.changeOperator(accounts[0])
};