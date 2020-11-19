const StkrPool        = artifacts.require("GlobalPool");
const TokenContract    = artifacts.require("AETH");
const SystemParameters = artifacts.require("SystemParameters");
const DepositContract  = artifacts.require("DepositContract");

const { deployProxy } = require("@openzeppelin/truffle-upgrades");

module.exports = async (deployer) => {
  const tokenContract = await TokenContract.deployed();
  const parameters    = await SystemParameters.deployed();

  let beaconAddr;

  switch (deployer.network) {
    case 'ganache': {}
    case 'test': {}
    case 'develop': {
      beaconAddr = (await deployer.deploy(DepositContract)).address
      break;
    }
    case 'goerli': {
      beaconAddr = "0x8c5fecdc472e27bc447696f431e425d02dd46a8c"
      break;
    }
    case 'mainnet': {
      beaconAddr = "0x00000000219ab540356cBB839Cbe05303d7705Fa"
      break;
    }
    default: {
      beaconAddr = (await deployer.deploy(DepositContract)).address
    }
  }

  const stkrPool = await deployProxy(
    StkrPool,
    [tokenContract.address, parameters.address, beaconAddr],
    { deployer }
  );

  await tokenContract.updateGlobalPoolContract(stkrPool.address);
};