const Web3 = require("web3");
const fs = require("fs");
const path = require("path");
const abi = require("../json_abi/GlobalPool.json");
const addresses = require("../addresses.json");

async function run() {
  const web3 = new Web3("https://mainnet.infura.io/v3/167ee585da3c42e4a2a9c42476f9000f");

  const args = process.argv.slice(2);
  if (args.length < 1) {
    console.log("Block number missing");
    process.exit();
  }

  const blockNum = args[0];

  const stakes = {};

  const contract = new web3.eth.Contract(abi, "0x84db6eE82b7Cf3b47E8F19270abdE5718B936670");

  const stakeEvents = await contract.getPastEvents("StakePending", { fromBlock: 0, toBlock: blockNum });
  const unstakeEvents = await contract.getPastEvents("StakeRemoved", { fromBlock: 0, toBlock: blockNum });
  const confirmEvents = await contract.getPastEvents("StakeConfirmed", { fromBlock: 0, toBlock: blockNum });

  let g = 0;
  for (const event of stakeEvents) {
    const values = event.returnValues;

    const stakeAmount = (stakes[values.staker] ? Number(stakes[values.staker].stake) : 0) + Number(web3.utils.fromWei(values.amount.toString()));
    const unstakeAmount = stakes[values.staker] ? Number(stakes[values.staker].unstake) : 0;
    const transactions = stakes[values.staker] ? stakes[values.staker].stakeTransactions : [];

    transactions.push(event.transactionHash);

    const total = stakeAmount - unstakeAmount;
    if (!stakes[values.staker]) {
      // g++
    }
    stakes[values.staker] = {
      stake: stakeAmount,
      unstake: unstakeAmount,
      total,
      stakeTransactions: transactions,
      unstakeTransactions: []
    };
  }
  for (const event of unstakeEvents) {
    const values = event.returnValues;

    const unstakeAmount = Number(stakes[values.staker].unstake) + Number(web3.utils.fromWei(values.amount.toString()));
    const stakeAmount = Number(stakes[values.staker].stake);
    const transactions = stakes[values.staker].unstakeTransactions;

    transactions.push(event.transactionHash);

    const total = stakeAmount - unstakeAmount;

    stakes[values.staker] = {
      stake: stakeAmount,
      unstake: unstakeAmount,
      total,
      confirmed: 0,
      stakeTransactions: stakes[values.staker].stakeTransactions,
      unstakeTransactions: transactions,
      confirmTransactions: []
    };
  }

  for (const event of confirmEvents) {
    const values = event.returnValues;

    stakes[values.staker].confirmed += Number(values.amount);
    stakes[values.staker].confirmTransactions.push(event.transactionHash)
  }
  let e = 0;
  for (const staker in stakes) {

    if (stakes[staker].total > 0) {
      g++
    }
    else {
      e++
    }
  }

  const p = path.join(__dirname, "../stakers.json");
  fs.writeFileSync(p, JSON.stringify(stakes));
  console.log("Total stakers:" + g + " unstaked: " + e)
  console.log("Stakers written to: " + p);
}

run();