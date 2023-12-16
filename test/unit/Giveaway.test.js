const { network, ethers } = require("hardhat");
const { assert, expect } = require("chai");
const { developmentChainIds, networkConfig } = require("../../helper.config.js");
const { loadFixture } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const deployMain = require("../../scripts/deployMain.js");

developmentChainIds.includes(network.config.chainId)
    ? describe("Giveaway unit testing", function () {
          let giveaway, vrfCoordinatorV2Mock, user0, user1;

          beforeEach(async function () {
              ({ giveaway, vrfCoordinatorV2Mock, user0, user1 } = await loadFixture(deployMain));
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

                  assert.strictEqual(interval.toString(), networkConfig[network.config.chainId].interval.toString()); // the keyHash, callbackGasLimit, and interval for local network is the same as that for the sepolia network
              });

              it("the participant count must be zero", async function () {
                  const participantCount = await giveaway.getParticipantCount();

                  assert.strictEqual(participantCount.toString(), "0");
              });

              it("the nft metadata uri string must be equal to what was set in the .env", async function () {
                  const nftMetadataUri = await giveaway.getNFTMetadataUri();

                  assert.isTrue(nftMetadataUri.includes(process.env.NFT_METADATA_HASH));
              });
          });

          describe("Entering the giveaway", function () {
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

          describe("Checking for upkeep", function () {
              it("checkUpkeep must return false if not enough time has passed and there aren't sufficient participants", async function () {
                  const upkeepNeeded = await giveaway.checkUpkeep("0x");

                  assert.deepEqual(upkeepNeeded, [false, "0x"]);
              });

              it("checkUpkeep must return true if all the conditions are satisfied", async function () {
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
              it("if upkeep is not required, then performUpkeep must revert with Giveaway__UpkeepNotNeeded", async function () {
                  await expect(giveaway.performUpkeep("0x")).to.be.rejectedWith("Giveaway__UpkeepNotNeeded()");
              });

              it("the SelectingWinner event must be fired", async function () {
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

              it("The giveaway state must change to SELECTING_WINNER, indicated by 1 when upkeep is performed", async function () {
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

              it("the requestId must be added to the vrfRequest object", async function () {
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

                  assert.isAbove(Number(vrfRequest[0]), 0);
              });

              it("the random word must be supplied, the winner picked, and he random word stord in the vrfRequest struct", async function () {
                  await giveaway.connect(user1).enterGiveaway(); // sets hasPlayers to true
                  await network.provider.request({
                      method: "evm_increaseTime",
                      params: [Number(networkConfig[31337].interval + 1)],
                  });
                  await network.provider.request({
                      method: "evm_mine",
                      params: [],
                  });

                  await new Promise(async function (resolve, reject) {
                      giveaway.once("GiveawayWinnerSelected", async function () {
                          try {
                              const giveawayState = await giveaway.getGiveawayState();
                              const winner = await giveaway.getWinner();
                              const vrfRequestDetails = await giveaway.getVRFRequestDetails();

                              assert.strictEqual(winner.toString(), user1.address);
                              assert.strictEqual(giveawayState.toString(), "2");
                              assert.isAbove(Number(vrfRequestDetails[1]), 0);
                              resolve();
                          } catch (error) {
                              reject(error);
                          }
                      });

                      try {
                          await giveaway.performUpkeep("0x");
                          await vrfCoordinatorV2Mock.fulfillRandomWords("1", await giveaway.getAddress());
                      } catch (error) {
                          reject(error);
                      }
                  });
              });
          });

          describe("Miscellaneous", function () {
              it("The remaining time must be 5 seconds after 5 seconds have passed, since the interval set for local testing is 10 seconds", async function () {
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

              it("The giveaway owner's address must be the deployer's address", async function () {
                  const giveawayOwner = await giveaway.getGiveawayOwner();

                  assert.strictEqual(giveawayOwner, user0.address);
              });

              it("The NFT's address must be a vaild address, and not address 0", async function () {
                  const prizeNFTAddress = await giveaway.getNFTAddress();
                  console.log(Number(prizeNFTAddress));

                  assert.isAbove(Number(prizeNFTAddress), 0);
              });
          });
      })
    : describe.skip;
