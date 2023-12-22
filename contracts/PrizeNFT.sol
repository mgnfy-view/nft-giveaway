// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

error PrizeNFT__RewardMintedGiveawayClosed();

import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title The prize NFT for the giveaway
 * @author Sahil Gujrati
 * @notice This NFT will be minted to the winner of the giveaway
 */
contract PrizeNFT is ERC721URIStorage, Ownable {
    uint256 public tokenCounter = 0;
    string public nftUri;

    /**
     * Constructor
     * @param _nftUri The NFT metadata URI
     */
    constructor(string memory _nftUri) ERC721("Prize NFT", "PNFT") Ownable(msg.sender) {
        nftUri = _nftUri;
    }

    /**
     * @notice Mints the NFT to the winner's address
     * @dev This NFT can only be minted once
     * @param winner The winner that was randomly selected by the giveaway
     */
    function mintReward(address winner) public onlyOwner {
        if (tokenCounter != 0) revert PrizeNFT__RewardMintedGiveawayClosed();
        tokenCounter++;
        _safeMint(winner, tokenCounter);
        _setTokenURI(tokenCounter, nftUri);
    }
}
