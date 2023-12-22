const { ethers, network } = require("hardhat");
const { developmentChainIds, networkConfig } = require("../helper.config.js");
const deployMocks = require("./deployMocks.js");
const verify = require("../utils/verify.js");
const ERC20ABI = require("../utils/ERC20ABI.js");

const deployGiveaway = async function () {
    const isDevelopmentChain = developmentChainIds.includes(network.config.chainId);
    const [user0] = await ethers.getSigners();
    const NFT_METADATA_HASH = process.env.NFT_METADATA_HASH;
    let vrfCoordinatorV2Mock, vrfCoordinatorAddress;
    let upkeepContractAddress;
    let keyHash, callbackGasLimit, interval, linkTokenAddress;

    if (isDevelopmentChain) {
        // creating the vrf subscription
        console.log("Development chain detected");
        ({ vrfCoordinatorV2Mock } = await deployMocks());
        vrfCoordinatorAddress = await vrfCoordinatorV2Mock.getAddress();
        linkTokenAddress = "0x779877A7B0D9E8603169DdbD7836e478b4624789"; // for unit testing, we really don't care about the LINK token contract address. Here, I've pasted Sepolia's LINK token contract address
        upkeepContractAddress = "0xb0E49c5D0d05cbc241d68c05BC5BA1d1B7B72976"; // again we do not care about the registrar's address for a local testing environemnt, I've used Sepolia's registrar's address here
        ({
            31337: { keyHash, callbackGasLimit, interval },
        } = networkConfig);
    } else {
        const chainId = network.config.chainId;
        ({ keyHash, callbackGasLimit, interval, vrfCoordinatorAddress, linkTokenAddress, upkeepContractAddress } =
            networkConfig[chainId]);
    }
    const constructorArgs = [
        keyHash,
        callbackGasLimit,
        interval,
        vrfCoordinatorAddress,
        `https://ipfs.io/ipfs/${NFT_METADATA_HASH}`,
        linkTokenAddress,
        upkeepContractAddress,
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
        console.log("Funding subscription");
        await vrfCoordinatorV2Mock.fundSubscription(
            await giveaway.getSubscriptionId(),
            networkConfig[network.config.chainId]?.fundLinkAmount ?? ethers.parseEther("5"),
        );
        console.log("Subscription funded");

        return { giveaway, vrfCoordinatorV2Mock };
    } else {
        console.log(
            `Funding contract with ${
                networkConfig[network.config.chainId]?.fundLinkAmountForSubscription ?? ethers.parseEther("5")
            } LINK for the subscription`,
        );
        const linkToken = new ethers.Contract(linkTokenAddress, ERC20ABI, user0);
        await linkToken.transfer(
            await giveaway.getAddress(),
            networkConfig[network.config.chainId]?.fundLinkAmountForSubscription ?? ethers.parseEther("5"),
        );
        console.log(
            `Funded contract with ${
                networkConfig[network.config.chainId]?.fundLinkAmountForSubscription ?? ethers.parseEther("5")
            } LINK`,
        );

        console.log(
            `Funding subscription with ${
                networkConfig[network.config.chainId]?.fundLinkAmountForSubscription ?? ethers.parseEther("5")
            } LINK`,
        );
        await giveaway.fundSubscription(
            networkConfig[network.config.chainId]?.fundLinkAmountForSubscription ?? ethers.parseEther("5"),
        );
        console.log(
            `Funded with ${
                networkConfig[network.config.chainId]?.fundLinkAmountForSubscription ?? ethers.parseEther("5")
            } LINK for the subscription`,
        );

        console.log(
            `Funding contract with ${
                networkConfig[network.config.chainId]?.fundLinkAmountForUpkeep ?? ethers.parseEther("3")
            } LINK for upkeep registration`,
        );
        await linkToken.transfer(
            await giveaway.getAddress(),
            networkConfig[network.config.chainId]?.fundLinkAmountForUpkeep ?? ethers.parseEther("3"),
        );
        console.log(
            `Funded with ${
                networkConfig[network.config.chainId]?.fundLinkAmountForUpkeep ?? ethers.parseEther("3")
            }  LINK`,
        );

        console.log("Registering contract for upkeep");
        await giveaway.registerForUpkeep(
            networkConfig[network.config.chainId]?.fundLinkAmountForUpkeep ?? ethers.parseEther("3"),
        );
        console.log("registered for upkeep");

        if (process.env.ETHERSCAN_API_KEY) {
            await verify(await giveaway.getAddress(), constructorArgs);
            await verify(await giveaway.getNFTAddress(), [`https://ipfs.io/ipfs/${NFT_METADATA_HASH}`]);
        }

        return giveaway;
    }
};

module.exports = deployGiveaway;
