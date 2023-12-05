// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

error Giveaway__NotAValidAddress();
error Giveaway__AlreadyJoined();

contract Giveaway is VRFConsumerBaseV2 {
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

    uint256 public participantCount = 0;
    mapping(address => bool) private participants;
    address[] public participantsArray;
    address private winner;
    GiveawayState public giveawayState = GiveawayState.OPEN;
    VRFRequest public vrfRequest;
    VRFCoordinatorV2Interface private immutable vrfCoordinator;
    uint64 private immutable subscriptionId;
    bytes32 private immutable keyHash;
    uint32 private immutable callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    constructor(
        uint64 _subscriptionId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        address _vrfCoordinatorAddress
    ) VRFConsumerBaseV2(_vrfCoordinatorAddress) {
        subscriptionId = _subscriptionId;
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinatorAddress);

        emit GiveawayOpen();
    }

    function requestRandomWords() external returns (uint256) {
        giveawayState = GiveawayState.SELECTING_WINNER;

        uint256 requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subscriptionId,
            REQUEST_CONFIRMATIONS,
            callbackGasLimit,
            NUM_WORDS
        );
        vrfRequest.requestId = requestId;

        return requestId;
    }

    function fulfillRandomWords(uint256 /* _requestId */, uint256[] memory _randomWords) internal override {
        giveawayState = GiveawayState.CLOSED;
        vrfRequest.randomWord = _randomWords[0];

        winner = participantsArray[_randomWords[0] % participantCount];

        emit GiveawayWinnerSelected(winner);
        emit GiveawayClosed();
    }

    function enterGiveaway() public {
        if (isParticipant(msg.sender)) revert Giveaway__AlreadyJoined();

        participants[msg.sender] = true;
        participantsArray.push(msg.sender);
        participantCount++;
    }

    function isParticipant(address _participant) public view returns (bool) {
        if (_participant == address(0)) revert Giveaway__NotAValidAddress();

        return participants[_participant];
    }

    function getWinner() public view returns (address) {
        return winner;
    }
}
