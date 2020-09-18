const truffleAssert = require("truffle-assertions");
// const BigNumber = require('bignumber.js');
const helpers = require("./helpers/helpers");
const { assert } = require("chai");

describe("Auction", async () => {
  let auctionsContract;
  let microPoolContract;
  let tokenContract;
  let governanceContract;
  let insuranceContract;
  let marketPlaceContract;
  let nodeContract;
  let providerContract;
  let stakingContract;
  let ankrContract;
  let accounts;
  let validatorAddr;

  before(async function () {
    accounts = await ethers.getSigners();
    validatorAddr = await accounts[9].getAddress();

    const AuctionsContract = await ethers.getContractFactory("Auctions");
    const MicroPoolContract = await ethers.getContractFactory("MicroPool");
    const TokenContract = await ethers.getContractFactory("AETH");
    const AnkrContract = await ethers.getContractFactory("ANKR");
    const GovernanceContract = await ethers.getContractFactory("Governance");
    const InsuranceContract = await ethers.getContractFactory("InsurancePool");
    const MarketPlaceContract = await ethers.getContractFactory("MarketPlace");
    const NodeContract = await ethers.getContractFactory("Node");
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

    nodeContract = await NodeContract.deploy();
    await nodeContract.deployed();

    ankrContract = await AnkrContract.deploy(await accounts[0].getAddress());
    await ankrContract.deployed();

    stakingContract = await StakingContract.deploy(
      ankrContract.address,
      nodeContract.address,
      microPoolContract.address
    );
    await stakingContract.deployed();

    providerContract = await ProviderContract.deploy(stakingContract.address);
    await providerContract.deployed();

    auctionsContract = await AuctionsContract.deploy(providerContract.address);
    await auctionsContract.deployed();
  });

  it("Should validate the contracts deployed", async () => {
    assert.isTrue(web3.utils.isAddress(microPoolContract.address), "micropool");
    assert.isTrue(web3.utils.isAddress(tokenContract.address), "token");
    assert.isTrue(
      web3.utils.isAddress(governanceContract.address),
      "governance"
    );
    assert.isTrue(web3.utils.isAddress(insuranceContract.address), "insurance");
    assert.isTrue(
      web3.utils.isAddress(marketPlaceContract.address),
      "marketplace"
    );
    assert.isTrue(web3.utils.isAddress(nodeContract.address), "node");
    assert.isTrue(web3.utils.isAddress(providerContract.address), "provider");
    assert.isTrue(web3.utils.isAddress(stakingContract.address), "staking");
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
      nodeContract.updateGovernanceContract(governanceContract.address)
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
      stakingContract.updateNodeContract(nodeContract.address)
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

  it("Should add providers", async () => {
    await truffleAssert.passes(
      providerContract.applyToBeProvider(
        "0x68656c6c6f2d6d792d776f726c64000000000000000000000000000000000000",
        "0x68656c6c6f2d6d792d776f726c64000000000000000000000000000000000000",
        "0x68656c6c6f2d6d792d776f726c64000000000000000000000000000000000000",
        "0x68656c6c6f2d6d792d776f726c64000000000000000000000000000000000000"
      ),
      "first"
    );

    await truffleAssert.passes(
      providerContract
        .connect(accounts[5])
        .applyToBeProvider(
          "0x68656c6c6f2d6d792d776f726c64000000000000000000000000000000000000",
          "0x68656c6c6f2d6d792d776f726c64000000000000000000000000000000000000",
          "0x68656c6c6f2d6d792d776f726c64000000000000000000000000000000000000",
          "0x68656c6c6f2d6d792d776f726c64000000000000000000000000000000000000"
        ),
      "second"
    );

    await truffleAssert.passes(
      providerContract
        .connect(accounts[6])
        .applyToBeProvider(
          "0x68656c6c6f2d6d792d776f726c64000000000000000000000000000000000000",
          "0x68656c6c6f2d6d792d776f726c64000000000000000000000000000000000000",
          "0x68656c6c6f2d6d792d776f726c64000000000000000000000000000000000000",
          "0x68656c6c6f2d6d792d776f726c64000000000000000000000000000000000000"
        ),
      "third"
    );

    await truffleAssert.passes(
      providerContract.approve(await accounts[0].getAddress()),
      "4"
    );

    await truffleAssert.passes(
      providerContract.approve(await accounts[5].getAddress()),
      "5"
    );

    await truffleAssert.passes(
      providerContract.approve(await accounts[6].getAddress()),
      "6"
    );
  });

  it("Should requester start a new auction with a processing fee and a deadline", async () => {
    await truffleAssert.passes(
      auctionsContract.startAuction(
        helpers.amount(5), // 5 eth is the max budget of requester
        2 // auction will last for 2 days
      )
    );
  });

  it("Should revert with a message if provider bid higher than requester's budget", async () => {
    await truffleAssert.reverts(
      auctionsContract.connect(accounts[5]).bid(0, helpers.amount(11)),
      "You need to offer less than or equal to requester's budget."
    );
  });

  // TODO: make a wallet before the next test provider when provider contract is ready
  it("Should provider add a new bid", async () => {
    await truffleAssert.passes(auctionsContract.bid(0, helpers.amount(2)));
  });

  it("Should revert with a message if provider bid higher than the best bid", async () => {
    await truffleAssert.reverts(
      auctionsContract.connect(accounts[6]).bid(0, helpers.amount(3)),
      "You need to offer less than the lowest bid."
    );
  });

  it("Should read status and details of an auction", async () => {
    const auctionDetails = await auctionsContract.auctionDetails(0);
    assert.equal(
      auctionDetails.processingFee.toString(),
      helpers.amount(5),
      "processing fee"
    );
    assert.equal(auctionDetails.status, 0, "status");
    assert.equal(
      auctionDetails.bestBidAmount.toString(),
      helpers.amount(2),
      "best bid amount"
    );
    assert.equal(
      auctionDetails.bestBidder,
      await accounts[0].getAddress(),
      "address"
    );
  });
});
