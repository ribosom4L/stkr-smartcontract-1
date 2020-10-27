const { deployProxy } = require("@openzeppelin/truffle-upgrades");
const { scripts, ConfigManager } = require('@openzeppelin/cli');
const { add, push, create } = scripts;

module.exports = async (deployer, networkName, from, contract, args = []) => {

  const { network, txParams } = await ConfigManager.initNetworkConfiguration({ network: networkName, from })

  await add({ contractsData: [{ name: contract.contractName, alias: contract.contractName }] });
  // const a = await deployProxy(contract, args, { deployer });
  await push({ network, txParams, deployProxyAdmin: true, deployProxyFactory: true });

  return await contract.deployed()
}