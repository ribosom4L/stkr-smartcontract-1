const truffleAssert = require("truffle-assertions");
// const BigNumber = require('bignumber.js');
const helpers = require("./helpers/helpers");
const { assert } = require("chai");

let microPoolContract;
let tokenContract;
let governanceContract;
let providerContract;
let auctionsContract;
let accounts;
let providerAddr;
let validatorAddr;

describe("Auction", async () => {
  
  before(async function () {
    accounts = await ethers.getSigners();
    providerAddr = await accounts[8].getAddress();
    validatorAddr = await accounts[9].getAddress();

    const MicroPoolContract = await ethers.getContractFactory("MicroPool");
    const TokenContract = await ethers.getContractFactory("AETH");
    const GovernanceContract = await ethers.getContractFactory("Governance");
    const AuctionsContract = await ethers.getContractFactory("Auctions");
    const ProviderContract = await ethers.getContractFactory("Provider");

    tokenContract = await TokenContract.deploy();
    await tokenContract.deployed();

    governanceContract = await GovernanceContract.deploy();
    await governanceContract.deployed();

    microPoolContract = await MicroPoolContract.deploy(tokenContract.address);
    await microPoolContract.deployed();

    providerContract = await ProviderContract.deploy();
    await providerContract.deployed();

    auctionsContract = await AuctionsContract.deploy(providerContract.address);
    await auctionsContract.deployed();
  });

  it("Should validate the contracts deployed", async () => {
    assert.isTrue(web3.utils.isAddress(microPoolContract.address));
    assert.isTrue(web3.utils.isAddress(tokenContract.address));
    assert.isTrue(web3.utils.isAddress(governanceContract.address));
    assert.isTrue(web3.utils.isAddress(providerContract.address));
    assert.isTrue(web3.utils.isAddress(auctionsContract.address));
  });

  it("Should add micro pool contract address' to token contract", async () => {
    await truffleAssert.passes(
      tokenContract.updateMicroPoolContract(microPoolContract.address)
    )
    assert.equal(await tokenContract.microPoolContract(), microPoolContract.address);
  });

  it("Should requester start a new auction with a processing fee and a deadline", async () => {
    await truffleAssert.passes(
      auctionsContract.startAuction(
        helpers.amount(5), // 5 eth is the max budget of requester
        2 // auction will last for 2 days
      )
    )
  });

  it("Should revert with a message if provider bid higher than requester's budget", async () => {
    await truffleAssert.reverts(
      auctionsContract.connect(accounts[5]).bid(
        0,
        helpers.amount(11)
      ), "You need to offer less than or equal to requester's budget."
    )
  });

  // TODO: make a wallet before the next test provider when provider contract is ready
  it("Should provider add a new bid", async () => {
    await truffleAssert.passes(
      auctionsContract.bid(
        0,
        helpers.amount(2)
      )
    )
  });

  it("Should revert with a message if provider bid higher than the best bid", async () => {
    await truffleAssert.reverts(
      auctionsContract.connect(accounts[6]).bid(
        0,
        helpers.amount(3)
      ), "You need to offer less than the lowest bid."
    )
  });

  it("Should read status and details of an auction", async () => {
    const auctionDetails = await auctionsContract.auctionDetails(0);
    assert.equal(auctionDetails.processingFee.toString(), helpers.amount(5), "processing fee");
    assert.equal(auctionDetails.status, 0, "status");
    assert.equal(auctionDetails.bestBidAmount.toString(), helpers.amount(2), "best bid amount");
    assert.equal(auctionDetails.bestBidder, await accounts[0].getAddress(), "address");
  });
});