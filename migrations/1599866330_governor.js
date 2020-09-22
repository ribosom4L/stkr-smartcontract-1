const GovernorContract = artifacts.require('Governance')

module.exports = async (_deployer) => {
  await _deployer.deploy(GovernorContract)
};
