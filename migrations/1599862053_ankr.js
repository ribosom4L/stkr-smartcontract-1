const ANKRContract = artifacts.require('ANKR')

module.exports = async (_deployer) => {
  //TODO: Ether addr
  await _deployer.deploy(ANKRContract)
}
