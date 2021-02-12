const { fromWei } = require("@openzeppelin/cli/lib/utils/units");
const helpers = require("./helpers/helpers");
const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const GlobalPool = artifacts.require("GlobalPool");
const GlobalPool_R24 = artifacts.require("GlobalPool_R24");
const AETH = artifacts.require("AETH");
const AETH_R8 = artifacts.require("AETH_R8");
const { upgradeProxy, admin } = require("@openzeppelin/truffle-upgrades");

contract("aETH", function(accounts) {
  let pool, aeth;

  before(async function() {
    pool = await GlobalPool.deployed();
    const aethOld = await AETH.deployed();
    aeth = await upgradeProxy(aethOld.address, AETH_R8);
    pool = await upgradeProxy(pool.address, GlobalPool_R24)

    for (let i = 0; i < 300; i++) {
      await helpers.advanceBlock();
    }
  });

  it("only operator should be able to update the ratio", async () => {
    await expectRevert(aeth.updateRatio(helpers.wei(0.99), { from: accounts[1] }), "Operator: not allowed");
    aeth.changeOperator(accounts[1]);
  });

  it("should calculate ratio correctly on push to beacon", async () => {
    let ratio = 1;
    // get aeth balance first
    const firstBalance = Number(fromWei(await aeth.balanceOf(accounts[0])));
    // stake 32
    for (let i = 0; i < 300; i++) {
      await helpers.advanceBlock();
    }
    await pool.stake({ value: helpers.wei(32) });
    // push to beacon
    await helpers.pushToBeacon(pool);

    await pool.claimAETH();
    // get aeth balance
    const secondBalance = Number(fromWei(await aeth.balanceOf(accounts[0])));
    // it should bi +32 of first
    assert.equal(secondBalance, firstBalance + 32);
    for (let i = 0; i < 20; i++) {
      ratio = ratio * 0.998
      await aeth.updateRatio(helpers.wei(ratio), { from: accounts[1] });
      const acc = accounts[i % 10];

      const accBalance = Number(fromWei(await aeth.balanceOf(acc)));

      // stake 32
      await pool.stake({ value: helpers.wei(32), from: acc });

      // push to beacon
      await helpers.pushToBeacon(pool);

      await pool.claimAETH({ from: acc })

      // get aeth balance
      const lastBalance = Number(fromWei(await aeth.balanceOf(acc)));
      // it should be + (32 * x) of second
      assert.equal(lastBalance.toFixed(5), (accBalance + (32 * ratio)).toFixed(5));
    }
  });

});
