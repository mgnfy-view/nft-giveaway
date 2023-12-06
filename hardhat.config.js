require("@nomicfoundation/hardhat-toolbox");
require("hardhat-docgen");
require("dotenv").config();

let SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL;
let REPORT_GAS = process.env.REPORT_GAS;
let ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;
let PRIVATE_ACCOUNT_1 = process.env.PRIVATE_ACCOUNT_1;
let PRIVATE_ACCOUNT_2 = process.env.PRIVATE_ACCOUNT_2;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: {
        version: "0.8.20",
    },
    defaultNetwork: "hardhat",
    networks: {
        localhost: {
            url: "http://127.0.0.1:8545/",
            chainId: 31337,
        },
        sepolia: {
            url: SEPOLIA_RPC_URL,
            accounts: [PRIVATE_ACCOUNT_1, PRIVATE_ACCOUNT_2],
            chainId: 11155111,
        },
    },
    gasReporter: {
        enabled: REPORT_GAS || false,
    },
    etherscan: {
        apiKey: ETHERSCAN_API_KEY,
    },
    docgen: {
        path: "./docs",
        clear: true, //clears the content of the ouptut directory (in this  case, ./docs before generating new docs)
        runOnCompile: false,
    },
};
