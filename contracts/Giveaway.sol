// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

error Giveaway__NotAValidAddress();
error Giveaway__AlreadyJoined();

contract Giveaway {
    uint256 public participantCount = 0;
    mapping(address => bool) private participants;
    address private winner;

    function enterGiveaway() public {
        if (isParticipant(msg.sender)) revert Giveaway__AlreadyJoined();

        participants[msg.sender] = true;
        participantCount++;
    }

    function isParticipant(address participant) public view returns (bool) {
        if (participant != address(0)) revert Giveaway__NotAValidAddress();

        return participants[participant];
    }

    function getWinner() public view returns (address) {
        return winner;
    }
}
