const fs               = require("fs");
const path             = require("path");
const helpers          = require("./helpers/helpers");
const { expectRevert } = require("@openzeppelin/test-helpers");
const StkrPool         = artifacts.require("StkrPool");

contract("Global Pool", function(accounts) {
  let ankr;
  let staking;
  let micropool;
  let owner;
  let systemParameters;
  let firstStaking;
  let depositData;

  before(async function() {
    pool = await StkrPool.deployed();

    const data = fs.readFileSync(path.join(__dirname, "/helpers/depositdata"), "utf8")
      .slice(8);

    depositData =
      web3.eth.abi.decodeParameters(["bytes", "bytes", "bytes", "bytes32"], data);

    owner = accounts[0];
  });
}