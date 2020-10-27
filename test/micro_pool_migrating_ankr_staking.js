const fs                            = require("fs");
const path                          = require("path");
const helpers                       = require("./helpers/helpers");
const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");

const MicroPool        = artifacts.require("MicroPool");
const Staking          = artifacts.require("Staking");
const AEth             = artifacts.require("AETH");
const MarketPlace      = artifacts.require("MarketPlace");
const Ankr             = artifacts.require("Ankr");
const SystemParameters = artifacts.require("SystemParameters");

contract("MicroPool Migrating (ANKR Staking)", function(accounts) {
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
    ankr             = await Ankr.deployed();
    staking          = await Staking.deployed();
    micropool        = await MicroPool.deployed();
    systemParameters = await SystemParameters.deployed();
    marketPlace      = await MarketPlace.deployed();
    aeth             = await AEth.deployed();

    await fundMarketPlaceContract(helpers.amount(10), accounts[5]);

    providerMinimumStaking = helpers.amount(100000);

    ankrEth = 50000;
    ethUsd  = 300;

    // 1 eth 300 usd
    await marketPlace.updateEthUsdRate(ethUsd);
    // 1 eth 50k ankr
    await marketPlace.updateAnkrEthRate(ankrEth);

    const data = fs.readFileSync(path.join(__dirname, "/helpers/depositdata"), "utf8")
      .slice(8);

    depositData =
      web3.eth.abi.decodeParameters(["bytes", "bytes", "bytes", "bytes32"], data);

    owner = accounts[0];

    await ankr.approve(staking.address, providerMinimumStaking);

    poolName = helpers.makeHex("Test pool");

    await micropool.initializePool(poolName);

    oldProvider = owner;

    await micropool.stake(1, {
      value: helpers.amount(12),
      from:  accounts[2]
    });

    await micropool.stake(1, {
      value: helpers.amount(10),
      from:  accounts[3]
    });

    await micropool.stake(1, {
      value: helpers.amount(5),
      from:  accounts[4]
    });

    await micropool.stake(1, {
      value: helpers.amount(5),
      from:  accounts[5]
    });

    await micropool.pushToBeacon(
      1,
      depositData[0],
      depositData[1],
      depositData[2],
      depositData[3]
    );
  });

  describe("Positive Provider Balance Migration", async () => {
    it("Should Migrate Without Errors", async () => {
      currentPoolBalance    = helpers.amount(49);
      currentSlashingAmount = helpers.amount(1.6);

      let newProvider = accounts[9];

      await migrate(newProvider, currentPoolBalance, currentSlashingAmount);
    });

    it("new provider's available balance should be frozen", async () => {
      // because this is a positive balance migration, old provider should have same
      // total staking amount as before
      assert.equal(Number(newProviderStakeAmountAfterMigration.available), 0);
    });

    it("old provider's frozen balance should be unfrozen after migration", async () => {
      // because this is a positive balance migration, old provider should have same
      // total staking amount as before
      assert.equal(
        oldProviderStakeAmountBeforeMigration.frozen - providerMinimumStaking,
        0
      );
    });

    it(
      "old provider's available balance should be equal to old total balance",
      async () => {
        // because this is a positive balance migration, old provider should have same
        // total staking amount as before
        assert.equal(
          Number(oldProviderStakeAmountAfterMigration.available),
          Number(oldProviderStakeAmountBeforeMigration.frozen) + Number(
          oldProviderStakeAmountBeforeMigration.available)
        );
      }
    );

    it("old provider should get positive balance as frozen aeth", async () => {
      assert.equal(Number(oldProviderFrozenAethBalanceBeforeMigration), 0);
      assert.equal(
        Number(oldProviderFrozenAethBalanceAfterMigration),
        260000000000000000
      );
    });
  });

  describe("Negative Provider Balance Migration", async () => {
    it("Should Migrate Without Errors", async () => {
      currentPoolBalance    = helpers.amount(49);
      currentSlashingAmount = helpers.amount(3.2);

      let newProvider = accounts[8];

      await migrate(newProvider, currentPoolBalance, currentSlashingAmount);
    });

    it("new provider's available balance should be frozen", async () => {
      // because this is a positive balance migration, old provider should have same
      // total staking amount as before
      assert.equal(Number(newProviderStakeAmountAfterMigration.available), 0);
    });

    it("old provider's frozen balance should be unfrozen after migration", async () => {
      // because this is a positive balance migration, old provider should have same
      // total staking amount as before
      assert.equal(
        0,
        oldProviderStakeAmountBeforeMigration.frozen - providerMinimumStaking
      );
    });

    // it(
    //   "old provider's available balance should be equal to (old total - compensated balance)",
    //   async () => {
    //     // because this is a positive balance migration, old provider should have same
    //     // total staking amount as before
    //     const poolMigratedEvent = tx.logs[0].args;
    //     const compensated       = poolMigratedEvent.compensated;
    //     const oldTotal          = oldProviderStakeAmountBeforeMigration.frozen.add(
    //       oldProviderStakeAmountBeforeMigration.available);
    //     const newTotal          = oldProviderStakeAmountAfterMigration.frozen.add(
    //       oldProviderStakeAmountAfterMigration.available);
    //
    //     assert.equal(Number(newTotal), Number(oldTotal.sub(compensated)));
    //   }
    // );

    // TODO: We should test burned aeth
    // it("compensated aeth should be burned", async () => {
    //
    // });
  });

  const migrate = async (newProvider, currentPoolBalance, currentSlashingAmount) => {
    await ankr.approve(staking.address, providerMinimumStaking, { from: newProvider });
    // and allowance

    newProviderStakeAmountBeforeMigration = await staking._stakes(newProvider);
    oldProviderStakeAmountBeforeMigration = await staking._stakes(oldProvider);

    oldProviderFrozenAethBalanceBeforeMigration = await aeth.frozenBalanceOf(oldProvider);

    tx =
      await micropool.migrate(
        1,
        currentPoolBalance,
        currentSlashingAmount,
        newProvider,
        { from: accounts[0] }
      );

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
