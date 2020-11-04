require("dotenv").config();

const HDWalletProvider = require("truffle-hdwallet-provider");
const privateKey       = process.env.DEPLOYMENT_KEY;

module.exports = {
  networks: {
    // development: {
    //   host: "127.0.0.1",
    //   port: 8545,
    //   network_id: "*",
    // },
    develop: {
      port: 8545,
      defaultEtherBalance: 5000,
    },
    ropsten: {
      provider:      () =>
                       new HDWalletProvider(
                         privateKey,
                         "https://ropsten.infura.io/v3/167ee585da3c42e4a2a9c42476f9000f"
                       ),
      network_id:    3, // Ropsten's id
      gas:           5500000, // Ropsten has a lower block limit than mainnet
      timeoutBlocks: 50, // # of blocks before a deployment times out  (minimum/default:
                         // 50)
      skipDryRun:    true // Skip dry run before migrations? (defaultü false for public
      // nets)
    },
    goerli:  {
      provider:      () =>
                       new HDWalletProvider(
                         privateKey,
                         `https://goerli.infura.io/v3/167ee585da3c42e4a2a9c42476f9000f`
                       ),
      network_id:    5, // goerli's id
      gas:           8000000, // goerli has a lower block limit than mainnet
      timeoutBlocks: 50, // # of blocks before a deployment times out  (minimum/default:
                         // 50)
      skipDryRun:    true // Skip dry run before migrations? (defaultü false for public
      // nets)
    }
  },
  // Set default mocha options here, use special reporters etc.
  mocha:    {
    // timeout: 100000
  },
  // Configure your compilers
  compilers: {
    solc: {
      version:  "0.6.8", // Fetch exact version from solc-bin (default: truffle's version)
      docker: false,        // Use "0.5.1" you've installed locally with docker
      settings: {
        optimizer: {
          enabled: false,
          runs:    200
        }
      }
    }
  }
};