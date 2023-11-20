const { run } = require("hardhat");

module.exports = async (contractAddress, constructorArgs = []) => {
    try {
        await run("verify:verify", {
            address: contractAddress,
            constructorArguments: constructorArgs,
        });
    } catch (error) {
        if (error.message.toLowerCase().includes("already verified"))
            console.log(`Contract ${contractAddress} has already been verified`);
        else console.log(error);
    }
};
