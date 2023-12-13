const { ethers, network } = require("hardhat");
const { developmentChainIds, networkConfig } = require("../helper.config.js");
const deployGiveaway = require("./deployGiveaway.js");

const deployMain = async function () {
    const isDevelopmentChain = developmentChainIds.includes(network.config.chainId);
    const [user0, user1] = await ethers.getSigners();
    let giveaway, vrfCoordinatorV2Mock;

    if (isDevelopmentChain) {
        ({ giveaway, vrfCoordinatorV2Mock } = await deployGiveaway());

        return { giveaway, vrfCoordinatorV2Mock, user0, user1 };
    } else {
        giveaway = await deployGiveaway();

        return { giveaway, user0, user1 };
    }
};

module.exports = deployMain;
