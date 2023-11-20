// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Giveaway {
    address public winner;
    AggregatorV3Interface internal ETHUSDpriceFeed;

    constructor(address ETHUSDpriceFeedAggregatorAddress) {
        ETHUSDpriceFeed = AggregatorV3Interface(ETHUSDpriceFeedAggregatorAddress);
    }

    function enterGiveaway() public payable {}

    function getLatestETHUSDpriceFeed() internal view returns (int256) {
        (, int256 answer, , , ) = ETHUSDpriceFeed.latestRoundData();
        return answer;
    }
}
