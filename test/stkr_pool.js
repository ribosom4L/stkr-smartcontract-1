const fs = require("fs");
const path = require("path");
const helpers = require("./helpers/helpers");
const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const StkrPool = artifacts.require("GlobalPool");
const AEth = artifacts.require("AETH");

contract("Stkr Pool", function(accounts) {
  let pool;
  let depositData;
  let tx;
  let aEth;

  before(async function() {
    pool = await StkrPool.deployed();
    aEth = await AEth.deployed();

    const data = fs.readFileSync(path.join(__dirname, "/helpers/depositdata"), "utf8")
      .slice(8);

    depositData =
      web3.eth.abi.decodeParameters(["bytes", "bytes", "bytes", "bytes32"], data);

    owner = accounts[0];

    for (let i = 0; i < 300; i++) {
      await helpers.advanceBlock();
    }
  });

  it("should let users to stake", async () => {
    const tx = await pool.stake({
      from: accounts[0],
      value: helpers.wei(10)
    });

    expectEvent(tx, "StakePending", { staker: accounts[0], amount: helpers.wei(10) });
  });

  it("should close pool after 32 eth", async () => {
    await pool.stake({
      from: accounts[1],
      value: helpers.wei(22)
    });
    const tx = await helpers.pushToBeacon(pool);
    expectEvent(tx, "PoolOnGoing", { pool: depositData[0] });
  });

  it("should distribute calculate pending stake amounts correctly", async () => {
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

  it("should throw error if pending amount lower than 32 ether", async () => {
    await expectRevert(helpers.pushToBeacon(pool), "pending ethers not enough");
  });

  it("Should emit stake confirm events after push", async () => {
    await pool.stake({
      from: accounts[3],
      value: helpers.wei(13)
    });

    await pool.stake({
      from: accounts[4],
      value: helpers.wei(3)
    });

    await pool.stake({
      from: accounts[4],
      value: helpers.wei(8)
    });

    tx = await helpers.pushToBeacon(pool);
    expectEvent(tx, "StakeConfirmed", { staker: accounts[0], amount: helpers.wei(10) });
    expectEvent(tx, "StakeConfirmed", { staker: accounts[1], amount: helpers.wei(7) });
    expectEvent(tx, "StakeConfirmed", { staker: accounts[3], amount: helpers.wei(15) });
  });

  it("Should calculate correct remaining amount after confirmed stake", async () => {
    assert.equal(Number(await pool.pendingStakesOf(accounts[3])), helpers.wei(11));
  });

  it("Stakers should be able to unstake pending stakes", async () => {
    await pool.unstake({ from: accounts[3] });
    assert.equal(Number(await pool.pendingStakesOf(accounts[3])), helpers.wei(0));
  });

  it("Should claim correct amounts of aeth", async () => {
    await pool.claim();
    assert.equal(Number(await aEth.balanceOf(accounts[0])), helpers.wei(20));

    await pool.claim({ from: accounts[1] });
    assert.equal(Number(await aEth.balanceOf(accounts[1])), helpers.wei(29));

    await pool.claim({ from: accounts[3] });
    assert.equal(Number(await aEth.balanceOf(accounts[3])), helpers.wei(15));
  });

  it("Should revert for zero balance", async () => {
    expectRevert(pool.claim({ from: accounts[3] }), "claimable reward zero");
  });
});