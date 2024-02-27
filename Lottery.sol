// SPDX-License-Identifier: MIT

/// @dev solidity version.
pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
//import "@chainlink/contracts/src/v0.8/VRFCoordinatorV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";



/** @title Main Lottery Contract.
 * @dev Randomness provided internally in this version
 * subsequent versions will use external randomness (Chainlink VRF)
 */
contract Lottery is Ownable(msg.sender), ReentrancyGuard, VRFConsumerBaseV2{ //set myself, the deployer, as contract owner for now. can make this contract abstract later

    uint256  public ticketPrice = 2 * 10**18; // V2 would use chainlink pricefeeds for a more dynamic outlook.
    uint256 public maximumNumberOfTickets = 1000; // set max number of tickets to 1000 oer round
    uint256 public ticketCommission = 0.2 *10**18;
    uint256 public maximumNumberOfTicketsPerBuy = 5; // Functionality to control this variable : setMaximumNumberOfTickets
    uint256 public currentLotteryId;
    uint public lastWinnersAmounts; // Amounts the winners of last round won


    address public constant LINK_TOKEN_ADDRESS = 0x326037b4B1d8D50Db93e7D410cEE57ABe3a0C9a1;
    address public lotteryOperator; // admin addy
    address public lastWinnersAddy; //Addresses of the winners of the last round
    address public treasuryAddy; //where all smart contract profits would be sent for safekeeping

    address[] public tickets; //tickets(address) array

    VRFCoordinatorV2Interface public vrfCoordinator;
    bytes32 public keyHash;
    uint256 public requestFee;    


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

        //write  here statement to transfer MATIC (ticket cost) + ticket commission to the contract

        // write here statement to increment total amount collected for this lottery round

        for (uint256 i = 0; i < numberOfTicketsToBuy; i++){
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

        _lotteryRounds[_lotteryId].status = Status.Close;

        emit LotteryClose(_lotteryId);
    }

    function drawWinnersAndMakeLotteryClaimable(uint256 _lotteryId)
        external
        isAdmin
        nonReentrant
    {
        require(
            _lotteryRounds[_lotteryId].status == Status.Close,
            "Lottery has to be closed to draw winners"
        );
        require(tickets.length > 0, "No tickets were bought this round");

        // Calculating prize money to share post-treasury fee
        uint256 totalPrize = _lotteryRounds[_lotteryId].totalAmountInCurrentRound;
        uint256 treasuryFeeAmount = totalPrize * _lotteryRounds[_lotteryId].treasuryFee / 10**18;
        uint256 winnerShare = (totalPrize - treasuryFeeAmount) / 5; // share for each winner :-)

        // Requesting randomness from Chainlink VRF
        requestRandomness();
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

    function selectWinners(uint256 randomness) internal view returns (uint256[] memory) {
        uint256[] memory selectedWinners = new uint256[](5); //setting winners to an array of 5 elements
        for (uint256 i = 0; i < 5; i++) {
            selectedWinners[i] = randomness % tickets.length; //choosing randomly from the tickets array :-)
        }
        return selectedWinners;
    }    

    function requestRandomness() public isAdmin {
        require(
            LinkTokenInterface(LINK_TOKEN_ADDRESS).balanceOf(address(this)) >= requestFee, 
            "Insufficient LINK balance"
        );

        VRFCoordinatorV2.Request calldata request = vrfCoordinator.requestRandomness(
            keyHash,
            requestFee,
            1
        );
        requestId = request.requestId;
    }

    function getLinkBalance() public view returns (uint256) {
        return LinkTokenInterface(LINK_TOKEN_ADDRESS).balanceOf(address(this));
    }    

    function fulfillRandomness(uint256 requestId, uint256 randomness) 
        internal 
        override 
    {
        require(requestId == this.requestId, "Request ID does not match :-(");

        // Selecting winners randomly
        uint256[] memory selectedWinners = selectWinners(randomness);

        // Assigning winnings to selected winners
        for (uint256 i = 0; i < selectedWinners.length; i++) {
            address winnerAddress = tickets[selectedWinners[i]];
            winnings[winnerAddress] = winnerShare;
        }

        // Updating lottery round status and transfering treasury balance
        _lotteryRounds[_lotteryId].status = Status.Claimable;
        payable(treasuryAddy).transfer(treasuryFeeAmount);

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