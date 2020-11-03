const fs                            = require("fs");
const path                          = require("path");
const helpers                       = require("./helpers/helpers");
const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");

const fakeMigration = require("./helpers/migrate");
const { BN }        = require("@openzeppelin/test-helpers");

contract("MicroPool Rewarding (ETH Staking)", function(accounts) {
  let contracts = {};

  let stakers;

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

  before(async () => {
    contracts = await fakeMigration(accounts[0]);
    await fundMarketPlaceContract(helpers.amount(10), accounts[5]);

    providerMinimumStaking = helpers.amount(100000);

    ankrEth = 50000;
    ethUsd  = 300;

    // 1 eth 300 usd
    await contracts.marketPlace.updateEthUsdRate(ethUsd);
    // 1 eth 50k ankr
    await contracts.marketPlace.updateAnkrEthRate(ankrEth);

    const data = fs.readFileSync(
      path.join(__dirname, "/helpers/depositdata"),
      "utf8"
    ).slice(8);

    depositData =
      web3.eth.abi.decodeParameters(
        ["bytes", "bytes", "bytes", "bytes32"],
        data
      );

    owner = accounts[0];

    await contracts.ankr.approve(
      contracts.staking.address,
      providerMinimumStaking
    );

    poolName = helpers.makeHex("Test pool");

    stakers = [
      {
        value: helpers.amount(12),
        from:  accounts[2]
      },
      {
        value: helpers.amount(10),
        from:  accounts[3]
      },
      {
        value: helpers.amount(5),
        from:  accounts[4]
      },
      {
        value: helpers.amount(5),
        from:  accounts[5]
      }
    ];

    await contracts.micropool.initializePool(poolName);

    oldProvider = owner;

    await contracts.micropool.stake(1, stakers[0]);

    await contracts.micropool.stake(1, stakers[1]);

    await contracts.micropool.stake(1, stakers[2]);

    await contracts.micropool.stake(1, stakers[3]);

    await contracts.micropool.pushToBeacon(1, depositData[0], depositData[1],
      depositData[2], depositData[3],
      { from: accounts[0] }
    );

    currentPoolBalance    = helpers.amount(34);
    currentSlashingAmount = helpers.amount(1.1);

    await migrate(accounts[9], currentPoolBalance, currentSlashingAmount);

    currentPoolBalance    = helpers.amount(35);
    currentSlashingAmount = helpers.amount(2.2);

    await migrate(accounts[8], currentPoolBalance, currentSlashingAmount);
  });

  it("should allow rewarding only to ongoing pools", async () => {

    await contracts.ankr.approve(contracts.staking.address,
      providerMinimumStaking, { from: accounts[1] }
    );

    poolName = helpers.makeHex("Some pool");

    await contracts.micropool.initializePool(poolName, { from: accounts[1] });

    await expectRevert(
      contracts.micropool.rewardMicropool(2, helpers.amount(3.4),
        { value: helpers.amount(38) }
      ),
      "Pool cannot be rewarded"
    );
  });

  it(
    "should revert if tx has lower slashing amount from current pool slashings",
    async () => {
      await expectRevert(
        contracts.micropool.rewardMicropool(1, helpers.amount(2.1),
          { value: helpers.amount(38) }
        ),
        "Current slashings cannot be smaller than last slashings"
      );
    }
  );

  it("should run without errors", async () => {
    oldProviderStakeAmountBeforeMigration =
      await contracts.staking._stakes(oldProvider);

    oldProviderFrozenAethBalanceBeforeMigration =
      await contracts.aeth.frozenBalanceOf(oldProvider);


    const tx = await contracts.micropool.rewardMicropool(1, helpers.amount(2.2),
      {
        value: helpers.amount(48)
      }
    );

    oldProviderStakeAmountAfterMigration =
      await contracts.staking._stakes(oldProvider);

    oldProviderFrozenAethBalanceAfterMigration =
      await contracts.aeth.frozenBalanceOf(oldProvider);
    await expectEvent(tx, "PoolReward");
  });

  it("provider should get correct reward amount", async () => {
    assert.equal(Number(oldProviderFrozenAethBalanceBeforeMigration), 0);
    assert.equal(
      Number(oldProviderFrozenAethBalanceAfterMigration),
      1300000000000000000
    );
  });

  it("requesters should be able to get correct amount", async () => {
    const poolDetails      = await contracts.micropool.poolDetails(1);
    const requesterRewards = Number(poolDetails.requesterRewards) + Number(helpers.amount(
      32));

    for (const staker of stakers) {
      const tx               = await contracts.micropool.claimAeth(
        1,
        { from: staker.from }
      );
      const claimAmount      = Number(tx.logs[0].args[2]);
      const stakerPercentage = staker.value / helpers.amount(32);
      assert.equal(claimAmount / requesterRewards, stakerPercentage);
    }
  });

  it("requesters should not be able to claim more than once", async () => {
    for (const staker of stakers) {
      await expectRevert(
        contracts.micropool.claimAeth(1, { from: staker.from }),
        "Claimable amount must be bigger than zero"
      );
    }
  });

  const migrate = async (newProvider, currentPoolBalance, currentSlashingAmount) => {
    await contracts.ankr.approve(contracts.staking.address,
      providerMinimumStaking, { from: newProvider }
    );
    // and allowance

    newProviderStakeAmountBeforeMigration =
      await contracts.staking._stakes(newProvider);
    oldProviderStakeAmountBeforeMigration =
      await contracts.staking._stakes(oldProvider);

    oldProviderFrozenAethBalanceBeforeMigration =
      await contracts.aeth.frozenBalanceOf(oldProvider);

    tx =
      await contracts.micropool.migrate(1, currentPoolBalance,
        currentSlashingAmount, newProvider,
        { from: accounts[0] }
      );

    await expectEvent(tx, "PoolMigrated");

    newProviderStakeAmountAfterMigration =
      await contracts.staking._stakes(newProvider);

    oldProviderStakeAmountAfterMigration =
      await contracts.staking._stakes(oldProvider);

    oldProviderFrozenAethBalanceAfterMigration =
      await contracts.aeth.frozenBalanceOf(oldProvider);

    oldProvider = newProvider;
  };

  const fundMarketPlaceContract = async (amount, from) => {
    // first, we need to get some aeth
    await contracts.aeth.send(amount, { from });

    await contracts.aeth.transfer(contracts.marketPlace.address, amount,
      { from }
    );
  };
});
