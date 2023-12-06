const { ethers, network } = require("hardhat");
const { developmentChainIds, networkConfig } = require("../helper.config.js");

const deploy = async function () {
    const isDevelopmentChain = developmentChainIds.includes(network.config.chainId);
    const [user0, user1] = await ethers.getSigners();
    console.log(`AwesomeNFT is being deployed by ${user0.address}`);
    const awesomeNFT = await ethers.deployContract("AwesomeNFT", ["https://test.com"], user0);
    await awesomeNFT.waitForDeployment();
    console.log(`AwesomeNFT deployed at address ${await awesomeNFT.getAddress()}`);
    console.log(
        `Waiting for ${
            networkConfig[network.config.chainId]?.blockConfirmations ?? 1
        } block confirmation/confirmations`,
    );
    const txReceipt = await awesomeNFT
        .deploymentTransaction()
        .wait(networkConfig[network.config.chainId]?.blockConfirmations ?? 1);
    console.log("Done Deploying");
};

deploy().catch((error) => console.log(error));

module.exports = deploy;
