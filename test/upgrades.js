const Ankr    = artifacts.require("Ankr");
const helpers = require("./helpers/helpers");

contract("Upgrades", async function(accounts) {
  let ankr;
  let owner;

  before(async () => {
    ankr  = await Ankr.deployed();
    owner = accounts[0];
  });

  it("should test", async () => {

  });
});
