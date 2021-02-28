const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const Config = artifacts.require("Config");

const FETH = artifacts.require("FETH");
const FETH_R2 = artifacts.require("FETH_R2");

const GlobalPool = artifacts.require("GlobalPool");
const GlobalPool_R29 = artifacts.require("GlobalPool_R29");


module.exports = async function(deployer, network, accounts) {

  let feth = await FETH.deployed();
  const upgraded = await upgradeProxy(feth.address, FETH_R2, { deployer });
};