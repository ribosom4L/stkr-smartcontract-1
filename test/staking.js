const Staking = artifacts.require("Staking");
const Ankr    = artifacts.require("Ankr");

const helpers = require("./helpers/helpers");

contract("Staking", function(accounts) {
  let ankr;
  let staking;
  let owner;
  beforeEach(async function() {
    ankr    = await Ankr.deployed();
    staking = await Staking.deployed();
    owner   = accounts[0];
  });

  it("allow users to stake ankr", async () => {
    assert.equal(Number(await staking.totalStakesOf(owner)), 0);

    await ankr.faucet();

    const amount = helpers.amount(100000);

    await ankr.approve(staking.address, amount);

    await staking.claimAnkrAndStake(owner);

    assert.equal(Number(await staking.totalStakesOf(owner)), amount);
  });

  it("allow users to ustake ankr", async () => {
    await staking.unstake();

    assert.equal(Number(await staking.totalStakesOf(owner)), 0);
  });
});
