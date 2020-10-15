const ANKRContract = artifacts.require('ANKR')

module.exports = async (deployer) => {
  await deployer.deploy(ANKRContract)
}
