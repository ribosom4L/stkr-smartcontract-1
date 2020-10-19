const fs = require("fs");
const path = require("path");
const helpers = require("./helpers/helpers");
const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");

const MicroPool = artifacts.require("MicroPool");
const Staking = artifacts.require("Staking");
const AEth = artifacts.require("AETH");
const MarketPlace = artifacts.require("MarketPlace");
const Ankr = artifacts.require("Ankr");
const SystemParameters = artifacts.require("SystemParameters");

contract("MicroPool Migrating", function(accounts) {
  let ankr;
  let staking;
  let micropool;
  let owner;
  let systemParameters;
  let marketPlace;
  let aeth;

  let tx;

  let currentPoolBalance;
  let currentSlashingAmount;

  let newProviderStakeAmountBeforeMigration;
  let oldProviderStakeAmountBeforeMigration;
  let newProviderStakeAmountAfterMigration;
  let oldProviderStakeAmountAfterMigration;
  let oldProviderFrozenAethBalanceBeforeMigration;
  let oldProviderFrozenAethBalanceAfterMigration;

  let providerMinimumStaking;
  let depositData;

  let oldProvider;

  let ethUsd;
  let ankrEth;

  let poolName;

  before(async function() {
    ankr = await Ankr.deployed();
    staking = await Staking.deployed();
    micropool = await MicroPool.deployed();
    systemParameters = await SystemParameters.deployed();
    marketPlace = await MarketPlace.deployed();
    aeth = await AEth.deployed();

    await fundMarketPlaceContract(helpers.amount(10), accounts[5]);

    providerMinimumStaking = helpers.amount(100000);

    ankrEth = 50000;
    ethUsd = 300;

    // 1 eth 300 usd
    await marketPlace.updateEthUsdRate(ethUsd);
    // 1 eth 50k ankr
    await marketPlace.updateAnkrEthRate(ankrEth);

    const data = fs.readFileSync(path.join(__dirname, "/helpers/depositdata"), "utf8").slice(8);

    depositData = web3.eth.abi.decodeParameters(["bytes", "bytes", "bytes", "bytes32"], data);

    owner = accounts[0];

    await ankr.approve(staking.address, providerMinimumStaking);

    poolName = helpers.makeHex("Test pool");

    await micropool.initializePool(poolName);

    oldProvider = owner;

    await micropool.stake(1, {
      value: helpers.amount(12),
      from: accounts[2]
    });

    await micropool.stake(1, {
      value: helpers.amount(10),
      from: accounts[3]
    });

    await micropool.stake(1, {
      value: helpers.amount(5),
      from: accounts[4]
    });

    await micropool.stake(1, {
      value: helpers.amount(5),
      from: accounts[5]
    });

    await micropool.pushToBeacon(1, depositData[0], depositData[1], depositData[2], depositData[3]);

    currentPoolBalance = helpers.amount(34);
    currentSlashingAmount = helpers.amount(1.1);

    await migrate(accounts[9], currentPoolBalance, currentSlashingAmount);

    currentPoolBalance = helpers.amount(35);
    currentSlashingAmount = helpers.amount(2.2);

    await migrate(accounts[8], currentPoolBalance, currentSlashingAmount);
  });

  

  const migrate = async (newProvider, currentPoolBalance, currentSlashingAmount) => {
    await ankr.approve(staking.address, providerMinimumStaking, { from: newProvider });
    // and allowance

    newProviderStakeAmountBeforeMigration = await staking._stakes(newProvider);
    oldProviderStakeAmountBeforeMigration = await staking._stakes(oldProvider);

    oldProviderFrozenAethBalanceBeforeMigration = await aeth.frozenBalanceOf(oldProvider);

    tx = await micropool.migrate(1, currentPoolBalance, currentSlashingAmount, newProvider, { from: accounts[0] });

    await expectEvent(tx, "PoolMigrated");

    newProviderStakeAmountAfterMigration = await staking._stakes(newProvider);
    oldProviderStakeAmountAfterMigration = await staking._stakes(oldProvider);

    oldProviderFrozenAethBalanceAfterMigration = await aeth.frozenBalanceOf(oldProvider);

    oldProvider = newProvider;
  };

  const fundMarketPlaceContract = async (amount, from) => {
    // first, we need to get some aeth
    await aeth.send(amount, { from });

    await aeth.transfer(marketPlace.address, amount, { from });
  };
});
