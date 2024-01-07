// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import {PrizeNFT} from "./PrizeNFT.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {RegistrationParams, AutomationRegistrarInterface} from "./AutomationRegistrarInterface.sol";

/**
 * @title A Giveaway smart contract
 * @author Sahil Gujrati
 * @notice People can join in to have a fair chance at winning an NFT. The NFT can also represent a physical asset such as sneakers, gaming consoles, etc
 */
contract Giveaway is VRFConsumerBaseV2, AutomationCompatibleInterface, Ownable {
    // stores the details of the request that was made to the Chainlink VRF node operators to retrieve a random number for the given requestId
    struct VRFRequest {
        uint256 requestId;
        uint256 randomWord;
    }

    /**
     * @dev 0 for open state, 1 for the "selecting winner" state, and 2 for the closed state
     */
    enum GiveawayState {
        OPEN,
        SELECTING_WINNER,
        CLOSED
    }

    GiveawayState private giveawayState = GiveawayState.OPEN;
    address private immutable giveawayOwner;
    uint256 private participantCount = 0;
    mapping(address => bool) private participants;
    address[] private participantsArray;
    address private winner;
    uint256 private immutable interval;
    string private nftMetadataUri;
    uint256 private lastTimeStamp;
    VRFRequest private vrfRequest;

    uint64 private subscriptionId;
    bytes32 private immutable keyHash;
    uint32 private immutable callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // the number of confirmations from Chainlink nodes required before the random word is supplied. The higher the confirmations, the more secure is the random word
    uint32 private constant NUM_WORDS = 1; // the number of random words we want
    address private immutable upkeepContractAddress;
    uint256 private upkeepId;

    VRFCoordinatorV2Interface private immutable vrfCoordinator;
    AutomationRegistrarInterface private immutable registrar;
    PrizeNFT private immutable prizeNFT;
    LinkTokenInterface private immutable linkToken;

    /**
     * @notice Emitted when the giveaway is deployed
     */
    event GiveawayOpen();
    /**
     * @notice Emitted when the giveaway's winner is picked
     * @param _winner The giveaway's winner
     */
    event GiveawayWinnerSelected(address indexed _winner);
    /**
     * @notice Emitted when the VRF request is made to get the random word
     * @param _requestId The requestId for getting the random word
     */
    event SelectingWinner(uint256 indexed _requestId);
    /**
     * @notice Emitted when the giveaway is closed
     */
    event GiveawayClosed();

    error NotAValidAddress();
    error AlreadyJoined();
    error NotOpen();
    error UpkeepNotNeeded();
    error IndexOutOfBounds();
    error UpkeepRegistrationFailed();

    /**
     * @param _keyHash The gas lane key hash value, which is the maximum gas price you are willing to pay for a request in wei
     * @param _callbackGasLimit The amount of gas to use when the fulfillRandomWords function is called to supply a random word to our contract
     * @param _interval The amount of time in seconds after which to randomly pick a winner
     * @param _vrfCoordinatorAddress The vrfCoordinator contract address that is used to make the request for a random word
     * @param _nftMetadataUri The ipfs uri that points to the NFT metadata
     */
    constructor(
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint256 _interval,
        address _vrfCoordinatorAddress,
        string memory _nftMetadataUri,
        address _linkTokenAddress,
        address _automationRegistrarAddress
    ) VRFConsumerBaseV2(_vrfCoordinatorAddress) Ownable(msg.sender) {
        giveawayOwner = msg.sender;
        nftMetadataUri = _nftMetadataUri;

        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        interval = _interval;
        lastTimeStamp = block.timestamp;

        upkeepContractAddress = _automationRegistrarAddress;
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinatorAddress);
        registrar = AutomationRegistrarInterface(_automationRegistrarAddress);
        prizeNFT = new PrizeNFT(_nftMetadataUri);
        linkToken = LinkTokenInterface(_linkTokenAddress);

        createSubscription();
        addGiveawayAsConsumer();

        emit GiveawayOpen();
    }

    /**
     * @notice Funds the subscription created by this contract on deployment
     * @param _amount The amount of LINK tokens to fund the subscription with
     */
    function fundSubscription(uint256 _amount) external onlyOwner {
        linkToken.transferAndCall(address(vrfCoordinator), _amount, abi.encode(subscriptionId));
    }

    /**
     * @notice Registers this contract for upkeep
     * @param _amount The amount to fund the upkeep with
     */
    function registerForUpkeep(uint96 _amount) external onlyOwner {
        RegistrationParams memory params;
        params.name = "Giveaway";
        params.encryptedEmail = "0x";
        params.upkeepContract = address(this); // the contract that requires upkeep
        params.gasLimit = 500000;
        params.adminAddress = giveawayOwner;
        params.triggerType = 0; // 0 for custom logic upkeep
        params.checkData = "0x";
        params.triggerConfig = "0x";
        params.offchainConfig = "0x";
        params.amount = _amount;

        linkToken.approve(address(registrar), params.amount);
        uint256 _upkeepId = registrar.registerUpkeep(params);
        if (_upkeepId != 0) upkeepId = _upkeepId;
        else revert UpkeepRegistrationFailed();
    }

    /**
     * @notice A request is made for the random word, and the requst ID is obtained for the same
     * @dev The performUpkeep is called by the Chainlink automation service when it's time to pick a winner, as told by the checkUpkeep function
     */
    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) revert UpkeepNotNeeded();
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
     * @notice Removes this contract from the consumers list of the subscription created during deployment
     */
    function removeGiveawayFromConsumers() external onlyOwner {
        vrfCoordinator.removeConsumer(subscriptionId, address(this));
    }

    /**
     * @notice Cancels the subscription
     * @dev Sets the subscriptionId to 0
     */
    function cancelSubscription() external onlyOwner {
        vrfCoordinator.cancelSubscription(subscriptionId, giveawayOwner);
        subscriptionId = 0;
    }

    /**
     * @notice Allows the owner to withdraw all the LINK tokens held by this contract
     * @param _to The address of the receiver of the LINK tokens
     */
    function withdraw(address _to) external onlyOwner {
        uint256 balance = linkToken.balanceOf(address(this));
        linkToken.transfer(_to, balance);
    }

    /**
     * @notice Checks if the giveaway is open, if it has enough participants, and that, enough time has passed, as indicated by the interval
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
     * @notice Allows anyone to join the giveaway for free
     */
    function enterGiveaway() public {
        if (giveawayState != GiveawayState.OPEN) revert NotOpen();
        if (isParticipant(msg.sender)) revert AlreadyJoined();

        participants[msg.sender] = true;
        participantsArray.push(msg.sender);
        participantCount++;
    }

    /**
     * @return The giveaway owner's (deployer's) address
     */
    function getGiveawayOwner() public view returns (address) {
        return giveawayOwner;
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
     * @return participantCount The number of giveaway participants
     */
    function getParticipantCount() public view returns (uint256) {
        return participantCount;
    }

    /**
     * @notice Checks if the given address is a participant of the giveaway
     * @param _participant The address whose participation you want to check
     * @return isParticipant A boolean indicating whether the given address is a participant or not
     */
    function isParticipant(address _participant) public view returns (bool) {
        if (_participant == address(0)) revert NotAValidAddress();

        return participants[_participant];
    }

    /**
     * @dev Gets the address of a participant at the specified index in the participants array
     * @param _index The index at which the participant address is stores
     * @return the Participant's address
     */
    function getParticipant(uint256 _index) public view returns (address) {
        if (_index < 0 || _index > participantCount - 1) revert IndexOutOfBounds();
        return participantsArray[_index];
    }

    /**
     * @return prizeNFTAddress The address of the prize NFT
     */
    function getNFTAddress() public view returns (address) {
        return address(prizeNFT);
    }

    /**
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
     * @return remainingTime The time remaining before a winner is picked
     */
    function getRemainingTime() public view returns (uint256) {
        return interval - (block.timestamp - lastTimeStamp);
    }

    /**
     * @return interval The interval (in seconds) after which the giveaway's winner will be selected
     */
    function getInterval() public view returns (uint256) {
        return interval;
    }

    /**
     * @return subscriptionId The subscription ID this contract uses for funding VRF requests
     */
    function getSubscriptionId() public view returns (uint256) {
        return subscriptionId;
    }

    /**
     * @return vrfrequest A VRFRequest struct containing the requestId and the random number
     */
    function getVRFRequestDetails() public view returns (VRFRequest memory) {
        return vrfRequest;
    }

    /**
     * @return upkeepId The upkeep ID that was given to this contract on registering for upkeep
     */
    function getUpkeepId() public view returns (uint256) {
        return upkeepId;
    }

    /**
     * @notice A winner is picked using the modulo operation and the NFT is minted to the winner's address. The giveaway is closed
     * @dev This is the callabck for the vrf request. The vrfCoordinator calls this function, supplying the random number for the requestId
     * @param _randomWords The random numbers supplied to this function by the Chainlink vrf node operators
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
     * @notice Creates a new subscription for the giveaway to use
     */
    function createSubscription() private {
        subscriptionId = vrfCoordinator.createSubscription();
    }

    /**
     * @notice Adds the giveaway contract as the consumer of the subscription created during deployment
     */
    function addGiveawayAsConsumer() private {
        vrfCoordinator.addConsumer(subscriptionId, address(this));
    }
}
