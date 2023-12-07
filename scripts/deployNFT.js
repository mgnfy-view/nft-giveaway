const { ethers, network } = require("hardhat");
const { developmentChainIds, networkConfig } = require("../helper.config.js");

const deployNFT = async function () {
    const NFT_METADATA_HASH = process.env.NFT_METADATA_HASH;
    const isDevelopmentChain = developmentChainIds.includes(network.config.chainId);

    const [user0] = await ethers.getSigners();
    console.log(`NFT is being deployed by ${user0.address}`);
    const nft = await ethers.deployContract("AwesomeNFT", [`ipfs://${NFT_METADATA_HASH}`], user0);
    await nft.waitForDeployment();
    console.log(`NFT deployed at address ${await nft.getAddress()}`);
    console.log(
        `Waiting for ${
            networkConfig[network.config.chainId]?.blockConfirmations ?? 1
        } block confirmation/confirmations`,
    );
    const txReceipt = await nft
        .deploymentTransaction()
        .wait(networkConfig[network.config.chainId]?.blockConfirmations ?? 1);
    console.log("Done Deploying");

    return nft;
};

module.exports = deployNFT;
