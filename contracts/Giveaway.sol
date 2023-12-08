// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {PrizeNFT} from "./PrizeNFT.sol";

error Giveaway__NotAValidAddress();
error Giveaway__AlreadyJoined();
error Giveaway__NotOpen();
error Giveaway__UpkeepNotNeeded();
error Giveaway__IndexOutOfBounds();

contract Giveaway is VRFConsumerBaseV2, AutomationCompatibleInterface {
    event GiveawayOpen();
    event GiveawayWinnerSelected(address indexed winner);
    event GiveawayClosed();

    struct VRFRequest {
        uint256 requestId;
        uint256 randomWord;
    }

    enum GiveawayState {
        OPEN,
        SELECTING_WINNER,
        CLOSED
    }

    uint256 private participantCount = 0;
    mapping(address => bool) private participants;
    address[] private participantsArray;
    address private winner;
    GiveawayState private giveawayState = GiveawayState.OPEN;
    uint256 private immutable interval;
    uint256 private lastTimeStamp;
    VRFRequest private vrfRequest;
    VRFCoordinatorV2Interface private immutable vrfCoordinator;
    uint64 private immutable subscriptionId;
    bytes32 private immutable keyHash;
    uint32 private immutable callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    PrizeNFT public immutable prizeNFT;
    string private nftMetadataUri;

    constructor(
        uint64 _subscriptionId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint256 _interval,
        address _vrfCoordinatorAddress,
        string memory _nftMetadataUri
    ) VRFConsumerBaseV2(_vrfCoordinatorAddress) {
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        interval = _interval;
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinatorAddress);
        lastTimeStamp = block.timestamp;
        nftMetadataUri = _nftMetadataUri;
        prizeNFT = new PrizeNFT(_nftMetadataUri);

        emit GiveawayOpen();
    }

    function checkUpkeep(
        bytes memory /* checkData */
    ) public view override returns (bool, bytes memory /* performData */) {
        bool isOpen = (giveawayState == GiveawayState.OPEN);
        bool hasPlayers = (participantCount > 0);
        bool hasEnoughTimePassed = (block.timestamp - lastTimeStamp >= interval);
        bool upkeepNeeded = isOpen && hasPlayers && hasEnoughTimePassed;
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("0x");
        if (!upkeepNeeded) {
            revert Giveaway__UpkeepNotNeeded();
        }
        giveawayState = GiveawayState.SELECTING_WINNER;

        uint256 requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            callbackGasLimit,
            NUM_WORDS
        );
        vrfRequest.requestId = requestId;
    }

    function fulfillRandomWords(uint256 /* _requestId */, uint256[] memory _randomWords) internal override {
        giveawayState = GiveawayState.CLOSED;
        vrfRequest.randomWord = _randomWords[0];

        winner = participantsArray[_randomWords[0] % participantCount];
        prizeNFT.mintReward(winner);

        emit GiveawayWinnerSelected(winner);
        emit GiveawayClosed();
    }

    function enterGiveaway() public {
        if (giveawayState != GiveawayState.OPEN) revert Giveaway__NotOpen();
        if (isParticipant(msg.sender)) revert Giveaway__AlreadyJoined();

        participants[msg.sender] = true;
        participantsArray.push(msg.sender);
        participantCount++;
    }

    function getGiveawayState() public view returns (GiveawayState) {
        return giveawayState;
    }

    function getParticipantCount() public view returns (uint256) {
        return participantCount;
    }

    function isParticipant(address _participant) public view returns (bool) {
        if (_participant == address(0)) revert Giveaway__NotAValidAddress();

        return participants[_participant];
    }

    function getParticipant(uint256 index) public view returns (address) {
        if (index < 0 || index > participantCount - 1) revert Giveaway__IndexOutOfBounds();
        return participantsArray[index];
    }

    function getNFTAddress() public view returns (address) {
        return address(prizeNFT);
    }

    function getNFTMetadataUri() public view returns (string memory) {
        return nftMetadataUri;
    }

    function getWinner() public view returns (address) {
        return winner;
    }

    function getInterval() public view returns (uint256) {
        return interval;
    }

    function getVRFRequestDetails() public view returns (VRFRequest memory) {
        return vrfRequest;
    }
}
