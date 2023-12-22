const { ethers, network } = require("hardhat");
const deployGiveaway = require("./deployGiveaway.js");
const { developmentChainIds, networkConfig } = require("../helper.config.js");

const deployMain = async function () {
    const isDevelopmentChain = developmentChainIds.includes(network.config.chainId);
    const [user0] = await ethers.getSigners();
    let giveaway, vrfCoordinatorV2Mock;

    if (isDevelopmentChain) {
        ({ giveaway, vrfCoordinatorV2Mock } = await deployGiveaway());

        return { giveaway, vrfCoordinatorV2Mock };
    } else {
        giveaway = await deployGiveaway();

        return { giveaway };
    }
};

module.exports = deployMain;
