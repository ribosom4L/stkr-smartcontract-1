const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const Config = artifacts.require("Config");

const AETH = artifacts.require("AETH");
const AETH_R8 = artifacts.require("AETH_R8");

module.exports = async function(deployer, accounts) {
  const existing = await AETH.deployed();
  const ins = await upgradeProxy(existing.address, AETH_R8, { deployer });

  ins.togglePause(web3.utils.fromAscii("transfer"))
};