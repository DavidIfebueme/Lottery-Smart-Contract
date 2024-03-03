# Lottery-Smart-Contract


## Lottery Contract: Decentralized Lottery System on Polygon Mumbai

This smart contract facilitates a decentralized lottery system on the Polygon Mumbai network. It leverages Chainlink VRF v2 for verifiable randomness to determine winners and offers transparency and fairness.

 ## Features:

Ticket purchase: Users can purchase tickets for a lottery round with MATIC.
Multiple winners: The system randomly selects 5 winners for each round.
Treasury: A portion of the collected fees is sent to a designated treasury address.
Operator control: An admin (operator) can manage various aspects like starting new rounds, setting fees, and withdrawing winnings.
Security:
Uses Chainlink VRF for verifiable randomness.
Restricts certain functionalities to the operator and prevents contract calls from other contracts.
Contract Structure:

Lottery: The main contract responsible for all lottery functionalities.
Ticket: Struct representing a lottery ticket with an owner address.
LotteryRound: Struct representing a single lottery round with details like status, start/end time, treasury fee, and total collected amount.
Events: Emitted for key events like lottery open/close, ticket purchase, and request sent/fulfilled for randomness.
Functions:

buyTickets(_lotteryId): Allows users to purchase tickets for a specific lottery round.
closeLottery(_lotteryId): (Admin only) Closes a lottery round after the end time and transfers collected fees to the treasury.
startLottery(_lotteryEndTime, _treasuryFee): (Admin only) Starts a new lottery round with specified end time and treasury fee.
setMaximumNumberOfTickets(_maximumNumberOfTicketsPerBuy): (Admin only) Sets the maximum number of tickets a user can buy in a single transaction.
withdrawWinnings: Allows winners to claim their rewards.
viewCurrentLotteryId: Returns the ID of the current ongoing lottery round.
viewLottery(_lotteryId): Returns details of a specific lottery round.
calculateRewardsForWinners(_lotteryId): Calculates the individual reward amount for winners.
requestRandomWords: (Admin only) Requests random words from Chainlink VRF to determine winners.
fulfillRandomWords(requestId, randomWords): Internal function called by Chainlink VRF to process random words and declare winners.
setOperator(newOperator): (Owner only) Sets a new operator address for managing the lottery.
isWinner: Checks if the caller address is a winner in the current round.
RemainingTickets: Returns the number of remaining tickets available for purchase in the current round.
Deployment and Usage:

Deploy the contract to Polygon Mumbai using a compatible wallet or tool like Remix.
Fund the deployed contract with MATIC for initial operations.
Users can call buyTickets to purchase tickets for the ongoing lottery round.
Once the lottery ends, the operator can call closeLottery to transfer collected fees and finalize the round.
Winners can call withdrawWinnings to claim their rewards after the round is closed and winners are announced.
Additional Notes:

This is a sample implementation and should be thoroughly reviewed and tested before deploying on a mainnet.
Consider security best practices like access controls, reentrancy protection, and proper error handling.
Adjust parameters like ticket price, fees, and number of winners according to your specific use case.