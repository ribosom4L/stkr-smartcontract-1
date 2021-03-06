const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const Config      = artifacts.require("Config");

const AETH = artifacts.require('AETH');
const AETH_R2 = artifacts.require('AETH_R2');

module.exports = async function (deployer, accounts) {
  if (deployer.network === 'mainnet') return;

  const existing = await AETH.deployed();
  const instance = await upgradeProxy(existing.address, AETH_R2, { deployer });
  await instance.changeSymbolAndName("ankrETH", "Ankr Ethereum")
};
