// SPDX-License-Identifier: MIT

/// @dev solitity version.
pragma solidity >=0.7.0 <0.9.0;

/** @title Main Lottery Contract.
 * @dev Randomness provided internally in this version
 * subsequent versions will use external randomness (Chainlink VRF)
 */
contract Lottery is ReentracyGuard, Ownable{
    using SafeERC20 for IERC;

    uint256  public ticketPrice = 2 * 10**18; // V2 would use chainlink pricefeeds for a more dynamic outlook.
    uint256 public maximumNumberOfTickets =
    uint256 public ticketCommission =

    address public lotteryOperator; // admin
    addresss public lastWinnersAddy; //Addresses of the winners of the last round
    uint public lastWinnersAmounts; // Amounts the winners of last round won


    address public treasuryAddy = //where all smart contract profits would be sent for safekeeping

    address[] public tickets; //tickets(address) array


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
        uint256 lotteryEndTime,

    );
    event LotteryClose(
        uint256 indexed lotteryId
    );
    event TicketPurchase(
        address indexed buyer,
        uint256 indexed lotteryId,
        uint256 amount 
    );

    constructor(){
        
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

    /**
    * Buy ticket functionality
    *@dev callable by users
    * contract can't buy tickets
    */
    function buyTickets(uint256 _lotteryId)
        external
        override
        notContract
        nonReentrant
    {
        require(
            _lotteries[_lotteryId].status == Status.Open, 
            "This round is not open yet!"
        );

        require(
            block.timestamp < _lotteries[_lotteryId].lotteryEndTime,
            "This round has ended :-("
        );

        uint256 numberOfTicketsToBuy = msg.value / ticketPrice;

        require(
            numberOfTicketsToBuy <= RemainingTickets(),
            "No more tickets for this round. Join the next one :-)"
        );

        //write  here statement to transfer MATIC (ticket cost) to the contract

        // write here statement to increment total amount collected for this lottery round

        for (uint256 i = 0; i < numberOfTicketsToBuy; i++){
            tickets.push(msg.sender);
        }

        emit TicketPurchase(msg.sender, _lotteryId);

    }

    /**
    *@notice Close a lottery round
    *@param _lotteryId: lottery id
    *@dev callable by only admin(operator) 
    */

    function closeLottery(uint256 _lotteryId)
        external
        override
        isAdmin
        nonReentrant
    {
        require(
            _lotteries[_lotteryId].status == Status.Open, 
            "This round is not open :-("
        );

        require(
            block.timestamp > _lotteries[_lotteryId].endTIme,
            "Lottery Round not over :-)"
        );

        _lotteries[_lotteryId].status = Status.Close;

        emit LotteryClose(_lotteryId);
    }

    function drawWinnersAndMakeLotteryClaimable(uint256 _lotteryId)
        external
        override
        isAdmin
        nonReentrant
    {
        require(
            _lotteries[_lotteryId].status == Status.Close, 
            "Lottery has to be closed to draw winners :-)"
        );

        require(
            tickets.length > 0,
            "No tickets were bought this round"
        );
        // calculate prize money to share post-treasury fee

        // random picking logic here to pick five winners and then share the pool to the five winners

        // initialize amount to withdraw to treasury

        // init lastWinners and amount they won

        _lotteries[_lotteryId].status = Status.Claimable;

        // safeTransfer treasuryfee to the treasury addy

    }

    /**
    *@notice Start a lottery round
    *@dev Callable by the admin(operator)
    *@param _treasuryFee
     */
    function startLottery(
        uint256 _lotteryEndTime,
        uint256 _treasuryFee
    ) external override isAdmin{
        require(
            (currentLotteryId == 0) || (_lotteries[currentLotteryId].status == Status.Claimable),
            "New Round should not be started because old round is still claimable"
        );
        currentLotteryId++;
        _lotteries[currentLotteryId] = Lottery({
            status: Status.Open,
            startTime: block.timestamp,
            endTIme: _endTime,
            treasuryFee: _treasuryFee
        });

        emit LotteryOpen(
            currentLotteryId,
            block.timestamp,
            _endTime
        )
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
        uint256
    }

    /**
     * @notice View current lottery id
     */
    function viewCurrentLotteryId() 
        external 
        view 
        override 
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
        returns (Lottery memory) 
    {
        return _lotteries[_lotteryId];
    }  

    /**
    *@notice Calculate winners rewards for the 5 winners
    *@param */
    function calculateRewardsForWinners(){

    }

    function isWinner()
        public
        view
        returns (bool)
    {
        return winnings[msg.sender] > 0;
    }

    function RemainingTicket()
        public
        view
        returns (uint256)
    {
        return maximumNumberOfTickets - tickets.length;
    }


    /**
     * @notice Check if an address is a contract
     */
    function _isContract(address _addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }      

}