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
    await expectRevert(depositAndPropose(dayInSec * 2, testTopic, testContent, accounts[0]), "Gov#propose: Timespan lower than limit");
    await expectRevert(depositAndPropose(dayInSec * 8, testTopic, testContent, accounts[0]), "Gov#propose: Timespan greater than limit");
    await expectRevert(depositAndPropose(dayInSec * 4, testTopic, testContent, accounts[0]), "Gov#propose: Not enough balance");
    // get 5m ankr tokens 0
    await faucet5mAndApprove(accounts[0])
    await depositAndPropose(dayInSec * 3, testTopic, testContent, accounts[0]);

    await faucet5mAndApprove(accounts[2])
    const tx = await depositAndPropose(dayInSec * 4, testTopic, testContent, accounts[2]);

    const vote = tx.logs[tx.logs.length - 1];
    const proposal = tx.logs[tx.logs.length - 2];
    assert.equal(Number(web3.utils.fromWei(vote.args.votes.toString())), 5000000);

    proposalId = proposal.args["proposeID"];
  });

  it("proposal should be in waiting status for 2 days", async () => {
    let data = await governance.proposal(proposalId);
    assert.equal(Number(data.status), 0);

    await faucetAndApprove(accounts[3])

    await expectRevert(governance.vote(proposalId, web3.utils.fromAscii("VOTE_NO"), { from: accounts[3] }), "Gov#__vote: Propose status is not VOTING");

    await helpers.advanceTimeAndBlock(2 * 24 * 60 * 60);
    data = await governance.proposal(proposalId);

    assert.equal(Number(data.status), 1);
    await faucetAndApprove(accounts[1])

    const txVote = await governance.vote(proposalId, web3.utils.fromAscii("VOTE_NO"), { from: accounts[1] });
    await expectEvent(txVote, "Vote")
  });

  it("Proposal info should be fetched correctly", async () => {
    const data = await governance.proposal(proposalId);
    assert.equal(data.topic, "Test Topic");
    assert.equal(data.content, "Test Content");
    assert.equal(Number(data.yes), 5000000);
    assert.equal(Number(data.no), 100000);
    // status is voting
    assert.equal(Number(data.status), 1);
    // current result is true
    assert.equal(data.result, true);
  });

  it("should lock voting amount after vote", async () => {
    await faucetAndApprove(accounts[4]);
    await governance.deposit({ from: accounts[4] });

    const beforeAmount = Number(web3.utils.fromWei(await governance.availableDepositsOf(accounts[4])));

    await governance.vote(proposalId, web3.utils.fromAscii("VOTE_NO"), { from: accounts[4] });

    const afterAmount = Number(web3.utils.fromWei(await governance.availableDepositsOf(accounts[4])));
    assert.equal(afterAmount, 0);
  });

  it("should lock proposer amount", async () => {
    assert.equal(Number(await governance.availableDepositsOf(accounts[2])), 0);
  });

  it("should reject second vote for proposal", async () => {
    await faucetAndApprove(accounts[4]);
    await governance.deposit({ from: accounts[4] });

    await expectRevert(governance.vote(proposalId, web3.utils.fromAscii("VOTE_NO"), { from: accounts[4] }), "Gov#__vote: You already voted to this proposal");
  });

  it("should remove lock on cancel if not proposer", async () => {
    await governance.vote(proposalId, web3.utils.fromAscii("VOTE_CANCEL"), { from: accounts[4] });
    const amount = await governance.availableDepositsOf(accounts[4])
    assert.equal(Number(web3.utils.fromWei(amount)), 100000)

    await faucetAndApprove(accounts[0])
    await expectRevert(governance.vote(proposalId, web3.utils.fromAscii("VOTE_YES"), {from: accounts[2]}), "Gov#__vote: Proposers cannot vote their own proposals")
  });

  it("Proposer cannot create another proposal if has an active one", async () => {
    await faucet5mAndApprove(accounts[2])
    await expectRevert(depositAndPropose(dayInSec * 4, testTopic, testContent, accounts[2]), "Gov#propose: You have an active proposal")
  })

  it("should finish proposal and clean locks", async () => {
    await helpers.advanceTimeAndBlock(9 * 24 * 60 * 60);
    const tx = await governance.finishProposal(proposalId);

    assert.equal(Number(await governance.lockedDepositsOf(accounts[2])), 0)

    await helpers.advanceTimeAndBlock(6 * 24 * 60 * 60);

    assert.equal(Number(await governance.lockedDepositsOf(accounts[2])), 0)

    const args = tx.logs[0].args;
    assert.equal(args.result, true);
    assert.equal(Number(args.yes), 5000000);
    assert.equal(Number(args.no), 200000);
    assert.equal(args.proposeID, proposalId);
  });

  it("Proposer can create 2 proposal per month", async () => {
    const tx = await depositAndPropose(dayInSec * 4, testTopic, testContent, accounts[2]);
    const proposal = tx.logs[tx.logs.length - 2];

    proposalId = proposal.args["proposeID"];
    await helpers.advanceTimeAndBlock(10 * 24 * 60 * 60);

    await governance.finishProposal(proposalId)

    await expectRevert(depositAndPropose(dayInSec * 4, testTopic, testContent, accounts[2]), "Gov#propose: Cannot create more proposals this month")
  });

  async function depositAndPropose(secs, topic, content, from) {
    return governance.propose(secs, topic, content, { from });
  }

  async function faucetAndApprove(account) {
    await ankr.faucet({ from: account });
    await ankr.approve(governance.address, helpers.wei(100000), { from: account });
  }

  async function faucet5mAndApprove(account) {
    await ankr.faucet5m({ from: account });
    await ankr.approve(governance.address, helpers.wei(5000000), { from: account });
  }
});