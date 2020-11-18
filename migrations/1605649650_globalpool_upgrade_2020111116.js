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

  await instance.updateConfigContract(configContract.address)
  await instance.changeOperator("0x4069D8A3dE3A72EcA86CA5e0a4B94619085E7362")
};