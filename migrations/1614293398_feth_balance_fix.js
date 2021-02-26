const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const Config = artifacts.require("Config");

const FETH = artifacts.require("FETH");
const FETH_R1 = artifacts.require("FETH_R1");

const GlobalPool = artifacts.require("GlobalPool");
const GlobalPool_R28 = artifacts.require("GlobalPool_R28");


module.exports = async function(deployer, network, accounts) {
  let bscBridge = '';
  switch (deployer.network) {
    case 'ganache': {
      bscBridge = "0xa5bAb2Ea2822FB70b22F5a5bd28Bd2722dA1b754"
    }
    case 'test': {
      bscBridge = "0xa5bAb2Ea2822FB70b22F5a5bd28Bd2722dA1b754"
    }
    case 'goerli': {
      bscBridge = "0xa5bAb2Ea2822FB70b22F5a5bd28Bd2722dA1b754"
      break;
    }
    case 'mainnet': {
      bscBridge = ""
      break;
    }
  }
  let existing = await GlobalPool.deployed();
  let upgraded = await upgradeProxy(existing.address, GlobalPool_R28, { deployer });

  existing = await FETH.deployed();
  upgraded = await upgradeProxy(existing.address, FETH_R1, { deployer });

  await upgraded.setOwnership();
  await upgraded.setBalanceRatio(web3.utils.toWei("1"));
  await upgraded.setBscBridgeContract(bscBridge)
};