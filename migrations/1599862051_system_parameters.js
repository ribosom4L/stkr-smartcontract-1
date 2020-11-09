const parameters      = artifacts.require("SystemParameters");
const { deployProxy } = require("@openzeppelin/truffle-upgrades");


module.exports = async (deployer) => {
  await deployProxy(parameters, [], { deployer });
};
