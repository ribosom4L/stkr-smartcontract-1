const fs = require("fs");
const path = require("path");
const helpers = require("./helpers/helpers");
const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const GlobalPool = artifacts.require("GlobalPool");
const Config = artifacts.require("Config");
const GlobalPool_R18 = artifacts.require("GlobalPool_R18");
const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");

const AEth = artifacts.require("AETH");

contract("2020 11 30 Upgrade Global Pool", function(accounts) {
  let poolOld;
  let pool;
  let config;

  before(async function() {
    config = await Config.deployed();
    poolOld = await GlobalPool.deployed();
    pool = await upgradeProxy(poolOld.address, GlobalPool_R18);

    const data = fs.readFileSync(path.join(__dirname, "/helpers/depositdata"), "utf8")
      .slice(8);

    depositData =
      web3.eth.abi.decodeParameters(["bytes", "bytes", "bytes", "bytes32"], data);

    owner = accounts[0];

    for (let i = 0; i < 300; i++) {
      await helpers.advanceBlock();
    }
  });

  it("should calculate pending provider stake amounts correctly", async () => {
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

    await pool.topUpETH({
      from: accounts[3],
      value: helpers.wei(13)
    });

    await pool.stake({
      from: accounts[3],
      value: helpers.wei(2)
    });


    assert.equal(Number(await pool.pendingStakesOf(accounts[1])), helpers.wei(7));
    assert.equal(Number(await pool.pendingStakesOf(accounts[2])), helpers.wei(7));
    assert.equal(Number(await pool.pendingStakesOf(accounts[3])), helpers.wei(15));

    await helpers.pushToBeacon(pool);

    assert.equal(Number(await pool.claimableRewardOf(accounts[1])), helpers.wei(7));
    assert.equal(Number(await pool.claimableRewardOf(accounts[2])), helpers.wei(7));
    assert.equal(Number(await pool.claimableRewardOf(accounts[3])), helpers.wei(2));

    await pool.stake({
      from: accounts[3],
      value: helpers.wei(30)
    });

    await pool.topUpETH({
      from: accounts[3],
      value: helpers.wei(8)
    });

    await pool.stake({
      from: accounts[5],
      value: helpers.wei(20)
    });

    await pool.topUpETH({
      from: accounts[5],
      value: helpers.wei(6)
    });

    await helpers.pushToBeacon(pool);
    await helpers.pushToBeacon(pool);

    assert.equal(Number(await pool.claimableRewardOf(accounts[3])), helpers.wei(32));
    assert.equal(Number(await pool.claimableRewardOf(accounts[5])), helpers.wei(20));

  });
});