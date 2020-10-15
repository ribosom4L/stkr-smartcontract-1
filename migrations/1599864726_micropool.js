const Micropool = artifacts.require('Micropool')
const TokenContract = artifacts.require('AETH')
const SystemParameters = artifacts.require('SystemParameters')

const { deployProxy } = require('@openzeppelin/truffle-upgrades')

module.exports = async (deployer) => {
  const tokenContract = await TokenContract.deployed()
  const parameters = await SystemParameters.deployed()
  console.log("here", tokenContract)
  // TODO: env
  const beaconAddr = '0x07b39F4fDE4A38bACe212b546dAc87C58DfE3fDC'

  const micropool = await deployProxy(Micropool, [tokenContract.address, parameters.address, beaconAddr], {
    deployer,
    // TODO: structs to mappings
    unsafeAllowCustomTypes: true
  })

  await tokenContract.updateMicroPoolContract(micropool.address)

}
