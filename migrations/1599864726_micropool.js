const Micropool = artifacts.require('Micropool')
const TokenContract = artifacts.require('AETH')
const SystemParameters = artifacts.require('SystemParameters')
const DepositContract = artifacts.require('DepositContract')

const { deployProxy } = require('@openzeppelin/truffle-upgrades')

module.exports = async (deployer) => {
  const tokenContract = await TokenContract.deployed()
  const parameters = await SystemParameters.deployed()

  let beaconAddr

  if (process.env.NETWORK === 'LOCAL') {
    await deployer.deploy(DepositContract)
    beaconAddr = (await DepositContract.deployed()).address
  } else {
    beaconAddr = process.env.DEPOSIT_CONTRACT
  }

  const micropool = await deployProxy(Micropool, [tokenContract.address, parameters.address, beaconAddr], {
    deployer,
    // TODO: Check the upgrades if structs fit our upgrades
    unsafeAllowCustomTypes: true
  })

  await tokenContract.updateMicroPoolContract(micropool.address)

}