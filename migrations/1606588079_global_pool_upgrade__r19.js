const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const Config      = artifacts.require("Config");

const GlobalPool = artifacts.require('GlobalPool');
const GlobalPool_R19 = artifacts.require('GlobalPool_R19');

module.exports = async function (deployer, accounts) {
  if (deployer.network === 'mainnet') return;

  const existing = await GlobalPool.deployed();
  const instance = await upgradeProxy(existing.address, GlobalPool_R19, { deployer });
};