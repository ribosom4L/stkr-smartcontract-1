const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const GlobalPool = artifacts.require('GlobalPool');
const GlobalPool_R12 = artifacts.require('GlobalPool_R12');

module.exports = async function (deployer) {
  const existing = await GlobalPool.deployed();
  const instance = await upgradeProxy(existing.address, GlobalPool_R12, { deployer });
  // await instance.togglePause(web3.utils.fromAscii('claim'))
  // await instance.togglePause(web3.utils.fromAscii('topUpETH'))
};