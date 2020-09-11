const truffleAssert = require("truffle-assertions");
// const BigNumber = require('bignumber.js');
const helpers = require("./helpers/helpers");
const { assert } = require("chai");

describe("Node", async () => {
  let microPoolContract;
  let tokenContract;
  let governanceContract;
  let insuranceContract;
  let marketPlaceContract;
  let nodeContract;
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
    const NodeContract = await ethers.getContractFactory("Node");

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

    nodeContract = await NodeContract.deploy();
    await nodeContract.deployed();
  });

  it("Should validate the contracts deployed", async () => {
    assert.isTrue(web3.utils.isAddress(microPoolContract.address));
    assert.isTrue(web3.utils.isAddress(tokenContract.address));
    assert.isTrue(web3.utils.isAddress(governanceContract.address));
    assert.isTrue(web3.utils.isAddress(insuranceContract.address));
    assert.isTrue(web3.utils.isAddress(marketPlaceContract.address));
    assert.isTrue(web3.utils.isAddress(nodeContract.address));
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

    await truffleAssert.passes(
      nodeContract.updateGovernanceContract(governanceContract.address)
    )

    assert.equal(await tokenContract.microPoolContract(), microPoolContract.address);
  })

  it("Should read Governance contract addresses", async () => {
    assert.equal(await nodeContract.governanceContract(), governanceContract.address)
  });

  it("Should provider request a new node", async () => {
    await truffleAssert.passes(
      nodeContract.request("0x5543450BE9D8E819719A609d343Aa37264BC77B8")
    )

    await truffleAssert.passes(
      nodeContract.request("0x0D8775F648430679A709E98d2b0Cb6250d2887EF")
    )
  });

  it("Should governor approve a request", async () => {
    await truffleAssert.passes(
      nodeContract.approve("0x5543450BE9D8E819719A609d343Aa37264BC77B8")
    )
  });

  it("Should governor reject a request", async () => {
    await truffleAssert.passes(
      nodeContract.reject("0x0D8775F648430679A709E98d2b0Cb6250d2887EF")
    )
  });
});
