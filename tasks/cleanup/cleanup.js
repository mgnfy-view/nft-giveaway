const cleanup = async function ({ address }, hre) {
    const [user0] = await hre.ethers.getSigners();
    const giveaway = await hre.ethers.getContractAt("Giveaway", address, user0);

    try {
        console.log("Removing giveaway from the consumers list");
        await giveaway.removeGiveawayFromConsumers();
        console.log("Giveaway removed from the consumers list");

        console.log("Cancelling subscription");
        await giveaway.cancelSubscription();
        console.log("Subscription cancelled");

        console.log("Withdrawing remaining LINK tokens");
        await giveaway.withdraw(user0.address);
        console.log("Remaining LINK tokens withdrawn");
    } catch (error) {
        console.log(error);
    }
};

module.exports = cleanup;
