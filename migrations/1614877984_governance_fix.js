const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const Config = artifacts.require("Config");

const Governance = artifacts.require("Governance");
const Governance_R1 = artifacts.require("Governance_R1");

module.exports = async function(deployer, accounts) {
  const existing = await Governance.deployed();
  await upgradeProxy(existing.address, Governance_R1, { deployer });
};
