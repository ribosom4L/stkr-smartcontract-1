const StakingContract = artifacts.require('Staking')
const Provider = artifacts.require('Provider')
const MicropoolContract = artifacts.require('MicroPool')
const ANKRContract = artifacts.require('ANKR')
const NodeContract = artifacts.require('Node')

module.exports = async (_deployer) => {
  const stakingContract = await StakingContract.deployed()


  const deployed = await _deployer.deploy(Provider, stakingContract.address)
  const providerContract = await Provider.deployed()
  stakingContract.updateProviderContract(providerContract.address)
  const ankrContract = await ANKRContract.deployed()
  const nodeContract = await NodeContract.deployed()
  const micropoolContract = await MicropoolContract.deployed()

  console.log({
    ankrContract: ankrContract.address,
    nodeContract: nodeContract.address,
    micropoolContract: micropoolContract.address,
    providerContract: providerContract.address,
    stakingContract: stakingContract.address
  })
}
