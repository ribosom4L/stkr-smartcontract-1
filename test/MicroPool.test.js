const truffleAssert = require("truffle-assertions");
// const BigNumber = require('bignumber.js');
const helpers = require("./helpers/helpers");
const { assert } = require("chai");

describe("MicroPool", async () => {
  let microPoolContract;
  let tokenContract;
  let governanceContract;
  let accounts;
  let providerAddr;
  let validatorAddr;

  before(async function () {
    accounts = await ethers.getSigners();
    providerAddr = await accounts[8].getAddress();
    validatorAddr = await accounts[9].getAddress();

    const MicroPoolContract = await ethers.getContractFactory("MicroPool");
    const TokenContract = await ethers.getContractFactory("AETH");
    const GovernanceContract = await ethers.getContractFactory("Governance");

    tokenContract = await TokenContract.deploy();
    await tokenContract.deployed();

    governanceContract = await GovernanceContract.deploy();
    await governanceContract.deployed();

    microPoolContract = await MicroPoolContract.deploy(tokenContract.address);
    await microPoolContract.deployed();
  });

  it("Should validate the contracts deployed", async () => {
    assert.isTrue(web3.utils.isAddress(microPoolContract.address));
    assert.isTrue(web3.utils.isAddress(tokenContract.address));
    assert.isTrue(web3.utils.isAddress(governanceContract.address));
  });

  it("Should add contract addresses to each other", async () => {
    await truffleAssert.passes(
      tokenContract.updateMicroPoolContract(microPoolContract.address)
    )

    await truffleAssert.passes(
      microPoolContract.updateGovernanceContract(governanceContract.address)
    )
    assert.equal(await tokenContract.microPoolContract(), microPoolContract.address);
  })

  it("Should read Governance contract address", async () => {
    assert.equal(await microPoolContract.governanceContract(), governanceContract.address)
  });

  it("Should read claimable status", async () => {
    assert.isNotTrue(await microPoolContract.claimable(), false)
  });

  it("Should create a new pool", async () => {
    await truffleAssert.passes(
      microPoolContract.initializePool(
        providerAddr,
        validatorAddr,
        helpers.amount(3) // 3 ETH
      )
    )
  });

  it("Should read a pool details", async () => {
    const details = await microPoolContract.poolDetails(0);
    assert.equal(details.status, 0, "status");
    assert.equal(details.provider, providerAddr, "provider address");
    assert.equal(details.validator, validatorAddr, "validator address");
    // assert.equal(details.members.length, 0, "member's length");
    assert.equal(details.providerOwe.toString(), helpers.amount(3), "provider owe");
    assert.equal(details.rewardBalance.toNumber(), 0, "reward amount");
    assert.equal(details.claimedBalance.toNumber(), 0, "claimed amount");
    assert.equal(details.totalStakedAmount.toNumber(), 0, "total staked amount");
  });

  it("Should user stake and get AETH amount which is half of his stake amount", async () => {
    const stakeAmount = helpers.amount(4);
    await truffleAssert.passes(
      microPoolContract.stake(0, {value: stakeAmount})
    )
    assert.equal(stakeAmount / 2, (await tokenContract.balanceOf(await accounts[0].getAddress())).toString())
    const details = await microPoolContract.poolDetails(0);
    assert.equal(details.totalStakedAmount.toString(), stakeAmount, "total staked amount");
  });

  it("Should user be able to unstake if pool status is 'pending'", async () => {
    await truffleAssert.passes(
      microPoolContract.unstake(0)
    );

    const details = await microPoolContract.poolDetails(0);
    assert.equal(details.totalStakedAmount.toNumber(), 0, "total staked amount");
  });

});
