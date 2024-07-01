import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
// import "@nomiclabs/hardhat-etherscan";
import "@openzeppelin/hardhat-upgrades";
import "@nomicfoundation/hardhat-verify";
import "hardhat-contract-sizer";
import * as dotenv from "dotenv";

const path = ".env." + (process.env.NODE_ENV ? process.env.NODE_ENV : "dev");
dotenv.config({ path });

const accounts = [process.env.PRIVATE_KEY as string];

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 100,
      },
      viaIR: true,
    },
  },
  defaultNetwork: process.env.NODE_ENV == "prod" ? "blast" : "hardhat",
  networks: {
    // for mainnet
    mainnet: {
      url: "https://special-stylish-sailboat.quiknode.pro/c3ac0bb44dde426be6861aa563ba8c10cdd40900/",
      accounts,
    },
    // for testnet
    goerli: {
      url: "https://goerli.infura.io/v3/bf5ac8481ba949a29e60f97735f17bde",
      accounts,
    },
    blastSepolia: {
      url: "https://blast-sepolia.blockpi.network/v1/rpc/public",
      accounts,
    },
    blast: {
      url: "https://rpc.blast.io",
      accounts,
    },
  },
  etherscan: {
    apiKey: {
      goerli: "U9B9CIHXBY14C9JW3YN9W1JES2MJT63ZI2",
      mainnet: "U9B9CIHXBY14C9JW3YN9W1JES2MJT63ZI2",
      blastSepolia: "blast_sepolia",
      blast: "56M5MK9TIH184KFBUPKIKYZQF2G9KBA2MV",
    },
    customChains: [
      {
        network: "blastSepolia",
        chainId: 168587773,
        urls: {
          apiURL: "https://api-sepolia.blastscan.io/api",
          browserURL:
            "https://api.routescan.io/v2/network/testnet/evm/168587773/etherscan",
        },
      },
      {
        network: "blast",
        chainId: 81457,
        urls: {
          apiURL: "https://api.blastscan.io/api",
          browserURL:
            "https://api.routescan.io/v2/network/mainnet/evm/81457/etherscan",
        },
      },
    ],
  },
};

export default config;
