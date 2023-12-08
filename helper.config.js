const SUBSCRIPTION_ID = process.env.SUBSCRIPTION_ID;

const developmentChainIds = [31337];
const networkConfig = {
    11155111: {
        name: "sepolia",
        blockConfirmations: 6,
        subscriptionId: SUBSCRIPTION_ID, // the subscriptionId that the contract uses to fund requests
        keyHash: "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c", // 150 gwei keyHash
        vrfCoordinatorAddress: "0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625",
        callbackGasLimit: "500000", // the maximum gas limit for fulfillRandomWords function
        interval: "10", // the amount of time after which the giveaway winner will be selected (here, its set to 10 seconds)
    },
    31337: {
        name: "localhost",
        blockConfirmations: 1,
        subscriptionId: 1,
        keyHash: "0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c",
        callbackGasLimit: "5000000",
        interval: "10",
    },
};

module.exports = {
    developmentChainIds,
    networkConfig,
};
