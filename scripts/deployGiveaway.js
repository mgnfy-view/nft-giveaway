const { ethers, network } = require("hardhat");
const { developmentChainIds, networkConfig } = require("../helper.config.js");
const verify = require("../utils/verify.js");
const deployMocks = require("./deployMocks.js");

const deployGiveaway = async function () {
    const isDevelopmentChain = developmentChainIds.includes(network.config.chainId);
    const [user0, user1] = await ethers.getSigners();
    const NFT_METADATA_HASH = process.env.NFT_METADATA_HASH;
    let vrfCoordinatorV2Mock;
    let subscriptionId, keyHash, callbackGasLimit, interval, vrfCoordinatorAddress;

    if (isDevelopmentChain) {
        // creating the vrf subscription
        console.log("Development chain detected");
        vrfCoordinatorV2Mock = await deployMocks();
        vrfCoordinatorAddress = await vrfCoordinatorV2Mock.getAddress();
        console.log("Creating subscription");
        await vrfCoordinatorV2Mock.createSubscription({ from: user0.address });
        subscriptionId = 1;
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

    await vrfCoordinatorV2Mock.addConsumer(subscriptionId, await giveaway.getAddress());

    if (!isDevelopmentChain && process.env.ETHERSCAN_API_KEY) {
        await verify(await giveaway.getAddress());
    }

    if (isDevelopmentChain) return { giveaway, vrfCoordinatorV2Mock };
    else return giveaway;
};

module.exports = deployGiveaway;
