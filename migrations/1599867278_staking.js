const StakingContract = artifacts.require('Staking')
const MicropoolContract = artifacts.require('MicroPool')
const ANKRContract = artifacts.require('ANKR')
const NodeContract = artifacts.require('Node')

module.exports = async (_deployer) => {
  await _deployer.deploy(StakingContract, ANKRContract.address, NodeContract.address, MicropoolContract.address)
  const stakingContract = StakingContract.deployed();
  const nodeContract = await NodeContract.deployed();

  nodeContract.updateStakingContract(stakingContract.address)
}
