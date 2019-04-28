pragma solidity ^0.4.24;

contract TronWorldRecord {

	/****************
		VARIABLES
	****************/

	bool public jackpotAwarded;
	address public admin;
	uint256 public totalVolume;
	uint256 public payIndex;
	uint256 public increase = 1001; //100.1%
	uint256 public minBuy = 5000000000; //5000 trx
	uint256 public goal = 99000000000000000; //99 billion trx
	mapping (address => uint256) public totalBought;
 	mapping (address => uint256) public totalPaid;

 	bool public lottoAwarded;
 	uint256 public highestNumber;
 	address public currentWinner;
 	mapping (address => bool) public hasPlayed;
 	mapping (address => uint256) public lottoNumber;
 	
 	Order[] public orders;

	struct Order {
		uint256 amount;
		address owner;
	}

	/******************
		CONSTRUCTOR
	******************/

	constructor() public {
		admin = msg.sender;
	}
	
	/*************
		EVENTS
	*************/

	event newOrder(
		address indexed buyer,
		uint256 amount,
		uint256 totalVol
	);

	event jackpotWon(
		address indexed winner,
		uint256 jackpotAmount
	);

	event lottoPlayed(
		address indexed player,
		uint256 number
	);
	
	event lottoWon(
	    address indexed winner,
		uint256 prizeAmount
	);

	event queueMoved(
		address indexed payee,
		uint256 amount,
		uint256 index
	);
	
	/*********************
		USER FUNCTIONS
	*********************/
	
	/**
	 * fallback function
	 */
	function() public payable {
		buy(address(0));
	}

	/**
	 * buy into the contract
	 * @param _ref referral address
	 */
	function buy(address _ref) public payable {
    	//min buy to prevent small buys clogging up the queue
    	//and to ensure that profit is larger than txn costs
		require (msg.value >= minBuy); 
		//check referral
		address referrer = _checkRef(_ref);
		//calculate amounts
		uint256 valueMultiplied = (msg.value * increase) / 1000; //1.001x
		uint256 prizeAmount = msg.value / 1000; //0.1%
		uint256 refAmount = msg.value / 2000; //0.05%
		//force send to prevent malicious contracts blocking buys
		if (!referrer.send(refAmount)) {}
		//admin fee is also 0.05%
		admin.transfer(refAmount);
		//update state
		totalVolume += msg.value;
		totalBought[msg.sender] += msg.value;

	    orders.push(
	    	Order({
	    	    amount: valueMultiplied,
	    	    owner: msg.sender
	    	})
	    );
	    //check if goal is reached and award prize 
	    if (totalVolume >= goal && !jackpotAwarded) {
	    	uint256 prize = getJackpotPrize();
	    	jackpotAwarded = true;
	    	if (!msg.sender.send(prize)) {}
	    	emit jackpotWon(msg.sender, prize);
	    }

	    _processQueue(msg.value - (prizeAmount + (refAmount * 2)));

	    emit newOrder(msg.sender, msg.value, totalVolume);
	}

	/**
	 * forces the queue with non-prize funds in contract
     * under normal circumstances there should be no extra value in the contract
	 */
	function forceQueue() public {
		//can only be called if there is a balance and addresses in the queue
		require (availableBalance() > 0 && payIndex < orders.length);
		_processQueue(availableBalance());
	}

	/**
	 * free game that lets any user try to win a prize
	 * can only play once per address
	 * the highest number rolled when the goal is reached wins
	 * @return number rolled
	 */
	function playLotto() external returns(uint256) {
		//only one play per address
		require (!hasPlayed[msg.sender]);
		//generate pseudo random number
		uint256 num = _pseudoRNG();
		//update state
		hasPlayed[msg.sender] = true;
		lottoNumber[msg.sender] = num;
		//if number is current highest, update state
		if (num > highestNumber) {
			highestNumber = num;
			currentWinner = msg.sender;
		}

		emit lottoPlayed(msg.sender, num);

		return num;
	}

	/**
	 * claim lotto prize
	 * can only be called by winner
	 */
	function claimLottoPrize() external {
		require (!lottoAwarded);
		require (jackpotAwarded = true);
		require (totalVolume > goal);
		require (msg.sender == currentWinner);		

		lottoAwarded = true;
		uint256 prize = getLottoPrize();
	   	if (!msg.sender.send(prize)) {}

		emit lottoWon(msg.sender, prize);
	}
	

	/**********************
		ADMIN FUNCTIONS
	**********************/
	
	/**
	 * this function allows the admin to recover the prize funds and award manually
	 * can only be called if the goal is not reached by a specific date
	 */
	function recover() external {
		require (msg.sender == admin);
		//may 1, 2019
		require (now > 1556668800); 
		//first, send anything available to the queue
		forceQueue(); 
		//then transfer remaining prize funds for redistribution
		admin.transfer(address(this).balance);
	}

	/*********************
		VIEW FUNCTIONS
	*********************/

	/**
	 * @return total number of orders
	 */
	function getQueueLength() external view returns(uint256) {
	    return orders.length;
	}

	/**
	 * @return amount left to goal (in sun)
	 */
	function getAmountToGoal() external view returns(uint256) {
		return totalVolume < goal ? goal - totalVolume : 0; 
	}

	/**
	 * @return raw contract balance (in sun)
	 */
	function contractBalance() external view returns(uint256) {
		return address(this).balance; 
	}

	/**
	 * @return available balance not including prizes (in sun)
	 */
	function availableBalance() public view returns(uint256) {
		return address(this).balance > (totalVolume / 1000) ? address(this).balance - (totalVolume / 1000) : 0;
	}

	/**
	 * @return current lotto prize collected (in sun)
	 */
	function getLottoPrize() public view returns(uint256) {
		return !jackpotAwarded ? ((totalVolume / 1000) * 20) / 100 : totalVolume / 1000;
	}

	/**
	 * @return current jackpot prize collected (in sun)
	 */
	function getJackpotPrize() public view returns(uint256) {
		return !jackpotAwarded ? ((totalVolume / 1000) * 80) / 100 : 0;
	}

	/**
	 * total owed to a user calculated here to reduce state storage
	 * @param _user user address
	 * @return amount owed (in sun)
	 */
	function totalOwed(address _user) public view returns(uint256) {
		uint256 owed = (totalBought[_user] * increase) / 1000;
		if (totalPaid[_user] < owed) {
			return owed - totalPaid[_user];
		} else {
			return 0;
		}
	}

	/*************************
		INTERNAL FUNCTIONS
	*************************/

	/**
	 * process the queue in order
	 * @param _value value in sun available to process
	 */
	function _processQueue(uint256 _value) internal {
		uint256 value = _value;
		//loop while value remains and there are orders to fill
		while (payIndex < orders.length && value > 0) {
	    	Order storage order = orders[payIndex];
	    	//paritially fill order if value is less than order
			if (value < order.amount) {
				//update state
				totalPaid[order.owner] += value;
				order.amount -= value;
			    uint256 tempValue = value;
				value = 0;
				//force send to prevent malicious contracts holding up queue
				if (!order.owner.send(tempValue)) {}
			//fill order and increment queue if value is greater than order
			} else {
				//update state
				totalPaid[order.owner] += order.amount;
				value -= order.amount;
				tempValue = order.amount;
				order.amount = 0;
				//force send
				if (!order.owner.send(tempValue)) {}
				//log event
				emit queueMoved(order.owner, order.amount, payIndex);
				//increment queue
				payIndex++;
			}
	    }
	}

	/**
	 * utility function to manage referral
	 * admin receives referral if none is specified
	 * @param _ref referral address
	 * @return referral to use
	 */
	function _checkRef(address _ref) internal view returns(address) {
		address referrer = _ref;
		if (_ref == msg.sender || _ref == address(0)) {
			referrer = admin;
		}
		return referrer;
	}

	/**
	 * generate a pseudo random number between 0 and 99 billion
	 * since any address can only generate a single number, generating this is one block is secure enough
	 * @return pseudo random number
	 */
	function _pseudoRNG() public view returns(uint256) {
		return uint256(
		    keccak256(
		        abi.encodePacked(
		            blockhash(block.number - 1), 
		            block.coinbase, 
		            msg.sender
		      	)
		    )
		) % 99000000000;
	}
}