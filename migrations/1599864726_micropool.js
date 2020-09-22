const Micropool = artifacts.require('Micropool')
const TokenContract = artifacts.require('AETH')

module.exports = async (_deployer) => {
  const tokenContract = await TokenContract.deployed()
  await _deployer.deploy(Micropool, tokenContract.address)
};
