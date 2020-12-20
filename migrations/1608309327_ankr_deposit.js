const Ankr = artifacts.require("ANKR")
const AnkrDeposit = artifacts.require("AnkrDeposit")
const AETH = artifacts.require("AETH")
const Config = artifacts.require("Config")
const GlobalPool = artifacts.require("GlobalPool")
const GlobalPool_R21 = artifacts.require("GlobalPool_R21")

const { deployProxy, upgradeProxy } = require("@openzeppelin/truffle-upgrades");

module.exports = async (_deployer) => {
  if (_deployer.network !== "mainnet") {
    await _deployer.deploy(Ankr)
  }
  const ankr = await Ankr.deployed()
  let pool = await GlobalPool.deployed()
  const aeth = await AETH.deployed()
  const ankrDeposit = await deployProxy(AnkrDeposit, [ankr.address, pool.address, aeth.address])
  pool = await upgradeProxy(pool.address, GlobalPool_R21, { deployer: _deployer });
  await pool.updateStakingContract(ankrDeposit.address)

  await pool.togglePause(web3.utils.fromAscii('topUpANKR'))

};
