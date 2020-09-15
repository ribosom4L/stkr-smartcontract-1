const StakingContract = artifacts.require('Staking')
const NodeContract = artifacts.require('Node')

module.exports = async (_deployer) => {
  await _deployer.deploy(NodeContract)
}
