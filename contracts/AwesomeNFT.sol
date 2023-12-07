// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

error AwesomeNFT__RewardMintedGiveawayClosed();

import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract AwesomeNFT is ERC721URIStorage, Ownable {
    uint256 public tokenCounter = 0;
    string public nftUri;

    constructor(string memory _nftUri) ERC721("Awesome NFT", "ANFT") Ownable(msg.sender) {
        nftUri = _nftUri;
    }

    function mintReward(address player) public onlyOwner {
        if (tokenCounter != 0) revert AwesomeNFT__RewardMintedGiveawayClosed();
        _safeMint(player, tokenCounter);
        _setTokenURI(tokenCounter, nftUri);
        tokenCounter++;
    }
}
