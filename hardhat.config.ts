import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@nomicfoundation/hardhat-chai-matchers";
import "@nomiclabs/hardhat-ethers";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
// import "solidity-coverage"; TODO: figure out how to report coverage
import "hardhat-abi-exporter";
import "@openzeppelin/hardhat-upgrades";
import 'solidity-coverage';

dotenv.config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.33",
        settings: {
          evmVersion: "cancun",
          optimizer: {
            enabled: true,
            runs: 1,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
    ropsten: {
      url: process.env.ROPSTEN_URL || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      allowUnlimitedContractSize: true,
    },
    celo: {
      url: "https://forno.celo.org",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      allowUnlimitedContractSize: true,
      chainId: 42220,
    },
    celoSepolia: {
      url: "https://celo-sepolia.drpc.org",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      chainId: 11142220,
    },
    sepolia: {
      url: process.env.SEPOLIA_URL || "https://ethereum-sepolia-rpc.publicnode.com",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      chainId: 11155111,
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: {
      celo: "P2NMSA6X7YIQ6MCQ1D5WSQ2QQNDC2QNHX8",
      sepolia: process.env.ETHERSCAN_API_KEY || "",
    },
  },
  abiExporter: {
    path: "./data/abi",
    runOnCompile: true,
    clear: true,
    flat: true,
    format: "json",
    only: [":ERC20$", "NashEscrow"],
    spacing: 2,
  },
};

export default config;
