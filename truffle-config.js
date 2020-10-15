const PrivateKeyProvider = require("truffle-privatekey-provider");
var HDWalletProvider = require("truffle-hdwallet-provider");

const privateKey =
  "5667c2a27bf6c4daf6091094009fa4f30a6573b45ec836704eb20d5f219ce778";

// Or, pass an array of private keys, and optionally use a certain subset of addresses
var privateKeys = [
  "3f841bf589fdf83a521e55d51afddc34fa65351161eead24f064855fc29c9580",
  "9549f39decea7b7504e15572b2c6a72766df0281cea22bd1a3bc87166b1ca290",
];
var provider = new HDWalletProvider(privateKeys, "http://localhost:8545", 0, 2);



module.exports = {


  networks: {

    // development: {
    //   host: "127.0.0.1", // Localhost (default: none)
    //   port: 7545, // Standard Ethereum port (default: none)
    //   network_id: "*", // Any network (default: none)
    // },
    // Another network with more advanced options...
    // advanced: {
    // port: 8777,             // Custom port
    // network_id: 1342,       // Custom network
    // gas: 8500000,           // Gas sent with each transaction (default: ~6700000)
    // gasPrice: 20000000000,  // 20 gwei (in wei) (default: 100 gwei)
    // from: <address>,        // Account to send txs from (default: accounts[0])
    // websockets: true        // Enable EventEmitter interface for web3 (default: false)
    // },
    ropsten: {
      provider: () =>
        new HDWalletProvider(privateKey, "https://ropsten.infura.io/v3/167ee585da3c42e4a2a9c42476f9000f"),
      network_id: 3, // Ropsten's id
      gas: 5500000, // Ropsten has a lower block limit than mainnet
      timeoutBlocks: 50, // # of blocks before a deployment times out  (minimum/default: 50)
      // skipDryRun: true, // Skip dry run before migrations? (defaultü false for public nets)
    },
    goerli: {
      provider: () =>
        new HDWalletProvider(
          "bc8d7fd98d1ecf0f0d79e23ad3d5f9f9a1178db7cf636825b1f74e2c12311262",
          `https://goerli.infura.io/v3/167ee585da3c42e4a2a9c42476f9000f`
        ),
      network_id: 5, // goerli's id
      gas: 5500000, // goerli has a lower block limit than mainnet
      timeoutBlocks: 50, // # of blocks before a deployment times out  (minimum/default: 50)
    },
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.6.8", // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      // settings: {
      //  optimizer: {
      //    enabled: false,
      //    runs: 200
      //  }
      // }
    },
  },
};
