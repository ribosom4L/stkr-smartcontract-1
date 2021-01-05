const Ankr = artifacts.require("ANKR")
const AnkrDeposit = artifacts.require("AnkrDeposit")
const Governance = artifacts.require("Governance")
const AETH = artifacts.require("AETH")
const Config = artifacts.require("Config")
const GlobalPool = artifacts.require("GlobalPool")
const GlobalPool_R21 = artifacts.require("GlobalPool_R21")

const { deployProxy, upgradeProxy, prepareUpgrade } = require("@openzeppelin/truffle-upgrades");

module.exports = async (_deployer) => {
  let ankrAddress;
  if (_deployer.network !== "mainnet") {
    await _deployer.deploy(Ankr)
    ankrAddress = (await Ankr.deployed()).address
  }
  else {
    ankrAddress = "0x8290333ceF9e6D528dD5618Fb97a76f268f3EDD4"
  }

  let pool = await GlobalPool.deployed()
  pool = await upgradeProxy(pool.address, GlobalPool_R21)

  const aeth = await AETH.deployed()

  if (Boolean(await pool.isPaused(web3.utils.fromAscii('topUpANKR'))))
    await pool.togglePause(web3.utils.fromAscii('topUpANKR'))

  const governance = await deployProxy(Governance, [ankrAddress, pool.address, aeth.address])
  await pool.updateConfigContract(governance.address)
  await pool.updateStakingContract(governance.address)

  await governance.changeOperator("0x4069D8A3dE3A72EcA86CA5e0a4B94619085E7362")
};
