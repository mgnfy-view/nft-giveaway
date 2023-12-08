const { ethers, network } = require("hardhat");
const { developmentChainIds, networkConfig } = require("../helper.config.js");
const deployGiveaway = require("./deployGiveaway.js");

const deployMain = async function () {
    const isDevelopmentChain = developmentChainIds.includes(network.config.chainId);
    const [user0, user1] = await ethers.getSigners();
    let giveaway, vrfCoordinatorV2Mock;

    if (isDevelopmentChain) {
        ({ giveaway, vrfCoordinatorV2Mock } = await deployGiveaway());
    } else {
        ({ giveaway } = await deployGiveaway());
    }

    if (isDevelopmentChain) return { giveaway, vrfCoordinatorV2Mock, user0, user1 };
    else return { giveaway, user0, user1 };
};

deployMain().catch((error) => console.log(error));

module.exports = deployMain;
