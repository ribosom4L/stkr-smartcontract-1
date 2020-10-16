const ANKRContract = artifacts.require('ANKR')
const { deployProxy } = require('@openzeppelin/truffle-upgrades');


module.exports = async (deployer) => {
  await deployProxy(ANKRContract, [], { deployer })
}
