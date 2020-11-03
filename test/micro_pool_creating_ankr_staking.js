const fs               = require("fs");
const path             = require("path");
const helpers          = require("./helpers/helpers");
const { expectRevert } = require("@openzeppelin/test-helpers");

const MicroPool        = artifacts.require("MicroPool");
const Staking          = artifacts.require("Staking");
const Ankr             = artifacts.require("Ankr");
const SystemParameters = artifacts.require("SystemParameters");

contract("MicroPool Creating and Staking (ANKR Staking)", function(accounts) {
  let ankr;
  let staking;
  let micropool;
  let owner;
  let systemParameters;
  let firstStaking;
  let depositData;

  before(async function() {
    ankr             = await Ankr.deployed();
    staking          = await Staking.deployed();
    micropool        = await MicroPool.deployed();
    systemParameters = await SystemParameters.deployed();

    const data = fs.readFileSync(path.join(__dirname, "/helpers/depositdata"), "utf8")
      .slice(8);

    depositData =
      web3.eth.abi.decodeParameters(["bytes", "bytes", "bytes", "bytes32"], data);

    owner = accounts[0];
  });

  it("should have 1 padding pool at the beginning", async () => {
    assert.equal(await micropool.poolCount(), 1);
  });

  it("allows users to create micro pool", async () => {
    const providerMinimumStaking = helpers.amount(100000);

    await ankr.approve(staking.address, providerMinimumStaking);

    const poolName = helpers.makeHex("Test pool");

    await micropool.initializePool(poolName);

    const pool = await micropool.poolDetails(1);

    assert.equal(poolName, pool.name);

    assert.equal(pool.provider, accounts[0]);
  });

  it("should revert insufficient stake amounts", async () => {
    await ankr.faucet({ from: accounts[1] });

    await ankr.approve(staking.address, helpers.amount(99999), { from: accounts[1] });

    await expectRevert(micropool.initializePool(
      helpers.makeHex("test"),
      { from: accounts[1] }
    ), "Staking: Insufficient funds");
  });

  it("should allow users to participate to pool", async () => {
    firstStaking = helpers.amount(1);

    await micropool.stake(1, {
      value: firstStaking,
      from:  accounts[1]
    });

    assert.equal(Number(await micropool.userStakeAmount(1, accounts[1])), firstStaking);
  });

  it("should revert if staking amount lower than minimum staking amount", async () => {

    const value = await systemParameters.REQUESTER_MINIMUM_POOL_STAKING() / 2;


    await expectRevert(micropool.stake(1, {
      value: "0x" + value.toString(16),
      from:  accounts[1]
    }), "Ethereum value must be greater than minimum staking amount");
  });

  it("should send exceed amount when pool balance is more than 32 ether", async () => {
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

    const value = helpers.amount(12);

    await micropool.stake(1, {
      value,
      from: accounts[2]
    });

    assert.equal(
      (value - firstStaking),
      Number(await micropool.userStakeAmount(1, accounts[2]))
    );
  });

  it("should be PushWaiting status after 32 ether sent", async () => {
    const pool = await micropool.poolDetails(1);
    assert.equal(Number(pool.status), 1);
  });

  it("staking requests should reverted after 32 ethereum stake", async () => {
    const value = helpers.amount(1);

    await expectRevert(micropool.stake(1, {
      value,
      from: accounts[3]
    }), "Cannot stake to this pool");
  });

  it("owner should be able to send push request", async () => {

    await expectRevert(micropool.pushToBeacon(
      1,
      depositData[0],
      depositData[1],
      depositData[2],
      depositData[3],
      { from: accounts[1] }
    ), "Ownable: caller is not the owner");

    await micropool.pushToBeacon(
      1,
      depositData[0],
      depositData[1],
      depositData[2],
      depositData[3]
    );

    const pool = await micropool.poolDetails(1);

    assert.equal(Number(pool.balance), 0);
  });

  it("should be OnGoing status after push", async () => {
    const pool = await micropool.poolDetails(1);
    assert.equal(Number(pool.status), 2);
  });

  it("push requests should be reverted after success push", async () => {
    await expectRevert(micropool.pushToBeacon(
      1,
      depositData[0],
      depositData[1],
      depositData[2],
      depositData[3]
    ), "Pool status not allow to push");
  });

  it("pool balance and reward should be correct after push", async () => {
    const pool = await micropool.poolDetails(1);

    assert.equal(Number(pool.balance), 0);
    assert.equal(Number(pool.lastReward), 0);
  });
});
