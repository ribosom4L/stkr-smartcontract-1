const fs = require("fs");
const path = require("path");
const helpers = require("./helpers/helpers");
const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const GlobalPool = artifacts.require("GlobalPool");
const Config = artifacts.require("Config");
const GlobalPool_R23 = artifacts.require("GlobalPool_R23");
const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");

const AEth = artifacts.require("AETH");

contract("2020 11 16 Upgrade Global Pool", function(accounts) {
  let poolOld;
  let pool;
  let config;

  before(async function() {
    config = await Config.deployed();
    poolOld = await GlobalPool.deployed();
    pool = await upgradeProxy(poolOld.address, GlobalPool_R23);
    pool.updateConfigContract(config.address);

    const data = fs.readFileSync(path.join(__dirname, "/helpers/depositdata"), "utf8")
      .slice(8);

    depositData =
      web3.eth.abi.decodeParameters(["bytes", "bytes", "bytes", "bytes32"], data);

    owner = accounts[0];

    for (let i = 0; i < 300; i++) {
      await helpers.advanceBlock();
    }
  });

  it("should providers enabled for eth top up", async () => {
    await expectRevert(pool.topUpETH(), "Value must be greater than minimum amount");
  });

  it("should providers cannot deposit lower than minimum amount", async () => {
    await expectRevert(pool.topUpETH(), "Value must be greater than minimum amount");
  });

  it("should calculate pending stake amounts correctly", async () => {
    await pool.stake({
      from: accounts[0],
      value: helpers.wei(3)
    });

    await pool.stake({
      from: accounts[1],
      value: helpers.wei(7)
    });

    await pool.stake({
      from: accounts[0],
      value: helpers.wei(7)
    });

    await pool.stake({
      from: accounts[3],
      value: helpers.wei(13)
    });

    assert.equal(Number(await pool.pendingStakesOf(accounts[3])), helpers.wei(13));
    assert.equal(Number(await pool.pendingStakesOf(accounts[1])), helpers.wei(7));
    assert.equal(Number(await pool.pendingStakesOf(accounts[0])), helpers.wei(10));
  });

  it("should calculate pending provider stake amounts correctly", async () => {
    await pool.topUpETH({
      from: accounts[0],
      value: helpers.wei(3)
    });

    await pool.topUpETH({
      from: accounts[1],
      value: helpers.wei(7)
    });

    await pool.topUpETH({
      from: accounts[0],
      value: helpers.wei(7)
    });

    await pool.topUpETH({
      from: accounts[3],
      value: helpers.wei(13)
    });

    assert.equal(Number(await pool.pendingStakesOf(accounts[3])), helpers.wei(13 * 2));
    assert.equal(Number(await pool.pendingStakesOf(accounts[1])), helpers.wei(7 * 2));
    assert.equal(Number(await pool.pendingStakesOf(accounts[0])), helpers.wei(10 * 2));
  });

  it("should distribute amounts correctly with provider staking", async () => {

    const tx = await helpers.pushToBeacon(pool);

    assert.equal(Number(await pool.pendingStakesOf(accounts[0])), 0);

    assert.equal(Number(await pool.pendingStakesOf(accounts[1])), helpers.wei(2));

    assert.equal(Number(await pool.pendingStakesOf(accounts[3])), helpers.wei(26));

    assert.equal(Number(await pool.pendingEtherBalanceOf(accounts[3])), helpers.wei(13));

    assert.equal(Number(await pool.pendingEtherBalanceOf(accounts[1])), helpers.wei(0));
  });

  it("should providers cannot stake or unstake after exit for x block count", async () => {
    await pool.providerExit({from: accounts[0]})
    await helpers.advanceBlocks(21);

    await expectRevert(pool.stake({ from: accounts[0], value: helpers.wei(2) }), "Recently exited")

    await expectRevert(pool.unstake({ from: accounts[0] }), "Recently exited")
  });

  it("should providers able to unstake after exit approved", async () => {
    await helpers.advanceBlocks(30);
    const tx = await pool.unstake({ from: accounts[3] })
  });

  it("should send deposit", async () => {

    await pool.stake({
      from: accounts[0],
      value: helpers.wei(23)
    });

    await pool.stake({
      from: accounts[9],
      value: helpers.wei(10)
    });

    let tx = await helpers.pushToBeacon(pool);

    await pool.stake({
      from: accounts[0],
      value: helpers.wei(3)
    });

    await pool.stake({
      from: accounts[1],
      value: helpers.wei(7)
    });

    await pool.stake({
      from: accounts[2],
      value: helpers.wei(7)
    });

    await pool.stake({
      from: accounts[3],
      value: helpers.wei(3)
    });

    await pool.stake({
      from: accounts[4],
      value: helpers.wei(3)
    });

    await pool.stake({
      from: accounts[5],
      value: helpers.wei(7)
    });

    await pool.stake({
      from: accounts[6],
      value: helpers.wei(1)
    });

    tx = await helpers.pushToBeacon(pool);

    await pool.stake({
      from: accounts[0],
      value: helpers.wei(23)
    });

    await pool.stake({
      from: accounts[9],
      value: helpers.wei(9)
    });

    tx = await helpers.pushToBeacon(pool);

    await pool.stake({
      from: accounts[0],
      value: helpers.wei(23)
    });

    await pool.stake({
      from: accounts[9],
      value: helpers.wei(13)
    });

    tx = await helpers.pushToBeacon(pool);


    await pool.stake({
      from: accounts[7],
      value: helpers.wei(23)
    });

    await pool.stake({
      from: accounts[8],
      value: helpers.wei(23)
    });

    await pool.stake({
      from: accounts[9],
      value: helpers.wei(13)
    });

    tx = await helpers.pushToBeacon(pool);
  });

  it('should clear pending stakers without errors', async () => {
    await pool.clearEmptyPendingStakers()
  })
});