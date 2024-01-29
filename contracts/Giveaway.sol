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
 * @notice People can join in to have a fair chance at winning an NFT. The NFT can also represent physical assets such as sneakers, gaming consoles, etc
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

    GiveawayState private s_giveawayState;
    address private immutable i_giveawayOwner;
    uint256 private s_participantCount = 0;
    mapping(address => bool) private s_participants;
    address[] private s_participantsArray;
    address private s_winner;
    uint256 private immutable i_interval;
    string private s_nftMetadataUri;
    uint256 private s_lastTimeStamp;
    VRFRequest private s_vrfRequest;

    uint64 private immutable s_subscriptionId;
    bytes32 private immutable i_keyHash;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // the number of confirmations from Chainlink nodes required before the random word is supplied. The higher the confirmations, the more secure is the random word
    uint32 private constant NUM_WORDS = 1; // the number of random words we want
    address private immutable i_upkeepContractAddress;
    uint256 private i_upkeepId;

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    AutomationRegistrarInterface private immutable i_registrar;
    PrizeNFT private immutable i_prizeNFT;
    LinkTokenInterface private immutable i_linkToken;

    /**
     * @notice Emitted when the giveaway is deployed
     */
    event GiveawayOpen();
    /**
     * @notice Emitted when the giveaway's winner is picked
     * @param winner The giveaway's winner
     */
    event GiveawayWinnerSelected(address indexed winner);
    /**
     * @notice Emitted when the VRF request is made to get the random word
     * @param requestId The requestId for getting the random word
     */
    event SelectingWinner(uint256 indexed requestId);
    /**
     * @notice Emitted when the giveaway is closed
     */
    event GiveawayClosed();

    error Giveaway__AlreadyJoined();
    error Giveaway__NotOpen();
    error Giveaway__UpkeepNotNeeded();
    error Giveaway__IndexOutOfBounds();
    error Giveaway__UpkeepRegistrationFailed();
    error Giveaway__FailedToWithdrawLinkTokens();
    error Giveaway__FailedToFundSubscription();
    error Giveaway__FailedToApproveLinkTokensForUpkeep();

    /**
     * @param keyHash The gas lane key hash value, which is the maximum gas price you are willing to pay for a request, in wei
     * @param callbackGasLimit The amount of gas to use when the fulfillRandomWords function is called to supply a random word to our contract
     * @param interval The amount of time in seconds after which to randomly pick a winner
     * @param vrfCoordinatorAddress The vrfCoordinator contract address that is used to make the request for a random word
     * @param nftMetadataUri The ipfs uri that points to the NFT metadata
     */
    constructor(
        bytes32 keyHash,
        uint32 callbackGasLimit,
        uint256 interval,
        address vrfCoordinatorAddress,
        string memory nftMetadataUri,
        address linkTokenAddress,
        address automationRegistrarAddress
    ) VRFConsumerBaseV2(vrfCoordinatorAddress) Ownable(msg.sender) {
        s_giveawayState = GiveawayState.OPEN;
        i_giveawayOwner = msg.sender;
        s_nftMetadataUri = nftMetadataUri;

        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;

        i_upkeepContractAddress = automationRegistrarAddress;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorAddress);
        i_registrar = AutomationRegistrarInterface(automationRegistrarAddress);
        i_prizeNFT = new PrizeNFT(nftMetadataUri);
        i_linkToken = LinkTokenInterface(linkTokenAddress);

        s_subscriptionId = i_vrfCoordinator.createSubscription();
        i_vrfCoordinator.addConsumer(s_subscriptionId, address(this));

        emit GiveawayOpen();
    }

    /**
     * @notice Funds the subscription created by this contract on deployment
     * @param amount The amount of LINK tokens to fund the subscription with
     */
    function fundSubscription(uint256 amount) external onlyOwner {
        bool success = i_linkToken.transferAndCall(
            address(i_vrfCoordinator),
            amount,
            abi.encode(s_subscriptionId)
        );
        if (!success) revert Giveaway__FailedToFundSubscription();
    }

    /**
     * @notice Registers this contract for upkeep
     * @param amount The amount to fund the upkeep with
     */
    function registerForUpkeep(uint96 amount) external onlyOwner {
        RegistrationParams memory params = RegistrationParams({
            name: "Giveaway",
            encryptedEmail: "0x",
            upkeepContract: address(this),
            gasLimit: 500000,
            adminAddress: i_giveawayOwner,
            triggerType: 0, // 0 for custom logic upkeep,
            checkData: "0x",
            triggerConfig: "0x",
            offchainConfig: "0x",
            amount: amount
        });

        bool success = i_linkToken.approve(address(i_registrar), params.amount);
        if (!success) revert Giveaway__FailedToApproveLinkTokensForUpkeep();

        uint256 upkeepId = i_registrar.registerUpkeep(params);
        if (upkeepId == 0) revert Giveaway__UpkeepRegistrationFailed();
        else i_upkeepId = upkeepId;
    }

    /**
     * @notice A request is made for the random word, and the requst ID is obtained for the same
     * @dev The performUpkeep is called by the Chainlink automation service when it's time to pick a winner, as told by the checkUpkeep function
     */
    function performUpkeep(bytes calldata /* performData */) external override {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) revert Giveaway__UpkeepNotNeeded();
        s_giveawayState = GiveawayState.SELECTING_WINNER;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHash,
            s_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        s_vrfRequest.requestId = requestId;

        emit SelectingWinner(requestId);
    }

    /**
     * @notice Removes this contract from the consumers list of the subscription created during deployment
     */
    function removeGiveawayFromConsumers() external onlyOwner {
        i_vrfCoordinator.removeConsumer(s_subscriptionId, address(this));
    }

    /**
     * @notice Cancels the subscription
     */
    function cancelSubscription() external onlyOwner {
        i_vrfCoordinator.cancelSubscription(s_subscriptionId, i_giveawayOwner);
    }

    /**
     * @notice Allows the owner to withdraw all the LINK tokens held by this contract
     * @param to The address wich receives the LINK tokens when this function is called
     */
    function withdraw(address to) external onlyOwner {
        uint256 balance = i_linkToken.balanceOf(address(this));
        bool success = i_linkToken.transfer(to, balance);
        if (!success) revert Giveaway__FailedToWithdrawLinkTokens();
    }

    /**
     * @notice Checks if the giveaway is open, if it has enough participants, and that, enough time has passed, as indicated by the interval
     * @dev This function contains the logic that will be executed off-chain to see if performUpkeep should be executed
     * @return A boolean value indicating whether it's time to select a winner or not
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view override returns (bool, bytes memory /* performData */) {
        bool isOpen = (s_giveawayState == GiveawayState.OPEN);
        bool hasPlayers = (s_participantCount > 0);
        bool hasEnoughTimePassed = (block.timestamp - s_lastTimeStamp >= i_interval);
        bool upkeepNeeded = isOpen && hasPlayers && hasEnoughTimePassed;

        return (upkeepNeeded, "");
    }

    /**
     * @notice Allows anyone to join the giveaway for free
     */
    function enterGiveaway() public {
        if (s_giveawayState != GiveawayState.OPEN) revert Giveaway__NotOpen();
        if (isParticipant(msg.sender)) revert Giveaway__AlreadyJoined();

        s_participants[msg.sender] = true;
        s_participantsArray.push(msg.sender);
        s_participantCount++;
    }

    /**
     * @return The giveaway owner's (deployer's) address
     */
    function getGiveawayOwner() public view returns (address) {
        return i_giveawayOwner;
    }

    /**
     * @notice Tells if the giveaway is open or not
     * @dev GiveawayState is an enum where 0 indicates an open state, 1 indicates the "selecting winner" state and 2 indicates the closed state
     * @return A number indicating the current state of the giveaway
     */
    function getGiveawayState() public view returns (GiveawayState) {
        return s_giveawayState;
    }

    /**
     * @return The number of giveaway participants
     */
    function getParticipantCount() public view returns (uint256) {
        return s_participantCount;
    }

    /**
     * @notice Checks if the given address is a participant of the giveaway
     * @param participant The address whose participation you want to check
     * @return A boolean indicating whether the given address is a participant or not
     */
    function isParticipant(address participant) public view returns (bool) {
        return s_participants[participant];
    }

    /**
     * @dev Gets the address of a participant at the specified index in the participants array
     * @param index The index at which the participant address is stored
     * @return The participant's address
     */
    function getParticipant(uint256 index) public view returns (address) {
        if (index > s_participantCount - 1) revert Giveaway__IndexOutOfBounds();

        return s_participantsArray[index];
    }

    /**
     * @return The address of the prize NFT
     */
    function getNFTAddress() public view returns (address) {
        return address(i_prizeNFT);
    }

    /**
     * @return The NFT metadata URI
     */
    function getNFTMetadataUri() public view returns (string memory) {
        return s_nftMetadataUri;
    }

    /**
     * @notice Gets the address of the winner of the giveaway
     * @dev The winner is initially address(0), indicating that the giveaway is still open, and that, no winner is selected
     * @return The giveaway winner's address
     */
    function getWinner() public view returns (address) {
        return s_winner;
    }

    /**
     * @return The time remaining before a winner is picked
     */
    function getRemainingTime() public view returns (uint256) {
        return i_interval - (block.timestamp - s_lastTimeStamp);
    }

    /**
     * @return The interval (in seconds) after which the giveaway's winner will be selected
     */
    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    /**
     * @return The subscription ID this contract uses for funding VRF requests
     */
    function getSubscriptionId() public view returns (uint256) {
        return s_subscriptionId;
    }

    /**
     * @return The VRFRequest struct containing the requestId and the random number
     */
    function getVRFRequestDetails() public view returns (VRFRequest memory) {
        return s_vrfRequest;
    }

    /**
     * @return The upkeep ID that was given to this contract upon registering for upkeep
     */
    function getUpkeepId() public view returns (uint256) {
        return i_upkeepId;
    }

    /**
     * @notice A winner is picked using the modulo operation and the NFT is minted to the winner's address. The giveaway is closed
     * @dev This is the callabck for the vrf request. The vrfCoordinator calls this function, supplying the random number for the requestId
     * @param randomWords The random numbers supplied to this function by the Chainlink vrf node operators
     */
    function fulfillRandomWords(
        uint256 /* _requestId */,
        uint256[] memory randomWords
    ) internal override {
        s_giveawayState = GiveawayState.CLOSED;
        s_vrfRequest.randomWord = randomWords[0];

        s_winner = s_participantsArray[randomWords[0] % s_participantCount];
        i_prizeNFT.mintReward(s_winner);

        emit GiveawayWinnerSelected(s_winner);
        emit GiveawayClosed();
    }
}
