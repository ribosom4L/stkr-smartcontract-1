const parameters = artifacts.require('SystemParameters')

module.exports = async (_deployer) => {
  await _deployer.deploy(parameters)
}
