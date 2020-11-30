const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const Config = artifacts.require("Config");

const AETH = artifacts.require("AETH");
const AETH_R3 = artifacts.require("AETH_R3");

module.exports = async function(deployer, accounts) {
  const existing = await AETH.deployed();
  const instance = await upgradeProxy(existing.address, AETH_R3, { deployer });
  if (deployer.network === "mainnet")

    await instance.changeSymbolAndName("ankrETH", "Ankr ETH");
};
