const AETHF = artifacts.require("AETHF")
const GlobalPool = artifacts.require("GlobalPool")
const GlobalPool_R23 = artifacts.require("GlobalPool_R23")

const { deployProxy, upgradeProxy } = require("@openzeppelin/truffle-upgrades")

module.exports = async (deployer) => {
  const addr = "0x4069D8A3dE3A72EcA86CA5e0a4B94619085E7362";
  const globalPool = await GlobalPool.deployed()
  const feth = await deployProxy(AETHF, ["AETHF", "AETHFPool", globalPool.address, addr], { deployer })

  const globalPool_r23 = await upgradeProxy(globalPool.address, GlobalPool_R23, { deployer })

  await globalPool_r23.updateFETHContract(feth.address)
  await globalPool_r23.updateFETHRewards(0)
};
