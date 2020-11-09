const StakingContract   = artifacts.require("Staking");
const StkrPool = artifacts.require("GlobalPool");
const ANKRContract      = artifacts.require("ANKR");
const TokenContract     = artifacts.require("AETH");

const { deployProxy } = require("@openzeppelin/truffle-upgrades");


module.exports = async (deployer) => {
  const tokenContract     = await TokenContract.deployed();
  const stkrPoolContract = await StkrPool.deployed();

  let ankrAddr;

  switch (deployer.network) {
    case 'mainnet': {
      ankrAddr = "0x8290333cef9e6d528dd5618fb97a76f268f3edd4"
      break;
    }
    default: {
      ankrAddr = (await deployer.deploy(ANKRContract)).address
    }
  }

  const stakingContract = await deployProxy(
    StakingContract,
    [ankrAddr, stkrPoolContract.address, tokenContract.address],
    { deployer }
  );

  await stkrPoolContract.updateStakingContract(stakingContract.address);
};
