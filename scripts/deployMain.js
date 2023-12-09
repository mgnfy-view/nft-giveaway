const { ethers, network } = require("hardhat");
const { developmentChainIds, networkConfig } = require("../helper.config.js");
const deployGiveaway = require("./deployGiveaway.js");

const deployMain = async function () {
    const isDevelopmentChain = developmentChainIds.includes(network.config.chainId);
    const [user0, user1, user2] = await ethers.getSigners();
    let giveaway, vrfCoordinatorV2Mock;

    if (isDevelopmentChain) {
        ({ giveaway, vrfCoordinatorV2Mock } = await deployGiveaway());
    } else {
        giveaway = await deployGiveaway();
    }

    if (isDevelopmentChain) return { giveaway, vrfCoordinatorV2Mock, user0, user1, user2 };
    else return { giveaway, user0, user1, user2 };
};

module.exports = deployMain;
