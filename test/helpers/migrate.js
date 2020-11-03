const MicroPool        = artifacts.require("MicroPool");
const Staking          = artifacts.require("Staking");
const AEth             = artifacts.require("AETH");
const MarketPlace      = artifacts.require("MarketPlace");
const Ankr             = artifacts.require("Ankr");
const SystemParameters = artifacts.require("SystemParameters");
const DepositContract  = artifacts.require("DepositContract");

const helpers = require("./helpers");

module.exports = async (owner) => {
  const systemParameters = await SystemParameters.new({ from: owner });
  await systemParameters.initialize();
  const ankr = await Ankr.new({ from: owner });

  const aeth = await AEth.new({ from: owner });
  await aeth.initialize(helpers.makeHex("AEthereum"), helpers.makeHex("aEth"));

  // -- micropool migrations
  const depositContract = await DepositContract.new({ from: owner });

  const micropool = await MicroPool.new(
    aeth.address,
    systemParameters.address,
    depositContract.address,
    { from: owner }
  );
  await micropool.initialize(
    aeth.address,
    systemParameters.address,
    depositContract.address
  );

  await aeth.updateMicroPoolContract(micropool.address);

  // -- staking migrations
  const staking = await Staking.new({ from: owner });
  await staking.initialize(ankr.address, micropool.address, aeth.address);

  await micropool.updateStakingContract(staking.address, { from: owner });
  // END -- staking migrations

  const marketPlace = await MarketPlace.new({ from: owner });
  await marketPlace.initialize(aeth.address);

  await staking.updateMarketPlaceContract(marketPlace.address, { from: owner });

  return {
    systemParameters, ankr, aeth, depositContract, micropool, staking, marketPlace
  };
};