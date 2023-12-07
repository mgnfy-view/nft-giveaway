const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { assert, expect } = require("chai");
const deployMain = require("../../scripts/deployMain.js");
const { developmentChainIds, networkConfig } = require("../../helper.config.js");

developmentChainIds.includes(network.config.chainId)
    ? describe("Giveaway", function () {
          let nft, giveaway, vrfCoordinatorV2Mock, user0, user1;

          beforeEach(async function () {
              ({ nft, giveaway, vrfCoordinatorV2Mock, user0, user1 } = await loadFixture(deployMain));
          });

          describe("Initialization check", function () {
              it("the giveaway must be in an open state, indicated by 0", async function () {
                  const giveawayState = await giveaway.getGiveawayState();

                  assert.strictEqual(giveawayState.toString(), "0");
              });

              it("the recent winner must be address 0 (no winner)", async function () {
                  const recentWinner = await giveaway.getWinner();

                  assert.strictEqual(recentWinner.toString(), "0x0000000000000000000000000000000000000000");
              });

              it("the interval after which a winner is picked must be equal to the interval specified in the helper config", async function () {
                  const interval = await giveaway.getInterval();

                  assert.strictEqual(interval.toString(), networkConfig[11155111].interval.toString()); // the keyHash, callbackGasLimit, and interval for local network is the same as that for the sepolia network
              });

              it("the participant count must be zero", async function () {
                  const participantCount = await giveaway.getParticipantCount();

                  assert.strictEqual(participantCount.toString(), "0");
              });

              it("the nft address must be correctly set", async function () {
                  const nftAddress = await giveaway.getNFTAddress();

                  assert.strictEqual(nftAddress.toString(), await nft.getAddress());
              });
          });

          describe.only("Entering the giveaway", function () {
              it("entering the giveaway must increase the participant count by 1", async function () {
                  await giveaway.connect(user1).enterGiveaway();
                  const participantCount = await giveaway.getParticipantCount();

                  assert.strictEqual(participantCount.toString(), "1");
              });

              it("the participant must be registered in the contract", async function () {
                  await giveaway.connect(user1).enterGiveaway();
                  const isParticipant = await giveaway.isParticipant(user1.address);
                  const participant = await giveaway.getParticipant(0);

                  assert.isTrue(isParticipant);
                  assert.strictEqual(participant, user1.address);
              });

              it("trying to rejoin the giveaway will result in an error", async function () {
                  await giveaway.connect(user1).enterGiveaway(); // first entry

                  await expect(giveaway.connect(user1).enterGiveaway()).to.be.rejectedWith("Giveaway__AlreadyJoined"); // rejection on second entry
              });
          });
      })
    : describe.skip;
