require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.28", // or the version that satisfies all your contracts
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
    },
    localhost: {
      url: "http://127.0.0.1:8545", // Ganache default port
      chainId: 1337, // Ganache default chain ID
     
    }
  }
};