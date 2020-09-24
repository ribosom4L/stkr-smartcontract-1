const truffleAssert = require("truffle-assertions");
// const BigNumber = require('bignumber.js');
const helpers = require("./helpers/helpers");
const { assert } = require("chai");

describe("MarketPlace", async () => {
  let microPoolContract;
  let tokenContract;
  let governanceContract;
  let insuranceContract;
  let marketPlaceContract;
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
    const InsuranceContract = await ethers.getContractFactory("InsurancePool");
    const MarketPlaceContract = await ethers.getContractFactory("MarketPlace");

    tokenContract = await TokenContract.deploy();
    await tokenContract.deployed();

    governanceContract = await GovernanceContract.deploy();
    await governanceContract.deployed();

    microPoolContract = await MicroPoolContract.deploy(tokenContract.address);
    await microPoolContract.deployed();

    insuranceContract = await InsuranceContract.deploy();
    await insuranceContract.deployed();

    marketPlaceContract = await MarketPlaceContract.deploy();
    await marketPlaceContract.deployed();
  });

  it("Should validate the contracts deployed", async () => {
    assert.isTrue(web3.utils.isAddress(microPoolContract.address));
    assert.isTrue(web3.utils.isAddress(tokenContract.address));
    assert.isTrue(web3.utils.isAddress(governanceContract.address));
    assert.isTrue(web3.utils.isAddress(marketPlaceContract.address));
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

    await truffleAssert.passes(
      marketPlaceContract.updateGovernanceContract(governanceContract.address)
    )

    assert.equal(await tokenContract.microPoolContract(), microPoolContract.address);
  })

  it("Should read Governance contract addresses", async () => {
    assert.equal(await marketPlaceContract.governanceContract(), governanceContract.address)
  });

  it("Should governor update ETH/USD rate", async () => {
    await truffleAssert.passes(
      marketPlaceContract.updateEthUsdRate(3)
    )
  });

  it("Should governor update ANKR/ETH rate", async () => {
    await truffleAssert.passes(
      marketPlaceContract.updateAnkrEthRate(3)
    )
  });

  it("Should read ETH/USD rate", async () => {
    assert.equal((await marketPlaceContract.ethUsdRate()).toString(), "3");
  });

  it("Should read ETH/USD rate", async () => {
    assert.equal((await marketPlaceContract.ankrEthRate()).toString(), "3");
  });
});
