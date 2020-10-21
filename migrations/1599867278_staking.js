const StakingContract   = artifacts.require("Staking");
const MicropoolContract = artifacts.require("MicroPool");
const ANKRContract      = artifacts.require("ANKR");
const TokenContract     = artifacts.require("AETH");

const { deployProxy } = require("@openzeppelin/truffle-upgrades");


module.exports = async (deployer) => {
  const ankrContract      = await ANKRContract.deployed();
  const tokenContract     = await TokenContract.deployed();
  const micropoolContract = await MicropoolContract.deployed();

  const stakingContract = await deployProxy(
    StakingContract,
    [ankrContract.address, micropoolContract.address, tokenContract.address],
    {
      deployer,
      unsafeAllowCustomTypes: true
    }
  );

  await micropoolContract.updateStakingContract(stakingContract.address);
};
