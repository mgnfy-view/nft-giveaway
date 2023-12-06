const { ethers, network } = require("hardhat");
const { developmentChainIds, networkConfig } = require("../helper.config.js");
const verify = require("../utils/verify.js");

const deploy = async function () {
    const isDevelopmentChain = developmentChainIds.includes(network.config.chainId);

    if (isDevelopmentChain) {
        // todo: deploy mocks
    }

    const [user0, user1] = await ethers.getSigners();
    const {
        11155111: { subscriptionId, keyHash, callbackGasLimit, interval, vrfCoordinatorAddress },
    } = networkConfig;
    const constructorArgs = [subscriptionId, keyHash, callbackGasLimit, interval, vrfCoordinatorAddress];
    const giveaway = await ethers.deployContract("Giveaway", constructorArgs, user0);

    await giveaway.waitForDeployment();
    console.log(`Giveaway contract deployed at address ${await giveaway.getAddress()}`);
    console.log(
        `Waiting for ${
            networkConfig[network.config.chainId]?.blockConfirmations ?? 1
        } block confirmation/confirmations`,
    );
    const txReceipt = await giveaway
        .deploymentTransaction()
        .wait(networkConfig[network.config.chainId]?.blockConfirmations ?? 1);
    console.log("Done Deploying");

    if (!isDevelopmentChain && process.env.ETHERSCAN_API_KEY) {
        await verify(await giveaway.getAddress());
    }

    return { giveaway, user1 };
};

deploy().catch((error) => console.log(error));

module.exports = deploy;
