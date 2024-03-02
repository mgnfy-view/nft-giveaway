// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {ERC721URIStorage, ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title The prize NFT for the giveaway.
 * @author Sahil Gujrati
 * @notice This NFT will be minted to the winner of the giveaway.
 */
contract PrizeNFT is ERC721URIStorage, Ownable {
    uint256 private s_tokenCounter;
    string private s_nftUri;

    error RewardMintedGiveawayClosed();

    /**
     * @param nftUri The NFT metadata URI.
     */
    constructor(string memory nftUri) ERC721("Prize NFT", "PNFT") Ownable(msg.sender) {
        s_nftUri = nftUri;
    }

    /**
     * @notice Mints the NFT to the winner's address.
     * @dev This NFT can only be minted once.
     * @param winner The winner that was randomly selected by the giveaway.
     */
    function mintReward(address winner) external onlyOwner {
        if (s_tokenCounter != 0) revert RewardMintedGiveawayClosed();
        s_tokenCounter++;

        _setTokenURI(s_tokenCounter, s_nftUri);
        _safeMint(winner, s_tokenCounter);
    }

    /**
     * @return The NFT metadata Uri.
     */
    function getNftUri() external view returns (string memory) {
        return s_nftUri;
    }
}
