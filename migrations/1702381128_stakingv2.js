const Marketplace   = artifacts.require("MarketPlace");
const TokenContract = artifacts.require("AETH");
const Staking       = artifacts.require("Staking");
const StakingV2     = artifacts.require("StakingV2");

const { deployProxy, upgradeProxy, prepareUpgrade } = require("@openzeppelin/truffle-upgrades");

module.exports = async (deployer) => {
  // const staking = await Staking.deployed();
  //
  // const stakingv2 = await upgradeProxy(staking.address, StakingV2, { deployer, unsafeAllowCustomTypes: true });
  // console.log(stakingv2)
};
