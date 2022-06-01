require("dotenv").config();

require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-web3");
require("@nomiclabs/hardhat-etherscan");

require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-ethers/signers");
require("@openzeppelin/hardhat-upgrades");

require("hardhat-deploy");
require("hardhat-deploy-ethers");
require("hardhat-gas-reporter");
require("hardhat-abi-exporter");

require("solidity-coverage");

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more
task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();
  accounts.forEach((account) => {
    console.log(account.address);
  });
});

task("balances", "Prints the list of ETH account balances", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();
  for (const account of accounts) {
    const balance = await hre.ethers.provider.getBalance(account.address);
    console.log(`${account.address} has balance ${balance.toString()}`);
  }
});

const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

module.exports = {
  defaultNetwork: "hardhat",

  solidity: {
    compilers: [
      {
        version: "0.8.7",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
            details: {
              yul: false
            }
          },
        },
      },
    ],
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    hardhat: {
      // forking: {
      //   url: "https://eth-rinkeby.alchemyapi.io/v2/" + ALCHEMY_API_KEY,
      // },
    },
    mainnet: {
      url: "https://eth-mainnet.alchemyapi.io/v2/" + ALCHEMY_API_KEY,
      accounts: [`${PRIVATE_KEY}`],
      gasMultiplier: 1.2,
      deploy: ["deploy/mainnet"],
    },
    rinkeby: {
      url: "https://eth-rinkeby.alchemyapi.io/v2/" + ALCHEMY_API_KEY,
      accounts: [`${PRIVATE_KEY}`],
      gasMultiplier: 1.5,
      deploy: ["deploy/rinkeby"],
    }
  },
  namedAccounts: {
    deployer: 0,
    member1: 1,
    member2: 2,
    minter1: 3,
    minter2: 4,
  },
  gasReporter: {
    currency: "USD",
    gasPrice: 100,
    enabled: process.env.REPORT_GAS ? true : false,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    maxMethodDiff: 10,
  },
  abiExporter: {
    clear: true,
    flat: true,
    spacing: 2,
    runOnCompile: true,
    only: ["NFTiff"],
  },
  mocha: {
    timeout: 0,
  },
  paths: {
    deploy: "deploy/mainnet",
    sources: "./contracts",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};
