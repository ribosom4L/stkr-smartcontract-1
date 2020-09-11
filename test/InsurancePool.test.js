const truffleAssert = require("truffle-assertions");
// const BigNumber = require('bignumber.js');
const helpers = require("./helpers/helpers");
const { assert } = require("chai");

describe("Insurance", async () => {
  let microPoolContract;
  let tokenContract;
  let governanceContract;
  let insuranceContract;
  let accounts;
  let providerAddr;
  let validatorAddr;

  before(async function () {
    accounts = await ethers.getSigners();
    providerAddr = await accounts[8].getAddress();
    validatorAddr = await accounts[9].getAddress();

    const MicroPoolContract = await ethers.getContractFactory("MicroPool");
    const TokenContract = await ethers.getContractFactory("ERC20");
    const GovernanceContract = await ethers.getContractFactory("Governance");
    const InsuranceContract = await ethers.getContractFactory("InsurancePool");

    tokenContract = await TokenContract.deploy();
    await tokenContract.deployed();

    governanceContract = await GovernanceContract.deploy();
    await governanceContract.deployed();

    microPoolContract = await MicroPoolContract.deploy(tokenContract.address);
    await microPoolContract.deployed();

    insuranceContract = await InsuranceContract.deploy();
    await insuranceContract.deployed();
  });

  it("Should validate the contracts deployed", async () => {
    assert.isTrue(web3.utils.isAddress(microPoolContract.address));
    assert.isTrue(web3.utils.isAddress(tokenContract.address));
    assert.isTrue(web3.utils.isAddress(governanceContract.address));
    assert.isTrue(web3.utils.isAddress(insuranceContract.address));
  });

  it("Should add contract addresses to each other", async () => {
    await truffleAssert.passes(
      tokenContract.updateMicroPoolContract(microPoolContract.address)
    )

    await truffleAssert.passes(
      microPoolContract.updateGovernanceContract(governanceContract.address)
    )

    await truffleAssert.passes(
      insuranceContract.updateGovernanceContract(governanceContract.address)
    )

    await truffleAssert.passes(
      insuranceContract.updateMicroPoolContract(microPoolContract.address)
    )

    assert.equal(await tokenContract.microPoolContract(), microPoolContract.address);
  })

  it("Should read Governance and MicroPool contract addresses", async () => {
    assert.equal(await insuranceContract.governanceContract(), governanceContract.address)
    assert.equal(await insuranceContract.microPoolContract(), microPoolContract.address)
  });

  it("Should governor update slashings", async () => {
    await truffleAssert.passes(
      microPoolContract.initializePool(
        providerAddr,
        validatorAddr,
        helpers.amount(3) // 3 ETH
      )
    )

    await truffleAssert.passes(
      insuranceContract.updateSlashings(0, 1)
    )
  });

});
