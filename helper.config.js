const { ethers } = require("hardhat");

const developmentChainIds = [31337];
const networkConfig = {
    // this configuration for the Sepolia testnet is provided as an example
    11155111: {
        name: "sepolia",
        blockConfirmations: 3,
        keyHash: "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c", // 150 gwei keyHash
        callbackGasLimit: "500000", // the maximum gas limit for fulfillRandomWords function
        interval: "10", // the amount of time after which the giveaway winner will be selected (here, its set to 10 seconds)
        vrfCoordinatorAddress: "0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625",
        linkTokenAddress: "0x779877A7B0D9E8603169DdbD7836e478b4624789",
        upkeepContractAddress: "0xb0E49c5D0d05cbc241d68c05BC5BA1d1B7B72976",
        fundLinkAmountForSubscription: ethers.parseEther("12"),
        fundLinkAmountForUpkeep: ethers.parseEther("3"),
    },
    31337: {
        name: "localhost",
        blockConfirmations: 1,
        subscriptionId: 1,
        keyHash: "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c",
        callbackGasLimit: "5000000",
        interval: "5",
    },
};

module.exports = {
    developmentChainIds,
    networkConfig,
};
