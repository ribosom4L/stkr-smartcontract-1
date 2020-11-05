const fs                            = require("fs");
const path                          = require("path");
const helpers                       = require("./helpers/helpers");
const { expectRevert, expectEvent } = require("@openzeppelin/test-helpers");
const StkrPool                      = artifacts.require("StkrPool");

contract("Global Pool", function(accounts) {
  let pool;
  let depositData;

  before(async function() {
    pool = await StkrPool.deployed();

    const data = fs.readFileSync(path.join(__dirname, "/helpers/depositdata"), "utf8")
      .slice(8);

    depositData =
      web3.eth.abi.decodeParameters(["bytes", "bytes", "bytes", "bytes32"], data);

    owner = accounts[0];
  });

  it("should let users to stake", async () => {
    const tx = await pool.stake({
      from:  accounts[0],
      value: helpers.amount(10)
    });

    expectEvent(tx, 'StakePending', {staker: accounts[0], pool: "0", amount: helpers.gwei(10)})
  });

  it('should close pool after 32 eth', async() => {
    const tx = await pool.stake({
      from:  accounts[0],
      value: helpers.amount(35)
    });

    console.log(tx.logs)
  })
  //
  // it('should let users to stake', function() {
  //
  // })
  //
  // it('should let users to stake', function() {
  //
  // })
});