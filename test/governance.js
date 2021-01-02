const { fromWei } = require("@openzeppelin/cli/lib/utils/units");
const helpers = require("./helpers/helpers");
const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const { upgradeProxy, admin } = require("@openzeppelin/truffle-upgrades");
const Governance = artifacts.require("Governance");
const ANKR = artifacts.require("ANKR");

contract("Governance", function(accounts) {
  let governance, ankr, proposalId;
  const ankrLimit = web3.utils.toWei(5000000 + "");
  const dayInSec = 24 * 60 * 60;
  const testTopic = "Test Topic";
  const testContent = "Test Content";

  before(async function() {
    governance = await Governance.deployed();
    ankr = await ANKR.deployed();
  });

  it("Proposals should be created with enough amount of ankr", async () => {
    await expectRevert(depositAndPropose(dayInSec * 2, testTopic, testContent, accounts[0]), "Timespan lower than limit");
    await expectRevert(depositAndPropose(dayInSec * 8, testTopic, testContent, accounts[0]), "Timespan greater than limit");
    await expectRevert(depositAndPropose(dayInSec * 4, testTopic, testContent, accounts[0]), "You dont have enough amount to freeze ankr");
    // get 5m ankr tokens 0
    await ankr.faucet5m({ from: accounts[0] });

    await ankr.approve(governance.address, ankrLimit);
    const tx = await depositAndPropose(dayInSec * 4, testTopic, testContent, accounts[0]);
  });

  it("Votes should affect the proposal correctly", async () => {
    await ankr.faucet5m({ from: accounts[2] });

    await ankr.approve(governance.address, ankrLimit, { from: accounts[2] });
    const tx = await depositAndPropose(dayInSec * 4, testTopic, testContent, accounts[2]);
    const vote = tx.logs[tx.logs.length - 1];
    const proposal = tx.logs[tx.logs.length - 2];
    assert.equal(Number(web3.utils.fromWei(vote.args.votes.toString())), 5000000);

    proposalId = proposal.args["proposeID"];

    await ankr.faucet({ from: accounts[1] });

    await ankr.approve(governance.address, web3.utils.toWei(100000 + ""), { from: accounts[1] });

    const txVote = await governance.vote(proposalId, web3.utils.fromAscii("VOTE_NO"), { from: accounts[1] });
  });

  it("Proposal info should be fetched correctly", async () => {
    const data = await governance.proposal(proposalId)
    assert.equal(data.topic, "Test Topic")
    assert.equal(data.content, "Test Content")
    assert.equal(Number(data.yes), 5000000)
    assert.equal(Number(data.no), 100000)
    // status is voting
    assert.equal(Number(data.status), 1)
    // current result is true
    assert.equal(data.result, true)
  });

  async function depositAndPropose(secs, topic, content, from) {
    return governance.propose(secs, topic, content, { from });
  }
});