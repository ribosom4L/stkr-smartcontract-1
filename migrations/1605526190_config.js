const Config      = artifacts.require("Config");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");
const GlobalPool_R1 = artifacts.require('GlobalPool_R1')
const GlobalPool = artifacts.require('GlobalPool')

module.exports = async (deployer) => {
  const configContract = await deployProxy(Config, [], { deployer });

  const instance = new web3.eth.Contract(GlobalPool_R1.abi, GlobalPool.address)
  await instance.methods.updateConfigContract(configContract.address)
};
