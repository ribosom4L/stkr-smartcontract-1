const fs = require('fs')
const path = require('path')

const buildPath = path.join(__dirname, '../build/contracts')
const data = {}

fs.readdirSync(buildPath).forEach(val => {
  const { contractName, abi, networks } = require(path.join(buildPath, val))
  if (!Object.keys(networks).length) return;

  fs.writeFileSync(path.join(__dirname, `../json_abi/${contractName}.json`), JSON.stringify(abi))
  data[contractName] = {}

  for (const networkData of Object.entries(networks)) {
    data[contractName][networkData[0]] = networkData[1].address
  }
})

fs.writeFileSync(path.join(__dirname, `../addresses.json`), JSON.stringify(data))
