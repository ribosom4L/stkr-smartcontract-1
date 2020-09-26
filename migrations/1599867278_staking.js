const StakingContract = artifacts.require('Staking')
const MicropoolContract = artifacts.require('MicroPool')
const ANKRContract = artifacts.require('ANKR')
const NodeContract = artifacts.require('Node')

module.exports = async (_deployer) => {
  const ankrContract = await ANKRContract.deployed()
  const micropoolContract = await MicropoolContract.deployed()
  await _deployer.deploy(StakingContract, ankrContract.address, micropoolContract.address)
}
