// SPDX-License-Identifier: MIT

/// @dev solidity version.
pragma solidity >=0.7.0 <0.9.0;

import { ReentrancyGuard } from  "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { VRFCoordinatorV2Interface } from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import { VRFConsumerBaseV2 } from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import { VRFCoordinatorV2 } from "@chainlink/contracts/src/v0.8/VRFCoordinatorV2.sol";
import { LinkTokenInterface } from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";


/** @title Main Lottery Contract.
 * @dev Randomness provided externally using Chainlink VRF V2.
 */
contract Lottery is Ownable(msg.sender), ReentrancyGuard, VRFConsumerBaseV2 { //set myself, the deployer, as contract owner for now. can make this contract abstract later

    uint256  public ticketPrice = 2 * 10**18; // V2 would use chainlink pricefeeds for a more dynamic outlook.
    uint256 public maximumNumberOfTickets = 1000; // set max number of tickets to 1000 per round. Should probably write function to make this dynamic. Like in maximumNumberOfTicketsPerBuy
    uint256 public ticketCommission = 0.2 *10**18;
    uint256 public maximumNumberOfTicketsPerBuy = 5; // Functionality to control this variable : setMaximumNumberOfTickets
    uint256 public currentLotteryId;
    uint256 public lastWinnersAmounts; // Amounts the winners of last round won

    address public lotteryOperator; // admin addy
    address[] public lastWinnersAddy; //Addresses of the winners of the last round
    address public constant treasuryAddy = 0xF3E71A6b9CDc8fC54f8dc9B80aC1E0f629A37cf3; //where all smart contract fees would be sent for safekeeping

    address[] public tickets; //tickets(address) array


    //inherited VRF variables
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 s_subscriptionId;

    bytes32 keyHash = 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c ; // sort of a controller for the gas price. Each uint of the keyHAsh is mapped to an addy
    uint32 callbackGasLimit = 200000;
    uint16 requestConfirmations = 3; // the more this var, the more secure but the slower the txn
    uint32 numWords = 5; // Thought of adding this var to generate all the winners' ID so we just use one vrf call/cost per round instead of 5


    enum Status{
        Open,
        Close,
        Claimable
    }

    // Functionlity that shouldn't be called by the contract or a proxy. For security and transparency.
    modifier notContract(){
        require(
            !_isContract(msg.sender), 
            "Access Denied, contract not allowed to call this!"
        );

        require(
            msg.sender == tx.origin,
            "Access Denied, proxy contracts are not allowed too :-)"
        );
        _;
    }

    modifier isAdmin(){
        require(
            (msg.sender == lotteryOperator),
            "Access Denied, Not Admin"
        );
        _;
    }

    modifier onlyWinner(){
        require(
            isWinner(),
            "You are not a winner this round. Try Again!"
        );
        _;
    }

    event LotteryOpen(
        uint256 indexed lotteryId,
        uint256 lotteryStartTime,
        uint256 lotteryEndTime

    );
    event LotteryClose(
        uint256 indexed lotteryId
    );
    event TicketPurchase(
        address indexed buyer,
        uint256 indexed lotteryId,
        uint256 amount 
    );

    event RequestSent(uint256 requestId);

    event RequestFulfilled(uint256 requestId);

    
    /**
     * Hardcoded specs for Polygon Mumbai
     */    
    constructor(
        uint16 subscriptionId
    )
        VRFConsumerBaseV2(0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed)
        //msg.sender
    {
        COORDINATOR = VRFCoordinatorV2Interface(
            0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed
        );
        s_subscriptionId = subscriptionId; 
        lotteryOperator = msg.sender; // set myself, the owner, as operator first. Can be delegated to another addy :-)      
    }    

    struct Ticket{
        address tickerOwner;
    }

    struct LotteryRound{
        Status status;
        uint256 lotteryStartTime;
        uint256 lotteryEndTime;
        uint256 treasuryFee;
        uint256 totalAmountInCurrentRound;
    }

    mapping(uint256 => Ticket) private _tickets;
    mapping(uint256 => LotteryRound) private _lotteryRounds;
    mapping(address => uint256) public winnings;    

    /**
    * Buy ticket functionality
    *@dev callable by users
    * contract can't buy tickets
    */
    function buyTickets(uint256 _lotteryId)
        external
        payable
        notContract
        nonReentrant
    {
        require(
            _lotteryRounds[_lotteryId].status == Status.Open, 
            "This round is not open yet!"
        );

        require(
            block.timestamp < _lotteryRounds[_lotteryId].lotteryEndTime,
            "This round has ended :-("
        );

        uint256 numberOfTicketsToBuy = msg.value / ticketPrice;

        require(
            numberOfTicketsToBuy <= RemainingTickets(),
            "No more tickets for this round. Join the next one :-)"
            );

        // Calculating total cost 
        uint256 totalCost = numberOfTicketsToBuy * (ticketPrice + ticketCommission);

        // Require exact amount for purchase. Sorry, No refunds :-)
        require(
            msg.value == totalCost,
            "Don't try to play me. Sent amount does not match ticket and commission cost!"
        );

        // Funding the contract with the purchased tickets    
        payable(address(this)).transfer(ticketPrice * numberOfTicketsToBuy);

        // Transfering commission to the treasury. SHould have probably done this just before emitting TicketPurchase. It is what it is.
        payable(treasuryAddy).transfer(ticketCommission * numberOfTicketsToBuy);

        // Incrementing total amount collected for this round
        _lotteryRounds[_lotteryId].totalAmountInCurrentRound += totalCost;

        // Adding the tickets to the pool
        for (uint256 i = 0; i < numberOfTicketsToBuy; i++) {
            tickets.push(msg.sender);
        }

        emit TicketPurchase(msg.sender, _lotteryId, msg.value);

    }

    /**
    *@notice Close a lottery round
    *@param _lotteryId: lottery id
    *@dev callable by only admin(operator) 
    */

    function closeLottery(uint256 _lotteryId)
        external
        isAdmin
        nonReentrant
    {
        require(
            _lotteryRounds[_lotteryId].status == Status.Open, 
            "This round is not open :-("
        );

        require(
            block.timestamp > _lotteryRounds[_lotteryId].lotteryEndTime,
            "Lottery Round not over :-)"
        );


        // I should probably optimize this process. It is what it is.
        uint256 totalAmount = _lotteryRounds[_lotteryId].totalAmountInCurrentRound;
        uint256 treasuryFee = totalAmount * _lotteryRounds[_lotteryId].treasuryFee / 10**18;

        payable(treasuryAddy).transfer(treasuryFee);

        _lotteryRounds[_lotteryId].status = Status.Close;

        emit LotteryClose(_lotteryId);
    }

    /**
    *@notice Start a lottery round
    *@dev Callable by the admin(operator)
    *@param _treasuryFee: treasuryFee
     */
    function startLottery(
        uint256 _lotteryEndTime,
        uint256 _treasuryFee
    ) external 
      isAdmin
    {
        require(
            (currentLotteryId == 0) || (_lotteryRounds[currentLotteryId].status == Status.Claimable),
            "New Round should not be started because old round is still claimable"
        );
        currentLotteryId++;

        _lotteryRounds[currentLotteryId] = LotteryRound({
            status: Status.Open,
            lotteryStartTime: block.timestamp,
            lotteryEndTime: _lotteryEndTime,
            treasuryFee: _treasuryFee,
            totalAmountInCurrentRound: 0 
        });

        emit LotteryOpen(
            currentLotteryId,
            block.timestamp,
            _lotteryEndTime
        );
    }

    /**
    * @notice Set the maximum number of tickets
    * @dev Callable by admin(operator)
    */
    function setMaximumNumberOfTickets(uint256 _maximumNumberOfTicketsPerBuy)
        external
        isAdmin
    {
        require(
            _maximumNumberOfTicketsPerBuy > 0,
            "Must be greater than 0"
        );
        maximumNumberOfTicketsPerBuy = _maximumNumberOfTicketsPerBuy;
    }

    function withdrawWinnings()
        public
        onlyWinner
    {
        address payable winner = payable(msg.sender);
        uint256 reward = winnings[winner];
        winnings[winner] = 0;

        winner.transfer(reward);
    }
  
    /**
     * @notice View current lottery id
     */
    function viewCurrentLotteryId() 
        external 
        view 
        returns (uint256) 
    {
        return currentLotteryId;
    }

    /**
     * @notice View lottery information
     * @param _lotteryId: lottery id
     */
    function viewLottery(uint256 _lotteryId) 
        external 
        view 
        returns (LotteryRound memory) 
    {
        return _lotteryRounds[_lotteryId];
    }

    /**
    *@notice Calculate winners rewards for the 5 winners
    *@param _lotteryId : lotteryId
     */
    function calculateRewardsForWinners(uint256 _lotteryId)
        external
        view
        returns (uint256)
    {
        uint256 totalPrize = _lotteryRounds[_lotteryId].totalAmountInCurrentRound;
        uint256 winnerShare = totalPrize * (1 - _lotteryRounds[_lotteryId].treasuryFee / 10**18) / 5;
        
        return winnerShare;
    }
  

    function requestRandomWords()
        external
        isAdmin
        returns (uint256 requestId)
    {
        // Will revert if subscription is not set and funded.
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        emit RequestSent(requestId);
        return requestId;
    }


    // Now working with the randomness we have generated
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)  
        internal
        override
    {
        require(requestId == requestId, "Request ID does not match!");

        uint256 startingIndex = randomWords[0] % tickets.length;
        address[] memory winners = new address[](5);

        for (uint256 i = 0; i < 5; i++) {
            
            uint256 winnerIndex = (startingIndex + i) % tickets.length; // Calculating winner index

            winners[i] = tickets[winnerIndex]; // Assigning winner address to the corresponding index
        }

        _lotteryRounds[currentLotteryId].status = Status.Claimable;

        // for (uint256 i = 0; i < 5; i++) {
        //     winnings[winners[i]] = calculateRewardsForWinners(currentLotteryId);
        // }

        
        //emit WinnersAnnounced(winners); I hope i remember to define this event later :-)

    }

    function setOperator(address newOperator) 
        external 
        onlyOwner 
    {
        require(newOperator != address(0), "Invalid operator address");
        lotteryOperator = newOperator;
    } 

    function isWinner()
        public
        view
        returns (bool)
    {
        return winnings[msg.sender] > 0;
    }

    function RemainingTickets()
        public
        view
        returns (uint256)
    {
        return maximumNumberOfTickets - tickets.length;
    }


    /**
     * @notice Check if an address is a contract
     */
    function _isContract(address _addr) 
        internal 
        view 
        returns (bool) 
    {
        uint256 size;
        assembly {
            size := extcodesize(_addr) // Using this opcode to check if there are any lines of code linked to this address then return true is so.
        }
        return size > 0;
    }      

}
