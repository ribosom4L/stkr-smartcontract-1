const GovernorContract = artifacts.require('AETH')

module.exports = async (_deployer) => {
  await _deployer.deploy(GovernorContract)
};
