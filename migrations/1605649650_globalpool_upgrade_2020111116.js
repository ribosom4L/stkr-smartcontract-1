const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const Config      = artifacts.require("Config");

const GlobalPool = artifacts.require('GlobalPool');
const GlobalPool_R16 = artifacts.require('GlobalPool_R16');

module.exports = async function (deployer, accounts) {
  const existing = await GlobalPool.deployed();
  const instance = await upgradeProxy(existing.address, GlobalPool_R16, { deployer });
  await instance.togglePause(web3.utils.fromAscii('claim'))
  await instance.togglePause(web3.utils.fromAscii('topUpETH'))
  const configContract = await Config.deployed()
  // await instance.changeOperator(accounts[0])
  await instance.updateConfigContract(configContract.address)
};