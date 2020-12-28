const { fromWei } = require("@openzeppelin/cli/lib/utils/units");
const helpers = require("./helpers/helpers");
const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const GlobalPool = artifacts.require("GlobalPool");
const AETH = artifacts.require("AETH");
const AETH_R4 = artifacts.require("AETH_R4");
const { upgradeProxy, admin } = require("@openzeppelin/truffle-upgrades");

contract("ankrETH", function(accounts) {
  let pool, aeth;

  before(async function() {
    pool = await GlobalPool.deployed();
    const aethOld = await AETH.deployed();
    aeth = await upgradeProxy(aethOld.address, AETH_R4);
  });

  it("only operator should be able to update the ratio", async () => {
    await expectRevert(aeth.updateRatio(helpers.wei(0.99), { from: accounts[1] }), "Operator: not allowed");
    aeth.changeOperator(accounts[1]);
  });

  it("should calculate ratio correctly on push to beacon", async () => {
    let ratio = 1;
    // get aeth balance first
    const firstBalance = Number(fromWei(await aeth.balanceOf(pool.address)));
    // stake 32
    await pool.stake({ value: helpers.wei(32) });
    // push to beacon
    await helpers.pushToBeacon(pool);
    // get aeth balance
    const secondBalance = Number(fromWei(await aeth.balanceOf(pool.address)));
    // it should bi +32 of first
    assert.equal(secondBalance, firstBalance + 32);
    // update ratio x
    let lastBalance = secondBalance;
    for (let i = 0; i < 20; i++) {
      ratio = ratio * 0.98
      await aeth.updateRatio(helpers.wei(ratio), { from: accounts[1] });
      // stake 32
      await pool.stake({ value: helpers.wei(32), from: accounts[i % 10] });
      // push to beacon
      await helpers.pushToBeacon(pool);
      // get aeth balance
      const thirdBalance = Number(fromWei(await aeth.balanceOf(pool.address)));
      // it should be + (32 * x) of second
      assert.equal(thirdBalance.toFixed(5), (lastBalance + (32 * ratio)).toFixed(5));
      lastBalance = thirdBalance;
    }
  });
});