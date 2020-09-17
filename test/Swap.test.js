const truffleAssert = require("truffle-assertions");
// const BigNumber = require('bignumber.js');
const helpers = require("./helpers/helpers");
const { assert } = require("chai");

describe("Swap", async () => {
  let microPoolContract;
  let tokenContract;
  let governanceContract;
  let insuranceContract;
  let marketPlaceContract;
  let nodeContract;
  let providerContract;
  let stakingContract;
  let ankrContract;
  let swapContract;
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
    const NodeContract = await ethers.getContractFactory("Node");
    const ProviderContract = await ethers.getContractFactory("Provider");
    const StakingContract = await ethers.getContractFactory("Staking");
    const SwapContract = await ethers.getContractFactory("Swap");

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

    ankrContract = await AnkrContract.deploy(await accounts[0].getAddress());
    await ankrContract.deployed();

    swapContract = await SwapContract.deploy();
    await swapContract.deployed();

    stakingContract = await StakingContract.deploy(ankrContract.address, nodeContract.address, microPoolContract.address);
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
    assert.isTrue(web3.utils.isAddress(nodeContract.address));
    assert.isTrue(web3.utils.isAddress(providerContract.address));
    assert.isTrue(web3.utils.isAddress(stakingContract.address));
    assert.isTrue(web3.utils.isAddress(swapContract.address));
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

    await truffleAssert.passes(
      providerContract.updateGovernanceContract(governanceContract.address)
    )

    await truffleAssert.passes(
      providerContract.updateStakingContract(stakingContract.address)
    )

    await truffleAssert.passes(
      stakingContract.updateGovernanceContract(governanceContract.address)
    )

    await truffleAssert.passes(
      stakingContract.updateAnkrContract(ankrContract.address)
    )

    await truffleAssert.passes(
      stakingContract.updateNodeContract(nodeContract.address)
    )

    await truffleAssert.passes(
      stakingContract.updateProviderContract(providerContract.address)
    )

    await truffleAssert.passes(
      stakingContract.updateMicroPoolContract(microPoolContract.address)
    )

    await truffleAssert.passes(
      swapContract.updateGovernanceContract(governanceContract.address)
    )

    await truffleAssert.passes(
      swapContract.updateTokenContract(tokenContract.address)
    )

    assert.equal(await tokenContract.microPoolContract(), microPoolContract.address);
  })

  it("Should user swap AETH to ETH", async () => {
    let initUserBalance = (await web3.eth.getBalance(await accounts[0].getAddress()))
    await truffleAssert.passes(
      tokenContract.mint(await accounts[0].getAddress(), helpers.amount(5)),
      "mint"
    )
    assert.equal(await tokenContract.balanceOf(await accounts[0].getAddress()), helpers.amount(5), "5 AETH given to user for test")
    await tokenContract.approve(swapContract.address, helpers.amount(5))
    await web3.eth.sendTransaction({from: await accounts[4].getAddress(), to: swapContract.address, value: helpers.amount(7)});

    await truffleAssert.passes(
      swapContract.swap(helpers.amount(5)),
      "swap"
    )
    assert.equal((await tokenContract.balanceOf(await accounts[0].getAddress())).toNumber(), helpers.amount(0), "5 AETH burnedFrom user")
    assert(Number(await web3.eth.getBalance(await accounts[0].getAddress())) > Number(initUserBalance), "User has more ethers after swapping");
  })

});
