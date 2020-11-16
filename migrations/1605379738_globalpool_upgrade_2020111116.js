const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const GlobalPool = artifacts.require('GlobalPool');
const GlobalPool_R1 = artifacts.require('GlobalPool_R1');

module.exports = async function (deployer) {
  const existing = await GlobalPool.deployed();
  const instance = await upgradeProxy(existing.address, GlobalPool_R1, { deployer });
  await instance.togglePause(web3.utils.fromAscii('claim'))
  await instance.togglePause(web3.utils.fromAscii('topUpETH'))
};