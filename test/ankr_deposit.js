const { fromWei } = require("@openzeppelin/cli/lib/utils/units");
const helpers = require("./helpers/helpers");
const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const GlobalPool = artifacts.require("GlobalPool");
const GlobalPool_R21 = artifacts.require("GlobalPool_R21");
const Governance = artifacts.require("Governance")
const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const Ankr = artifacts.require("ANKR")

contract("Ankr Deposit", (accounts) => {

  let pool, governance, ankr;

  before(async function() {
    const poolOld = await GlobalPool.deployed();
    pool = await upgradeProxy(poolOld.address, GlobalPool_R21);
    governance = await Governance.deployed()
    ankr = await Ankr.deployed();
  });

  it("Should allow deposit ankr with allowance", async () => {
    await ankr.faucet()
    await ankr.approve(governance.address, helpers.wei(10))
    const tx = await governance.deposit()
    const deposited = await governance.depositsOf(accounts[0])
    assert.equal(Number(deposited), helpers.wei(10))
  });

  it("Should allow withdraw deposited tokens", async () => {
    await governance.withdraw(helpers.wei(5))
    const deposited = await governance.depositsOf(accounts[0])
    assert.equal(Number(deposited), helpers.wei(5))
  });

  it("Users should be able to become a provider with ankr deposit", async () => {
    await ankr.faucet()
    await ankr.approve(governance.address, helpers.wei(100000))
    await pool.topUpANKR(helpers.wei(100000))
  });
});