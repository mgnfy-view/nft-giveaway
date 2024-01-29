const { ethers, network } = require("hardhat");
const { networkConfig } = require("../helper.config.js");

const deployMocks = async function () {
    const [user0] = await ethers.getSigners();
    const BASE_FEE = ethers.parseEther("0.25"); // the premium field value taken from that of sepolia testnet
    const GAS_PRICE_LINK = "1000000000"; // arbitrary link per gas price

    const vrfCoordinatorV2Mock = await ethers.deployContract(
        "VRFCoordinatorV2Mock",
        [BASE_FEE, GAS_PRICE_LINK],
        user0,
    );
    await vrfCoordinatorV2Mock.waitForDeployment();
    console.log(
        `vrfCoordinatorV2Mock deployed at address ${await vrfCoordinatorV2Mock.getAddress()}`,
    );
    console.log(
        `Waiting for ${
            networkConfig[network.config.chainId]?.blockConfirmations ?? 1
        } block confirmation/confirmations`,
    );
    await vrfCoordinatorV2Mock
        .deploymentTransaction()
        .wait(networkConfig[network.config.chainId]?.blockConfirmations ?? 1);
    console.log("Done Deploying");

    return { vrfCoordinatorV2Mock };
};

module.exports = deployMocks;
