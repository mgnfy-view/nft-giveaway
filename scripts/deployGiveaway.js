const { ethers, network } = require("hardhat");
const { developmentChainIds, networkConfig } = require("../helper.config.js");
const verify = require("../utils/verify.js");
const deployMocks = require("./deployMocks.js");

const deployGiveaway = async function () {
    const isDevelopmentChain = developmentChainIds.includes(network.config.chainId);
    const [user0] = await ethers.getSigners();
    const NFT_METADATA_HASH = process.env.NFT_METADATA_HASH;
    let vrfCoordinatorV2Mock, vrfCoordinatorAddress;
    let subscriptionId, keyHash, callbackGasLimit, interval;

    if (isDevelopmentChain) {
        // creating the vrf subscription
        console.log("Development chain detected");
        vrfCoordinatorV2Mock = await deployMocks();
        vrfCoordinatorAddress = await vrfCoordinatorV2Mock.getAddress();
        console.log("Creating subscription");
        await vrfCoordinatorV2Mock.createSubscription({ from: user0.address });
        subscriptionId = 1; // the vrfCoordinatorV2Mock keeps a count of all subscriptions, starting from 1. Since we are the first ones to create a subscription here, it's going to be 1
        console.log("Subscription created with subscription ID 1");
        // funding the subscription
        // our mock makes it so we don't actually have to worry about sending fund
        console.log("Funding subscription with 50 LINK");
        await vrfCoordinatorV2Mock.fundSubscription(subscriptionId, ethers.parseEther("50.0"));
        ({
            31337: { keyHash, callbackGasLimit, interval },
        } = networkConfig);
    } else {
        ({
            11155111: { subscriptionId, vrfCoordinatorAddress, keyHash, callbackGasLimit, interval },
        } = networkConfig);
    }
    const constructorArgs = [
        subscriptionId,
        keyHash,
        callbackGasLimit,
        interval,
        vrfCoordinatorAddress,
        `ipfs://${NFT_METADATA_HASH}`,
    ];

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

    if (isDevelopmentChain) {
        await vrfCoordinatorV2Mock.addConsumer(subscriptionId, await giveaway.getAddress()); // add our giveaway contract as the consumer
        return { giveaway, vrfCoordinatorV2Mock };
    } else {
        if (process.env.ETHERSCAN_API_KEY) await verify(await giveaway.getAddress());
        return giveaway;
    }
};

module.exports = deployGiveaway;
