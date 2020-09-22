const StakingContract = artifacts.require('Staking')
const MicropoolContract = artifacts.require('MicroPool')
const ANKRContract = artifacts.require('ANKR')
const NodeContract = artifacts.require('Node')

module.exports = async (_deployer) => {
  const ankrContract = await ANKRContract.deployed()
  const nodeContract = await NodeContract.deployed()
  const micropoolContract = await MicropoolContract.deployed()
  await _deployer.deploy(StakingContract, ankrContract.address, nodeContract.address, micropoolContract.address)
  const stakingContract = await StakingContract.deployed();

  nodeContract.updateStakingContract(stakingContract.address)
}
