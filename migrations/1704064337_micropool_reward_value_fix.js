const MicroPool        = artifacts.require("MicroPool");
const MicroPoolV2      = artifacts.require("MicroPoolV2");
const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");


module.exports = async (deployer) => {
  const deployed = await MicroPool.deployed();

  await upgradeProxy(deployed.address, MicroPoolV2, { deployer, unsafeAllowCustomTypes: true });
};
