const { fromWei } = require("@openzeppelin/cli/lib/utils/units");
const helpers = require("./helpers/helpers");
const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const { upgradeProxy, admin } = require("@openzeppelin/truffle-upgrades");
const Governance = artifacts.require("Governance");
const ANKR = artifacts.require("ANKR");
const AnkrDeposit = artifacts.require("AnkrDeposit");

contract("Governance", function(accounts) {
  let governance, ankr, ankrDeposit;
  const ankrLimit = web3.utils.toWei(5000000 + "");
  const dayInSec = 24 * 60 * 60;
  const testTopic = "Test Topic";
  const testContent = "Test Content";
  before(async function() {
    governance = await Governance.deployed();
    ankr = await ANKR.deployed();
    ankrDeposit = await AnkrDeposit.deployed();
  });

  it("Proposals should be created with enough amount of ankr", async () => {
    await expectRevert(depositAndPropose(dayInSec * 2, testTopic, testContent), "Timespan lower than limit");
    await expectRevert(depositAndPropose(dayInSec * 8, testTopic, testContent), "Timespan greater than limit");
    await expectRevert(depositAndPropose(dayInSec * 4, testTopic, testContent), "You dont have enough amount to freeze ankr");
    // get 5m ankr tokens 0
    await ankr.faucet5m({ from: accounts[0] });

    await ankr.approve(ankrDeposit.address, ankrLimit);
    const tx = await depositAndPropose(dayInSec * 4, testTopic, testContent);
  });

  it("Votes should affect the proposal correctly", async () => {
    await ankr.faucet5m({ from: accounts[2] });

    await ankr.approve(ankrDeposit.address, ankrLimit);
    const tx = await depositAndPropose(dayInSec * 4, testTopic, testContent);
    const vote = tx.logs[1];
    const proposal = tx.logs[0];
    assert.equal(Number(web3.utils.fromWei(vote.args.votes.toString())), 20000000);

    const proposalId = proposal.args["proposeID"];

    await ankr.faucet({ from: accounts[1] });

    await ankr.approve(ankrDeposit.address, ankrLimit, { from: accounts[1] });

    const txVote = await governance.depositAndVote(proposalId, web3.utils.fromAscii("VOTE_YES"), { from: accounts[1] });
  });



  async function depositAndPropose(secs, topic, content) {
    return governance.depositAndPropose(secs, topic, content);
  }
});