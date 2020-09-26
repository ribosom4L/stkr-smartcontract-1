const truffleAssert = require("truffle-assertions");
// const BigNumber = require('bignumber.js');
const helpers = require("./helpers/helpers");
const { assert } = require("chai");

describe("Provider", async () => {
  let microPoolContract;
  let tokenContract;
  let governanceContract;
  let insuranceContract;
  let marketPlaceContract;
  let providerContract;
  let stakingContract;
  let ankrContract;
  let accounts;
  let validatorAddr;

  before(async function () {
    accounts = await ethers.getSigners();
    validatorAddr = await accounts[9].getAddress();

    const MicroPoolContract = await ethers.getContractFactory("MicroPool");
    const TokenContract = await ethers.getContractFactory("AETH");
    const AnkrContract = await ethers.getContractFactory("ANKR");
    const GovernanceContract = await ethers.getContractFactory("Governance");
    const InsuranceContract = await ethers.getContractFactory("InsurancePool");
    const MarketPlaceContract = await ethers.getContractFactory("MarketPlace");
    const ProviderContract = await ethers.getContractFactory("Provider");
    const StakingContract = await ethers.getContractFactory("Staking");

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

    ankrContract = await AnkrContract.deploy();
    await ankrContract.deployed();

    stakingContract = await StakingContract.deploy(
      ankrContract.address,
      microPoolContract.address
    );
    await stakingContract.deployed();

    providerContract = await ProviderContract.deploy(stakingContract.address);
    await providerContract.deployed();
  });

  it("Should validate the contracts deployed", async () => {
    assert.isTrue(web3.utils.isAddress(microPoolContract.address));
    assert.isTrue(web3.utils.isAddress(tokenContract.address));
    assert.isTrue(web3.utils.isAddress(governanceContract.address));
    assert.isTrue(web3.utils.isAddress(insuranceContract.address));
    assert.isTrue(web3.utils.isAddress(marketPlaceContract.address));
    assert.isTrue(web3.utils.isAddress(providerContract.address));
    assert.isTrue(web3.utils.isAddress(stakingContract.address));
  });

  it("Should add contract addresses to each other", async () => {
    await truffleAssert.passes(
      tokenContract.updateMicroPoolContract(microPoolContract.address)
    );

    await truffleAssert.passes(
      microPoolContract.updateGovernanceContract(governanceContract.address)
    );

    await truffleAssert.passes(
      insuranceContract.updateGovernanceContract(governanceContract.address)
    );

    await truffleAssert.passes(
      insuranceContract.updateMicroPoolContract(microPoolContract.address)
    );

    await truffleAssert.passes(
      marketPlaceContract.updateGovernanceContract(governanceContract.address)
    );

    await truffleAssert.passes(
      providerContract.updateGovernanceContract(governanceContract.address)
    );

    await truffleAssert.passes(
      providerContract.updateStakingContract(stakingContract.address)
    );

    await truffleAssert.passes(
      stakingContract.updateGovernanceContract(governanceContract.address)
    );

    await truffleAssert.passes(
      stakingContract.updateAnkrContract(ankrContract.address)
    );

    await truffleAssert.passes(
      stakingContract.updateProviderContract(providerContract.address)
    );

    await truffleAssert.passes(
      stakingContract.updateMicroPoolContract(microPoolContract.address)
    );

    assert.equal(
      await tokenContract.microPoolContract(),
      microPoolContract.address
    );
  });

  it("Should read Governance contract addresses", async () => {
    assert.equal(
      await providerContract.governanceContract(),
      governanceContract.address
    );
  });

  it("Should user apply to be a provider", async () => {
    await truffleAssert.passes(
      providerContract.saveProvider(
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        {
          value: "199979771017400000000"
        }
      )
    );

    await truffleAssert.passes(
      providerContract
        .connect(accounts[1])
        .saveProvider(
          "0x68656c6c6f2d6d792d776f726c64000000000000000000000000000000000000",
          "0x68656c6c6f2d6d792d776f726c64000000000000000000000000000000000000",
          "0x68656c6c6f2d6d792d776f726c64000000000000000000000000000000000000",
          "0x68656c6c6f2d6d792d776f726c64000000000000000000000000000000000000"
        )
    );
  });

  it("Should governor ban a provider", async () => {
    await truffleAssert.passes(
      providerContract.ban(await accounts[1].getAddress()),
      "Not a provider"
    );

    await truffleAssert.passes(
      providerContract.ban(await accounts[0].getAddress())
    );
  });
});
