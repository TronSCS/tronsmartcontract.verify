pragma solidity ^0.4.24;

/*
* 
* FishvsFish Game
* A competitive Fish game on TRON platform
* 
*/

contract FishvsFish {
	using SafeMath for uint256;

	/*------------------------------
                CONFIGURABLES
     ------------------------------*/
    
    uint256 public minFee;
    uint256 public maxFee;
    uint256 public jackpotDistribution;
    uint256 public durationRound;
    uint256 public devFee;
    uint256 public airdropFee;

    uint256 public airDropPot;
    uint256 public airDropTracker;


    bool public activated = false;
    
    address public developerAddr;
    
    /*------------------------------
                DATASETS
     ------------------------------*/
    uint256 public rId;

    mapping (address => Indatasets.Player) public player;
    mapping (uint256 => Indatasets.Round) public round;
    mapping (uint256 => mapping (uint256 => mapping (address => uint256))) public playerAmountDeposit;
	mapping (uint256 => mapping (uint256 => mapping (address => uint256))) public playerAmountDepositReal;
	mapping (uint256 => mapping (uint256 => mapping (address => uint256))) public playerRoundAmount;


    event Invest(address investor, uint256 side, uint256 amount);
    event Withdraw(address investor, uint256 amount);
    event AirdropWin(address investor, uint256 winType, uint256 amount);

    event newRound(uint256 roundNo);


    /*------------------------------
                PUBLIC FUNCTIONS
    ------------------------------*/

    constructor()
        public
    {
        developerAddr = msg.sender;
    }

    /*------------------------------
                MODIFIERS
     ------------------------------*/

    modifier amountVerify() {
        if(msg.value < 1000000){
            developerAddr.transfer(msg.value);
        }else{
            require(msg.value >= 1000000, "Amount too low.");
            _;
        }
    }

    modifier playerVerify() {
        require(player[msg.sender].active == true, "Player isn't active.");
        _;
    }

    modifier isActivated() {
        require(activated == true, "Contract hasn't been activated yet."); 
        _;
    }


    /**
     * Activation of contract with settings
     */
    function activate()
        public
    {
        require(msg.sender == developerAddr);
        require(activated == false, "Contract already activated");
        
		minFee = 5;
		maxFee = 50;
		jackpotDistribution = 60;
        airdropFee = 5;
		durationRound = 43200;
		rId = 1;
		activated = true;
        devFee = 100;
        devFee = devFee.sub(jackpotDistribution).sub(airdropFee);

		// Initialise first round

        round[rId].start = now;
        round[rId].end = now.add(43200);
        round[rId].ended = false;
        round[rId].winner = 0;
    }


    /**
     * Invest into red or green fish
     */

    function invest(uint256 _side)
    	isActivated()
        amountVerify()
    	public
        payable
    {
    	uint256 _feeUser = 0;
    	if(_side == 1 || _side == 2){
            if(now >= round[rId].end){
                startRound();
            }
            _feeUser = buyFish(_side);
            processAirdrop(_feeUser);
    	} else {
    		msg.sender.transfer(msg.value);
    	}
    }


    /*
     * Process Airdrop
     */

    function processAirdrop(uint256 _feeUser)
        private
    {

        airDropPot = airDropPot.add((_feeUser.mul(airdropFee)).div(100));

        if (msg.value >= 1000000){
            airDropTracker++;
            if (airdrop() == true)
            {
                uint256 _prize;
                if (msg.value >= 1000000000){

                    _prize = airDropPot;
                    player[msg.sender].winBalance = player[msg.sender].winBalance.add(_prize);
                    
                    emit AirdropWin(msg.sender, 1, _prize);

                    airDropPot = (airDropPot).sub(_prize);
                } else if (msg.value >= 10000000 && msg.value < 1000000000) {

                    _prize = ((airDropPot).mul(10)) / 100;
                    player[msg.sender].winBalance = player[msg.sender].winBalance.add(_prize);
                    
                    emit AirdropWin(msg.sender, 2, _prize);

                    airDropPot = (airDropPot).sub(_prize);
                } else if (msg.value >= 1000000 && msg.value < 10000000) {

                    _prize = ((airDropPot).mul(2)) / 100;
                    player[msg.sender].winBalance = player[msg.sender].winBalance.add(_prize);

                    emit AirdropWin(msg.sender, 3, _prize);
                    
                    airDropPot = (airDropPot).sub(_prize);
                }
                airDropTracker = 0;
            }
        }
    }

    /*
     * Calculate Win for Airdrop
     */

    function airdrop()
        private 
        view 
        returns(bool)
    {
        uint256 seed = uint256(keccak256(abi.encodePacked(
            
            (block.timestamp).add
            (block.difficulty).add
            ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (now)).add
            (block.gaslimit).add
            ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (now)).add
            (block.number)
            
        )));
        if((seed - ((seed / 1000) * 1000)) < airDropTracker)
            return(true);
        else
            return(false);
    }

    /**
     * Buy into Fish
     */

    function buyFish(uint256 _side)
    	private
        returns (uint256)
    {
    	uint256 _rId = rId;
    	uint256 _amount = msg.value;

        if(player[msg.sender].active == false){
            player[msg.sender].active = true;
            player[msg.sender].withdrawRid = _rId;
        }

        uint256 _feeUser = (_amount.mul(getRoundFee())).div(1000000);
        uint256 _depositUser = _amount.sub(_feeUser);

    	playerAmountDeposit[_rId][_side][msg.sender] = playerAmountDeposit[_rId][_side][msg.sender].add(_depositUser);
    	playerAmountDepositReal[_rId][_side][msg.sender] = playerAmountDepositReal[_rId][_side][msg.sender].add(_amount);

    	if(_side == 1){
    		round[_rId].amount1 = round[_rId].amount1.add(_depositUser);
    		if(playerRoundAmount[_rId][1][msg.sender] == 0){
    			playerRoundAmount[_rId][1][msg.sender]++;
    			round[_rId].players1++;
    		}
            round[rId].devFee1 = round[rId].devFee1.add((_feeUser.mul(devFee)).div(100));
    	} else if(_side == 2){
    		round[_rId].amount2 = round[_rId].amount2.add(_depositUser);
    		if(playerRoundAmount[_rId][2][msg.sender] == 0){
    			playerRoundAmount[_rId][2][msg.sender]++;
    			round[_rId].players2++;
    		}
            round[rId].devFee2 = round[rId].devFee2.add((_feeUser.mul(devFee)).div(100));
    	}

    	// jackpot distribution
        uint256 _jackPotNextRounds = (_feeUser.mul(jackpotDistribution).div(2)).div(100);
    	round[_rId+1].jackpotAmount = round[_rId+1].jackpotAmount.add(_jackPotNextRounds);
        round[_rId+2].jackpotAmount = round[_rId+2].jackpotAmount.add(_jackPotNextRounds);
        emit Invest(msg.sender, _side, _depositUser);
        return _feeUser;
   	}

   	/**
   	 * End current round and start a new one
   	 */

   	function startRound()
   		private
   	{
   		if(round[rId].amount1 > round[rId].amount2){
   			round[rId].winner = 1;
            developerAddr.transfer(round[rId].devFee2);
            round[rId+1].jackpotAmount = round[rId+1].jackpotAmount.add(round[rId].devFee1);
   		} else if(round[rId].amount1 < round[rId].amount2){
   			round[rId].winner = 2;
            developerAddr.transfer(round[rId].devFee1);
            round[rId+1].jackpotAmount = round[rId+1].jackpotAmount.add(round[rId].devFee2);
   		} else if(round[rId].amount1 == round[rId].amount2){
   			round[rId].winner = 3;
            round[rId+1].jackpotAmount = round[rId+1].jackpotAmount.add((round[rId].devFee1).add(round[rId].devFee2));
   		}

   		round[rId].ended = true;

   		rId++;

   		round[rId].start = now;
   		round[rId].end = now.add(durationRound);
   		round[rId].ended = false;
   		round[rId].winner = 0;

        emit newRound(rId);
   	}

    /**
     * Get player's balance
     */


   	function getPlayerBalance(address _player)
   		public
   		view
   		returns(uint256)
   	{
   		uint256 userWithdrawRId = player[_player].withdrawRid;
   		uint256 potAmount = 0;
   		uint256 userSharePercent = 0;
   		uint256 userSharePot = 0;
   		uint256 userDeposit = 0;

   		uint256 userBalance = 0;

   		for(uint256 i = userWithdrawRId; i < rId; i++){
   			if(round[i].ended == true){
                potAmount = round[i].amount1.add(round[i].amount2).add(round[i].jackpotAmount);
   				if(round[i].winner == 1 && playerAmountDeposit[i][1][_player] > 0){
   					userSharePercent = playerAmountDeposit[i][1][_player].mul(1000000000000000000).div(round[i].amount1);
   				} else if(round[i].winner == 2 && playerAmountDeposit[i][2][_player] > 0){
   					userSharePercent = playerAmountDeposit[i][2][_player].mul(1000000000000000000).div(round[i].amount2);
                } else if(round[i].winner == 3){
   					if(playerAmountDeposit[i][1][_player] > 0 || playerAmountDeposit[i][2][_player] > 0){
   						userDeposit = playerAmountDeposit[i][1][_player].add(playerAmountDeposit[i][2][_player]);
   						userBalance = userBalance.add(userDeposit);
   					}
   				}
                if(round[i].winner == 1 || round[i].winner == 2){
                    userSharePot = potAmount.mul(userSharePercent).div(1000000000000000000);
                    userBalance = userBalance.add(userSharePot);
                    userSharePercent = 0;
                }
   			}
   		}
   		return userBalance;
   	}

   	/*
   	 * Return the win balance
   	 */

   	function getWinBalance(address _player)
   		public
   		view
   		returns (uint256)
   	{
   		return player[_player].winBalance;
   	}

   	/*
   	 * Allows the user to withdraw the funds from the unclaimed rounds and the win balance.
   	 */

   	function withdraw()
        playerVerify()
        public
    {
        require(getWinBalance(msg.sender) > 0 || getPlayerBalance(msg.sender) > 0);

    	address playerAddress = msg.sender;
    	uint256 withdrawAmount = 0;
    	if(getWinBalance(playerAddress) > 0){
    		withdrawAmount = withdrawAmount.add(getWinBalance(playerAddress));
    		player[playerAddress].winBalance = 0;
    	}

    	if(getPlayerBalance(playerAddress) > 0){
    		withdrawAmount = withdrawAmount.add(getPlayerBalance(playerAddress));
    		player[playerAddress].withdrawRid = rId;
    	}
    	playerAddress.transfer(withdrawAmount);

        emit Withdraw(msg.sender, withdrawAmount);
    }

    /*
     * Returns the following datas of the user: active, balance, winBalance, withdrawRId
     */

    function getPlayerInfo(address _player)
    	public
    	view
    	returns (bool, uint256, uint256, uint256)
    {
    	return (player[_player].active, getPlayerBalance(_player), player[_player].winBalance, player[_player].withdrawRid);
    }

    /*
     * Get investments of a player in the current round
     */

    function getCurrentRoundUserInvestment(address _player)
        public
        view
        returns (uint256, uint256)
    {
        return (playerAmountDeposit[rId][1][_player], playerAmountDeposit[rId][2][_player]);
    }

    /*
     * Get Round Info
     */

    function getRoundInfo(uint256 _rId)
    	public
    	view
    	returns (uint256, uint256, bool, uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256)
    {
    	uint256 roundNum = _rId; 
    	return (round[roundNum].start, round[roundNum].end, round[roundNum].ended, round[roundNum].amount1, round[roundNum].amount2, round[roundNum].players1, round[roundNum].players2, round[roundNum].jackpotAmount, round[roundNum].devFee1, round[roundNum].devFee2, round[roundNum].winner);
    }

    /*
     * get users deposit with deducted fees of a specific round a team
     */ 

    function getUserDeposit(uint256 _rId, uint256 _side, address _player)
    	public
    	view
    	returns (uint256)
    {
    	return playerAmountDeposit[_rId][_side][_player];
    }


    /*
     * get users deposit without deducted fees of a specific round a team
     */ 

    function getUserDepositReal(uint256 _rId, uint256 _side, address _player)
    	public
    	view
    	returns (uint256)
    {
    	return playerAmountDepositReal[_rId][_side][_player];
    }

    /**
     * Get current round fee
     */


    function getRoundFee()
        public
        view
        returns (uint256)
    {
        uint256 roundStart = round[rId].start;
        uint256 _durationRound = 0;

        _durationRound = durationRound;

        uint256 remainingTimeInv = now - roundStart;
        uint256 percentTime = (remainingTimeInv * 10000) / _durationRound;
        uint256 feeRound = ((maxFee - minFee) * percentTime) + (minFee * 10000);

        return feeRound;
    }

    /**
     * Get Airdrop Info
     */

    function getAirdropInfo()
        public
        view
        returns (uint256, uint256)
    {
        return (airDropPot, airDropTracker);
    }
}

library Indatasets {

	struct Player {
		bool active;			// has user already interacted 
		uint256 winBalance; 	// balance of winnings
		uint256 withdrawRid;	// time of the prev. withdraw
	}
    
    struct Round {
        uint256 start;          // time round started
        uint256 end;            // time round ends/ended
        bool ended;             // has round end function been ran
        uint256 amount1;        // Eth received for current round for red
        uint256 amount2;        // Eth received for current round for green
        uint256 players1;		// total players for red
        uint256 players2;		// total players for green
        uint256 jackpotAmount;  // total jackpot for current round
        uint256 devFee1;		// collected fees for the dev of red fish
        uint256 devFee2;        // collected fees for the dev of green fish
        uint256 winner; 		// winner of the round
    }
}

/**
 * @title SafeMath v0.1.9
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    
    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) 
        internal 
        pure 
        returns (uint256) 
    {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
    
    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) 
        internal 
        pure 
        returns (uint256) 
    {
        assert(b <= a);
        return a - b;
    }

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) 
        internal 
        pure 
        returns (uint256) 
    {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }
    
    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) 
        internal 
        pure 
        returns (uint256) 
    {
        assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }
    
    /**
     * @dev gives square root of given x.
     */
    function sqrt(uint256 x)
        internal
        pure
        returns (uint256 y) 
    {
        uint256 z = ((add(x,1)) / 2);
        y = x;
        while (z < y) 
        {
            y = z;
            z = ((add((x / z),z)) / 2);
        }
    }
    
    /**
     * @dev gives square. multiplies x by x
     */
    function sq(uint256 x)
        internal
        pure
        returns (uint256)
    {
        return (mul(x,x));
    }
    
    /**
     * @dev x to the power of y 
     */
    function pwr(uint256 x, uint256 y)
        internal 
        pure 
        returns (uint256)
    {
        if (x==0)
            return (0);
        else if (y==0)
            return (1);
        else 
        {
            uint256 z = x;
            for (uint256 i=1; i < y; i++)
                z = mul(z,x);
            return (z);
        }
    }
}