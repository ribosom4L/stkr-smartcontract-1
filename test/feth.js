const { fromWei } = require("@openzeppelin/cli/lib/utils/units");
const helpers = require("./helpers/helpers");
const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const GlobalPool = artifacts.require("GlobalPool");
const GlobalPool_R27 = artifacts.require("GlobalPool_R27");
const FETH = artifacts.require("FETH");
const { upgradeProxy, admin } = require("@openzeppelin/truffle-upgrades");

contract("fETH Token", function(accounts) {
  let pool, feth;

  before(async function() {
    pool = await GlobalPool.deployed();
    feth = await FETH.deployed();
    pool = await upgradeProxy(pool.address, GlobalPool_R27);

    for (let i = 0; i < 300; i++) {
      await helpers.advanceBlock();
    }
  });

  it("name and symbol should be correct", async () => {
    assert.equal(await feth.name(), "Ankr Eth2 Futures")
    assert.equal(await feth.symbol(), "fETH")
  })

  it("should be claimable after push", async () => {
    await pool.stake({ value: helpers.wei(32), from: accounts[0] });

    await helpers.pushToBeacon(pool)

    assert.equal(Number(fromWei(await pool.claimableAETHFRewardOf(accounts[0]))), 32)
  });

  it("supply should be increased only when user claimed", async () => {
    await pool.claimFETH()
    assert.equal(Number(fromWei(await feth.totalSupply())), 32)
  });

  it("should increase balances after update reward amount", async () => {
    await pool.stake({ value: helpers.wei(3), from: accounts[1] });
    await pool.stake({ value: helpers.wei(6), from: accounts[2] });
    await pool.stake({ value: helpers.wei(9), from: accounts[3] });
    await pool.stake({ value: helpers.wei(12), from: accounts[4] });
    await pool.stake({ value: helpers.wei(2), from: accounts[5] });

    await helpers.pushToBeacon(pool)

    assert.equal(Number(fromWei(await pool.claimableAETHFRewardOf(accounts[1]))), 3)

    await pool.claimFETH({ from: accounts[1] });
    assert.equal(Number(fromWei(await feth.balanceOf(accounts[1]))), 3)
    assert.equal(Number(fromWei(await feth.totalSupply())), 35)
    await pool.claimFETH({ from: accounts[2] });
    assert.equal(Number(fromWei(await feth.balanceOf(accounts[2]))), 6)
    assert.equal(Number(fromWei(await feth.totalSupply())), 41)
    await pool.claimFETH({ from: accounts[3] });
    assert.equal(Number(fromWei(await feth.balanceOf(accounts[3]))), 9)
    assert.equal(Number(fromWei(await feth.totalSupply())), 50)
    await pool.claimFETH({ from: accounts[4] });
    assert.equal(Number(fromWei(await feth.balanceOf(accounts[4]))), 12)
    assert.equal(Number(fromWei(await feth.totalSupply())), 62)
    await pool.claimFETH({ from: accounts[5] });
    assert.equal(Number(fromWei(await feth.totalSupply())), 64)
    assert.equal(Number(fromWei(await feth.balanceOf(accounts[5]))), 2)

    assert.equal(Number(await feth.balanceOf(accounts[1])), web3.utils.toWei("3"))
    assert.equal(Number(await feth.balanceOf(accounts[2])), web3.utils.toWei("6"))
    assert.equal(Number(await feth.balanceOf(accounts[3])), web3.utils.toWei("9"))

    await pool.updateFETHRewards(web3.utils.toWei("0.2"))

    assert.equal(Number(fromWei(await feth.balanceOf(accounts[1]))), 3 + 0.2 * 3 / 64)
    assert.equal(Number(fromWei(await feth.balanceOf(accounts[2]))), 6 + 0.2 * 6 / 64)
    assert.equal(Number(fromWei(await feth.balanceOf(accounts[3]))), 9 + 0.2 * 9 / 64)
    assert.equal(Number(fromWei(await feth.balanceOf(accounts[4]))), 12 + 0.2 * 12 / 64)
    assert.equal(Number(fromWei(await feth.balanceOf(accounts[5]))), 2 + 0.2 * 2 / 64)

    assert.equal(Number(fromWei(await feth.totalSupply())), 64.2)


    await pool.updateFETHRewards(web3.utils.toWei("10"))

    assert.equal(Number(fromWei(await feth.balanceOf(accounts[1]))), 3 + 10 * 3 / 64)
    assert.equal(Number(fromWei(await feth.balanceOf(accounts[2]))), 6 + 10 * 6 / 64)
    assert.equal(Number(fromWei(await feth.balanceOf(accounts[3]))), 9 + 10 * 9 / 64)
    assert.equal(Number(fromWei(await feth.balanceOf(accounts[4]))), 12 + 10 * 12 / 64)
    assert.equal(Number(fromWei(await feth.balanceOf(accounts[5]))), 2 + 10 * 2 / 64)

    assert.equal(Number(fromWei(await feth.totalSupply())), 74)

  });
});
