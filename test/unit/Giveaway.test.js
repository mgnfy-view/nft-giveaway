const { network, ethers } = require("hardhat");
const { assert, expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const deployGiveaway = require("../../scripts/deployGiveaway.js");
const { developmentChainIds, networkConfig } = require("../../helper.config.js");

developmentChainIds.includes(network.config.chainId)
    ? describe("Giveaway unit testing", function () {
          let giveaway, vrfCoordinatorV2Mock, user0, user1;

          beforeEach(async function () {
              [user0, user1] = await ethers.getSigners();
              ({ giveaway, vrfCoordinatorV2Mock } = await loadFixture(deployGiveaway));
          });

          describe("Giveaway initialization", function () {
              it("sets the giveaway owner's address to the deployer's address", async function () {
                  const giveawayOwner = await giveaway.getGiveawayOwner();

                  assert.strictEqual(giveawayOwner, user0.address);
              });

              it("sets the NFT's address to a vaild address, and not address 0", async function () {
                  const prizeNFTAddress = await giveaway.getNFTAddress();

                  assert.notStrictEqual(prizeNFTAddress, "0x0000000000000000000000000000000000000000");
              });

              it("sets the giveaway in open state, indicated by 0", async function () {
                  const giveawayState = await giveaway.getGiveawayState();

                  assert.strictEqual(giveawayState.toString(), "0");
              });

              it("sets the recent winner's address to 0 (indicating no winner)", async function () {
                  const recentWinner = await giveaway.getWinner();

                  assert.strictEqual(recentWinner.toString(), "0x0000000000000000000000000000000000000000");
              });

              it("sets the interval after which to pick a winner equal to the interval specified in the helper config", async function () {
                  const interval = await giveaway.getInterval();

                  assert.strictEqual(interval.toString(), networkConfig[network.config.chainId].interval.toString()); // I've kept the keyHash, callbackGasLimit, and interval for local network the same as that for the sepolia network
              });

              it("sets the participant count to 0", async function () {
                  const participantCount = await giveaway.getParticipantCount();

                  assert.strictEqual(participantCount.toString(), "0");
              });

              it("sets the NFT metadata uri string to what was set in the .env", async function () {
                  const nftMetadataUri = await giveaway.getNFTMetadataUri();

                  assert.isTrue(nftMetadataUri.includes(process.env.NFT_METADATA_HASH || "rndm0123456789val")); // if the metadata hash isn't set (for local testing chain, use random value)
              });

              it("sets the subscripton ID to 1", async function () {
                  const subscriptionId = await giveaway.getSubscriptionId();

                  assert.strictEqual(subscriptionId, "1");
              });
          });

          describe("Entering the giveaway", function () {
              it("increases the participant count by 1", async function () {
                  await giveaway.connect(user1).enterGiveaway();
                  const participantCount = await giveaway.getParticipantCount();

                  assert.strictEqual(participantCount.toString(), "1");
              });

              it("registers the participant in the contract", async function () {
                  await giveaway.connect(user1).enterGiveaway();
                  const isParticipant = await giveaway.isParticipant(user1.address);
                  const participant = await giveaway.getParticipant(0);

                  assert.isTrue(isParticipant);
                  assert.strictEqual(participant, user1.address);
              });

              it("throws an error if the same participant tries to rejoin", async function () {
                  await giveaway.connect(user1).enterGiveaway(); // first entry

                  await expect(giveaway.connect(user1).enterGiveaway()).to.be.rejectedWith("AlreadyJoined"); // rejection on second entry
              });
          });

          describe("Checking for upkeep", function () {
              it("returns false if not enough time has passed and there aren't sufficient participants", async function () {
                  const upkeepNeeded = await giveaway.checkUpkeep("0x");

                  assert.deepEqual(upkeepNeeded, [false, "0x"]);
              });

              it("returns true if all the conditions are satisfied", async function () {
                  await giveaway.connect(user1).enterGiveaway(); // sets hasPlayers to true
                  await network.provider.request({
                      method: "evm_increaseTime",
                      params: [Number(networkConfig[31337].interval)],
                  });
                  await network.provider.request({
                      method: "evm_mine",
                      params: [],
                  });
                  const upkeepNeeded = await giveaway.checkUpkeep("0x");

                  assert.deepEqual(upkeepNeeded, [true, "0x"]);
              });
          });

          describe("Performing upkeep/requesting a random word", function () {
              it("reverts with UpkeepNotNeeded if upkeep is not required", async function () {
                  await expect(giveaway.performUpkeep("0x")).to.be.rejectedWith("UpkeepNotNeeded()");
              });

              it("fires the SelectingWinner event", async function () {
                  await giveaway.connect(user1).enterGiveaway(); // sets hasPlayers to true
                  await network.provider.request({
                      method: "evm_increaseTime",
                      params: [Number(networkConfig[31337].interval) + 1],
                  });
                  await network.provider.request({
                      method: "evm_mine",
                      params: [],
                  });

                  await expect(giveaway.performUpkeep("0x")).to.emit(giveaway, "SelectingWinner");
              });

              it("changes the giveaway state to SELECTING_WINNER, indicated by 1 when upkeep is performed", async function () {
                  await giveaway.connect(user1).enterGiveaway(); // sets hasPlayers to true
                  await network.provider.request({
                      method: "evm_increaseTime",
                      params: [Number(networkConfig[31337].interval) + 1],
                  });
                  await network.provider.request({
                      method: "evm_mine",
                      params: [],
                  });
                  await giveaway.performUpkeep("0x");
                  const giveawayState = await giveaway.getGiveawayState();

                  assert.strictEqual(giveawayState.toString(), "1");
              });

              it("adds the requestId to the vrfRequest object", async function () {
                  await giveaway.connect(user1).enterGiveaway(); // sets hasPlayers to true
                  await network.provider.request({
                      method: "evm_increaseTime",
                      params: [Number(networkConfig[31337].interval)],
                  });
                  await network.provider.request({
                      method: "evm_mine",
                      params: [],
                  });
                  await giveaway.performUpkeep("0x");
                  const vrfRequest = await giveaway.getVRFRequestDetails();

                  assert.notStrictEqual(vrfRequest[0].toString, "0");
              });

              it("supplies the random word, picks the winner, and stores the random word in the vrfRequest struct", async function () {
                  await giveaway.connect(user1).enterGiveaway(); // sets hasPlayers to true
                  await network.provider.request({
                      method: "evm_increaseTime",
                      params: [Number(networkConfig[31337].interval + 1)],
                  });
                  await network.provider.request({
                      method: "evm_mine",
                      params: [],
                  });

                  giveaway.once("GiveawayWinnerSelected", async function () {
                      try {
                          const giveawayState = await giveaway.getGiveawayState();
                          const winner = await giveaway.getWinner();
                          const vrfRequestDetails = await giveaway.getVRFRequestDetails();

                          assert.strictEqual(winner.toString(), user1.address);
                          assert.strictEqual(giveawayState.toString(), "2");
                          assert.isAbove(Number(vrfRequestDetails[1]), 0);
                      } catch (error) {
                          console.log(error);
                      }
                  });

                  await giveaway.performUpkeep("0x");
                  await vrfCoordinatorV2Mock.fulfillRandomWords("1", await giveaway.getAddress());
              });
          });

          describe("Miscellaneous functions", function () {
              it("the remaining time must be 5 seconds after 5 seconds have passed, since tinhe interval set for local testing is 10 seconds", async function () {
                  await network.provider.request({
                      method: "evm_increaseTime",
                      params: [Number(networkConfig[31337].interval - 5)],
                  });
                  await network.provider.request({
                      method: "evm_mine",
                      params: [],
                  });
                  const remainingTime = await giveaway.getRemainingTime();

                  assert.isBelow(Number(remainingTime.toString()), 5); // accounting for time loss between requests
              });
          });
      })
    : describe.skip;
