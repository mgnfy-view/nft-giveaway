const { ethers, network } = require("hardhat");
const { developmentChainIds, networkConfig } = require("../helper.config.js");
const deployNFT = require("./deployNFT.js");
const deployGiveaway = require("./deployGiveaway.js");

const deployMain = async function () {
    const isDevelopmentChain = developmentChainIds.includes(network.config.chainId);
    const [user0, user1] = await ethers.getSigners();
    let nft, giveaway, VRFCoordinatorV2Mock;

    nft = await deployNFT();
    if (isDevelopmentChain) {
        ({ giveaway, VRFCoordinatorV2Mock } = await deployGiveaway(await nft.getAddress()));
    } else {
        ({ giveaway } = await deployGiveaway(await nft.getAddress()));
        return { nft, giveaway };
    }

    nft.transferOwnership(await giveaway.getAddress());

    if (isDevelopmentChain) return { nft, giveaway, VRFCoordinatorV2Mock };
    else return { nft, giveaway };
};

deployMain().catch((error) => console.log(error));
