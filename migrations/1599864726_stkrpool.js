const StkrPool        = artifacts.require("StkrPool");
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
    case 'local': {}
    case 'develop': {
      beaconAddr = (await deployer.deploy(DepositContract)).address
      break;
    }
    case 'goerli': {
      beaconAddr = "0x07b39F4fDE4A38bACe212b546dAc87C58DfE3fDC"
      break;
    }
    case 'mainnet': {
      beaconAddr = "0x00000000219ab540356cBB839Cbe05303d7705Fa"
      break;
    }
    default: {
      throw new Error('Unknown network: ' + deployer.network)
    }
  }

  const stkrPool = await deployProxy(
    StkrPool,
    [tokenContract.address, parameters.address, beaconAddr],
    { deployer }
  );

  await tokenContract.updateStkrPoolContract(stkrPool.address);
};