// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

error AwesomeNFT__RewardMintedGiveawayClosed();

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AwesomeNFT is ERC721URIStorage, Ownable {
    uint256 public tokenCounter = 0;
    string public NFTURI;

    constructor(string memory _NFTURI) ERC721("Awesome NFT", "ANFT") Ownable(msg.sender) {
        NFTURI = _NFTURI;
    }

    function mintReward(address player) public onlyOwner {
        if (tokenCounter != 0) revert AwesomeNFT__RewardMintedGiveawayClosed();
        _safeMint(player, tokenCounter);
        _setTokenURI(tokenCounter, NFTURI);
        tokenCounter++;
    }
}
