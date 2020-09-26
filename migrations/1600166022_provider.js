const StakingContract = artifacts.require('Staking')
const Provider = artifacts.require('Provider')
const MicropoolContract = artifacts.require('MicroPool')
const ANKRContract = artifacts.require('ANKR')
const GovernanceContract = artifacts.require('Governance')
const AETHContract = artifacts.require('AETH')

module.exports = async (_deployer) => {
  const stakingContract = await StakingContract.deployed()

  const micropoolContract = await MicropoolContract.deployed()

  await _deployer.deploy(Provider, stakingContract.address, micropoolContract.address)

  const providerContract = await Provider.deployed()
  stakingContract.updateProviderContract(providerContract.address)
  const ankrContract = await ANKRContract.deployed()
  const governanceContract = await GovernanceContract.deployed()
  const tokenContract = await AETHContract.deployed()

  console.log({
    ankrContract: ankrContract.address,
    micropoolContract: micropoolContract.address,
    providerContract: providerContract.address,
    stakingContract: stakingContract.address,
    governanceContract: governanceContract.address,
    AETHContract: tokenContract.address
  })
}
