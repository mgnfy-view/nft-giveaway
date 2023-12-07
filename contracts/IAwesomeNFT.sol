// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IAwesomeNFT is IERC721 {
    function mintReward(address player) external;
}
