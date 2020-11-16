const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const AETH = artifacts.require('AETH');
const AETH_R1 = artifacts.require('AETH_R1');

module.exports = async function (deployer) {
  const existing = await AETH.deployed();
  await upgradeProxy(existing.address, AETH_R1, { deployer });
};