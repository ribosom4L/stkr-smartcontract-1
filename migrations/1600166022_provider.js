const Provider = artifacts.require('Provider')
const StakingContract = artifacts.require('Staking')

module.exports = async (_deployer) => {
  await _deployer.deploy(Provider, StakingContract.address)
  const providerContract = await Provider.deployed()
  const stakingContract = await StakingContract.deployed();

  stakingContract.updateProviderContract(providerContract.address)
}
