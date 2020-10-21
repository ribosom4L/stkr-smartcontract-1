const Marketplace = artifacts.require("MarketPlace");
const TokenContract = artifacts.require("AETH");
const Staking = artifacts.require("Staking");

const { deployProxy } = require("@openzeppelin/truffle-upgrades");

module.exports = async (deployer) => {

  const marketplaceProxy = await deployProxy(
    Marketplace,
    [((await TokenContract.deployed()).address)],
    { deployer }
  );

  await (await Staking.deployed()).updateMarketPlaceContract(marketplaceProxy.address);
};
