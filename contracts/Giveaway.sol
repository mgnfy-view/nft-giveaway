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

/**
 * @title A Giveaway smart contract
 * @author Sahil Gujrati
 * @notice People can join to have a fair chance at winning an NFT. The NFT can also represent an physical item such as sneakers, gaming consoles, etc
 */
contract Giveaway is VRFConsumerBaseV2, AutomationCompatibleInterface {
    /**
     * @notice Emitted once when the giveaway is deployed
     */
    event GiveawayOpen();

    /**
     * @notice Emitted once when the giveaway's winner is picked
     * @param winner The giveaway's winner
     */
    event GiveawayWinnerSelected(address indexed winner);

    /**
     * @notice Emitted when the VRF request is made to get the random word and select the winner
     * @param requestId The requestId for getting the random word
     */
    event SelectingWinner(uint256 indexed requestId);

    /**
     * @notice Emitted once when the giveaway is closed
     */
    event GiveawayClosed();

    // stores the details of the request that was made to the chainlink vrf node operators to retrieve a random number for the given requestId
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
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // the number of confirmations from chainlink nodes required before the random word is supplied. The higher the confirmations, the more secure is the random word
    uint32 private constant NUM_WORDS = 1; // the number of random words we want
    PrizeNFT private immutable prizeNFT;
    string private nftMetadataUri;

    /**
     * @param _subscriptionId The subscription ID that this contract uses to fund the vrf requests
     * @param _keyHash The gas lane key hash value, which is the maximum gas price you are willing to pay for a request in wei
     * @param _callbackGasLimit the amount of gas we want to use when the random word is supplied to our contract and fulfillRandomWords function is called
     * @param _interval The amount of time in seconds after which to randomly pick a winner
     * @param _vrfCoordinatorAddress the vrfCoordinator contract address that is used to make the request for a random word
     * @param _nftMetadataUri The ipfs uri that leads to the NFT metadata
     */
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

    /**
     * @notice Checks if the giveaway is open, if it has enough players and that, enough time has passed, as indicated by the interval
     * @dev This function contains the logic that will be executed off-chain to see if performUpkeep should be executed
     * @return upkeepNeeded A boolean value indicating whether it's time to select a winner or not
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view override returns (bool, bytes memory /* performData */) {
        bool isOpen = (giveawayState == GiveawayState.OPEN);
        bool hasPlayers = (participantCount > 0);
        bool hasEnoughTimePassed = (block.timestamp - lastTimeStamp >= interval);
        bool upkeepNeeded = isOpen && hasPlayers && hasEnoughTimePassed;
        return (upkeepNeeded, "");
    }

    /**
     * @notice A request is made for the random word, and the requst ID is obtained for the same
     * @dev The performUpkeep is called by the chainlink automation service when it's time to pick a winner, as told by the checkUpkeep function
     */
    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
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
        emit SelectingWinner(requestId);
        vrfRequest.requestId = requestId;
    }

    /**
     * @notice A winner is picked using the modulo operation and the NFT is minted to the winner's address. The giveaway is closed
     * @dev This is the callabck for the vrf request. The vrfCoordinator calls this function, supplying the random number for the requestId
     * @param _randomWords The random numbers supplied to this function by the chainlink vrf node operators
     */
    function fulfillRandomWords(uint256 /* _requestId */, uint256[] memory _randomWords) internal override {
        giveawayState = GiveawayState.CLOSED;
        vrfRequest.randomWord = _randomWords[0];

        winner = participantsArray[_randomWords[0] % participantCount];
        prizeNFT.mintReward(winner);

        emit GiveawayWinnerSelected(winner);
        emit GiveawayClosed();
    }

    /**
     * @notice Allows anyone to join the giveaway for free.
     */
    function enterGiveaway() public {
        if (giveawayState != GiveawayState.OPEN) revert Giveaway__NotOpen();
        if (isParticipant(msg.sender)) revert Giveaway__AlreadyJoined();

        participants[msg.sender] = true;
        participantsArray.push(msg.sender);
        participantCount++;
    }

    /**
     * @notice Tells if the giveaway is open or not
     * @dev GiveawayState is an enum where 0 indicates an open state, 1 indicates the "selecting winner" state and 2 indicates the closed state
     * @return giveawayState A number indicating the current state of the giveaway
     */
    function getGiveawayState() public view returns (GiveawayState) {
        return giveawayState;
    }

    /**
     * @notice Gets the number of participants in the giveaway
     * @return participantCount The number of giveaway participants
     */
    function getParticipantCount() public view returns (uint256) {
        return participantCount;
    }

    /**
     * @notice Checks if the supplied address is a giveaway participant
     * @param _participant The address whose participation you want to check
     * @return isParticipant A boolean indicating whether the given address is a participant or not
     */
    function isParticipant(address _participant) public view returns (bool) {
        if (_participant == address(0)) revert Giveaway__NotAValidAddress();

        return participants[_participant];
    }

    /**
     * @dev Gets the address of a participant at the specified index in the participants array
     * @param index The index at which the participant address is stores
     * @return The participant's address
     */
    function getParticipant(uint256 index) public view returns (address) {
        if (index < 0 || index > participantCount - 1) revert Giveaway__IndexOutOfBounds();
        return participantsArray[index];
    }

    /**
     * @notice Gets the address of the prize NFT
     * @return The address of the prize NFT
     */
    function getNFTAddress() public view returns (address) {
        return address(prizeNFT);
    }

    /**
     * @notice Gets the NFT metadata URI
     * @return nftMetadatUri The NFT metadata URI
     */
    function getNFTMetadataUri() public view returns (string memory) {
        return nftMetadataUri;
    }

    /**
     * @notice Gets the address of the winner of the giveaway
     * @dev The winner is initially address(0), indicating no winner
     * @return winner The giveaway winner's address
     */
    function getWinner() public view returns (address) {
        return winner;
    }

    /**
     * @notice Gets the interval after which the winner is to be picked
     * @return interval The interval (in seconds) after which the giveaway's winner will be selected
     */
    function getInterval() public view returns (uint256) {
        return interval;
    }

    /**
     * Tells the amount of time remaining before the giveaway's winner is selected
     * @return Returns the time remaining before a winner is picked
     */
    function getRemainingTime() public view returns (uint256) {
        return interval - (block.timestamp - lastTimeStamp);
    }

    /**
     * @dev Returns the details of the VRF request that was made to get the random number for winner selection
     * @return Returns a VRFRequest struct containing the requestId and the random number
     */
    function getVRFRequestDetails() public view returns (VRFRequest memory) {
        return vrfRequest;
    }
}
