const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const Config = artifacts.require("Config");

const FETH = artifacts.require("FETH");
const FETH_R1 = artifacts.require("FETH_R1");

const GlobalPool = artifacts.require("GlobalPool");
const GlobalPool_R29 = artifacts.require("GlobalPool_R29");


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
  let pool = await GlobalPool.deployed();
  const poolUpgraded = await upgradeProxy(pool.address, GlobalPool_R29, { deployer });

  let feth = await FETH.deployed();
  const upgraded = await upgradeProxy(feth.address, FETH_R1, { deployer });

  await upgraded.setOwnership();
  await upgraded.setBalanceRatio(web3.utils.toWei("1"), "0");
  console.log("pool ratio", Number(await poolUpgraded.mintBase()))
  console.log("feth ratio", Number(await upgraded.ratio()))
  await upgraded.setBscBridgeContract(bscBridge);
};