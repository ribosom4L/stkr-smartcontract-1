const Micropool = artifacts.require('Micropool')
const TokenContract = artifacts.require('AETH')

module.exports = async (_deployer) => {
  await _deployer.deploy(Micropool, TokenContract.address)
};
