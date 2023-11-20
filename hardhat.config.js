require("@nomicfoundation/hardhat-toolbox");
require("hardhat-docgen");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
    solidity: "0.8.19",
    defaultNetwork: "hardhat",
    networks: {
        localhost: {
            url: "http://127.0.0.1:8545/",
            chainId: 31337,
        },
    },
    gasReporter: {
        enabled: process.env.REPORT_GAS || false,
    },
    docgen: {
        path: "./docs",
        clear: true, //clears the content of the ouptut directory (in this  case, ./docs before generating new docs)
        runOnCompile: true,
    },
};
