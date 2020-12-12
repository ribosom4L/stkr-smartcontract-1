const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const Config = artifacts.require("Config");

const AETH = artifacts.require("AETH");
const AETH_R4 = artifacts.require("AETH_R4");

module.exports = async function(deployer, accounts) {
  const existing = await AETH.deployed();
  const instance = await upgradeProxy(existing.address, AETH_R4, { deployer });
  await instance.changeOperator("0x4069D8A3dE3A72EcA86CA5e0a4B94619085E7362")
};
