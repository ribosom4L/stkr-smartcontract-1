const Web3 = require('web3')
const g = require('../json_abi/GlobalPool.json')
const fs = require('fs')
const web3 = new Web3(process.env.MAINNET_PROVIDER)

const contract = new web3.eth.Contract(g, "0x84db6ee82b7cf3b47e8f19270abde5718b936670")

contract.getPastEvents("PoolOnGoing", {fromBlock: 0}).then(xx => {
  const filtered = xx.map(x => x.returnValues.pool)
  fs.writeFileSync('filtered_pubkeys.json', JSON.stringify(filtered))
})

