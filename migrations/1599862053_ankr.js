const ANKRContract = artifacts.require('ANKR')

module.exports = async (_deployer) => {
  //TODO: Ether addr
  await _deployer.deploy(ANKRContract, "0x3B6BDC2fC41774800dbb4daF34Dd9FA6a4d9FdDa")
}
