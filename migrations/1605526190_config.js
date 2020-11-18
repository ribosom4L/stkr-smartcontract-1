const Config      = artifacts.require("Config");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");
const GlobalPool_R1 = artifacts.require('GlobalPool_R1')
const GlobalPool = artifacts.require('GlobalPool')

module.exports = async (deployer) => {
  await deployProxy(Config, [], { deployer });
};
