// SPDX-License-Identifier: MIT

/// @dev solitity version.
pragma solidity >=0.7.0 <0.9.0;

/** @title Main Lottery Contract.
 * @dev Randomness provided internally in this version
 * subsequent versions will use external randomness (Chainlink)
 */
contract Lottery is ReentracyGuard, Ownable{
    using SafeERC20 for IERC;

    uint256 public maximumNumberOfTickets =
    uint256  public ticketPrice = 2 * 10**18; // V2 would use chainlink pricefeeds for a more dynamic outlook.
    uint256 public ticketCommission =


    address public treasuryAddy = //where all smart contract profits would be sent for safekeeping

    enum Status{
        Open,
        Closed,
        Claimable
    }

    struct Ticket{
        uint256 ticketPrice;
        
    }

    struct LotteryRound{
        Status;
    }
}