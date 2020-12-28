const fs = require("fs");
const path = require("path");
const helpers = require("./helpers/helpers");
const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const GlobalPool = artifacts.require("GlobalPool");
const Config = artifacts.require("Config");
const GlobalPool_R21 = artifacts.require("GlobalPool_R21");
const DepositContract = artifacts.require("DepositContract");

const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const AnkrETH = artifacts.require("AETH");

contract("2020 11 30 Upgrade Global Pool", function(accounts) {
  let poolOld;
  let pool;
  let config;
  let ankrETH;

  before(async function() {
    ankrETH = await AnkrETH.deployed();
    config = await Config.deployed();
    const deposit = await DepositContract.deployed();
    pool = await GlobalPool_R21.new();
    pool.initialize(ankrETH.address, config.address, deposit.address)
    // pool = await upgradeProxy(poolOld.address, GlobalPool_R21);
    await pool.updateConfigContract(config.address)
    await pool.togglePause(web3.utils.fromAscii("topUpETH"));
    // pool.togglePause("Stake");
    await ankrETH.updateGlobalPoolContract(pool.address)

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

  it("should mint correct amount for provider participated rounds", async () => {
    const poolBalanceBefore = await ankrETH.balanceOf(pool.address);

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
    await helpers.pushToBeacon(pool);

    // pool ankrETH balance
    const poolBalanceAfter1 = await ankrETH.balanceOf(pool.address);

    assert.equal(web3.utils.fromWei(poolBalanceAfter1) - web3.utils.fromWei(poolBalanceBefore), 19);

    await pool.topUpETH({
      from: accounts[0],
      value: helpers.wei(3)
    });

    await pool.topUpETH({
      from: accounts[1],
      value: helpers.wei(7)
    });

    await pool.topUpETH({
      from: accounts[2],
      value: helpers.wei(7)
    });

    await pool.topUpETH({
      from: accounts[3],
      value: helpers.wei(13)
    });

    await pool.topUpETH({
      from: accounts[3],
      value: helpers.wei(2)
    });

    await helpers.pushToBeacon(pool);

    const poolBalanceAfter2 = await ankrETH.balanceOf(pool.address);

    assert.equal(web3.utils.fromWei(poolBalanceAfter2) - web3.utils.fromWei(poolBalanceAfter1), 0);
  });

  it("should distribute correct aETH amounts with claim function", async () => {

    const stakes = [];
    const topUps = [];
    topUps.push(
      {
        8: 7,
        9: 2
      },
      {
        9: 4,
        6: 10
      }
    );
    stakes.push(
      {
        6: 3,
        7: 7,
        8: 13
      },
      {
        9: 10,
        6: 8,
      }
    );

    for (let i = 0; i < topUps.length; i++) {
      const userTotals = {
        6: 0,
        7: 0,
        8: 0,
        9: 0
      }
      for (const acc in topUps[i]) {
        await pool.topUpETH({
          from: accounts[acc],
          value: helpers.wei(topUps[i][acc])
        });
        userTotals[acc] += topUps[i][acc]
      }

      for (const acc in stakes[i]) {
        await pool.stake({
          from: accounts[acc],
          value: helpers.wei(stakes[i][acc])
        });

        userTotals[acc] += stakes[i][acc]
      }

      if (web3.utils.fromWei(await ankrETH.balanceOf(pool.address)) > 0)
        await helpers.pushToBeacon(pool);

      for (const user in userTotals) {
        const acc = accounts[user]
        let claimable = Number(web3.utils.fromWei(await pool.claimableRewardOf(acc)))
        let stake = stakes[i][user] || 0
        let topUp = topUps[i][user] || 0

        assert.equal(claimable, stake);
      }

      for (const user in userTotals) {
        const acc = accounts[user]
        const oldTokenBalance = Number(await ankrETH.balanceOf(acc))

        let claimable = Number(await pool.claimableRewardOf(acc))
        if (claimable > 0) await pool.claim({from: acc})

        const newTokenBalance = Number(await ankrETH.balanceOf(acc))

        assert.equal(oldTokenBalance + claimable, newTokenBalance)

        assert.equal(Number(await pool.claimableRewardOf(acc)), 0);
      }
    }
  });

  it("provider should be able to claim aETH after exit", async () => {
    // provider exits
    // after exit mint aeth
    // after x block provider can claim
    const claimableBalanceBefore = Number(web3.utils.fromWei(await pool.claimableRewardOf(accounts[9])))
    const availableEtherBalanceBefore = Number(web3.utils.fromWei(await pool.availableEtherBalanceOf(accounts[9])))

    await pool.providerExit({ from: accounts[9] })

    const claimableBalanceAfter = Number(web3.utils.fromWei(await pool.claimableRewardOf(accounts[9])))
    const availableEtherBalanceAfter = Number(web3.utils.fromWei(await pool.availableEtherBalanceOf(accounts[9])))

    for (let i = 0; i < 50; i++) {
      await helpers.advanceBlock();
    }

    assert.equal(claimableBalanceBefore + availableEtherBalanceBefore, claimableBalanceAfter)
    assert.equal(availableEtherBalanceAfter, 0)
  });

  it("should store correct amount for providers", async () => {
    await ankrETH.updateRatio(helpers.wei(0.5))
    const availableEtherBalanceBefore = Number(web3.utils.fromWei(await pool.availableEtherBalanceOf(accounts[8])))
    await pool.topUpETH({
      from: accounts[8],
      value: helpers.wei(32)
    });
    await helpers.pushToBeacon(pool);

    const availableEtherBalanceAfter = Number(web3.utils.fromWei(await pool.availableEtherBalanceOf(accounts[8])))
    assert.equal(availableEtherBalanceAfter - availableEtherBalanceBefore, 32)
  })
});