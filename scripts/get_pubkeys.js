const Web3 = require('web3')
const g = require('../json_abi/GlobalPool.json')
const fs = require('fs')
const web3 = new Web3('https://mainnet.infura.io/v3/167ee585da3c42e4a2a9c42476f9000f')

const contract = new web3.eth.Contract(g, "0x84db6ee82b7cf3b47e8f19270abde5718b936670")

contract.getPastEvents("PoolOnGoing", {fromBlock: 0}).then(xx => {
  const filtered = xx.map(x => x.returnValues.pool)
  fs.writeFileSync('filtered.json', JSON.stringify(filtered))
})

