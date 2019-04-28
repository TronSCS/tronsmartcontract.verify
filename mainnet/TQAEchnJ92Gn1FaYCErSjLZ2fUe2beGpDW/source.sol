pragma solidity ^0.4.23;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
    
    /**
    * @dev Divides two unsigned integers and returns the remainder (unsigned integer modulo),
    * reverts when dividing by zero.
    */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}

contract Tronkeys {
    using SafeMath for uint256;

    uint256 public TIME_PER_BUY;
    uint256 public TIME_PER_HIGH_BID;

    address public owner;
    
    uint256 public total;
    uint256 public jackpotBalance;
    uint256 public keyPrice;
    uint256 public refRate;
    uint256 public devRate;
    uint256 public jackpotRate;
    uint256 public nextJackpotRate;
    uint256 public highestBid;
    uint256 public nextJackpot;
    uint256 public totalKeys;
    uint256 public compoundBonus;
    uint256 public devBalance;
    uint256 public currentRound;
    uint256 public startTime;
    uint256 public delayer;

    mapping(address => uint256) public invested;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public keys;
    
    address [] public investors;
    address highestBidder;

    //events
    event Deposit(address investor, uint256 value, uint256 keysBought, uint256 indexed round);
    event Compound(address investor, uint256 value, uint256 keysBought, uint256 indexed round);
    event BalancesTransfer(address from, address to, uint256 value);
    event NewLeader(address from, uint256 value);
    event JackpotEnd(address highestBidder, uint256 value);
    event KeyBurn(address from, uint256 value);
    event Withdrawal(address from);
    event DevWithdrawal(address to, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }    
    
    function changeOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }
    
	constructor () public {
		owner = msg.sender;
		keyPrice = 50000000;
		refRate = 0;
		devRate = 20;
		jackpotRate = 10;
		nextJackpotRate = 2;
		highestBid = 0;
		nextJackpot = 0;
		compoundBonus = 10;
		currentRound = 1;
        startTime = now;
        delayer = 0;
        TIME_PER_BUY = 0; // 0 Seconds for buy
        TIME_PER_HIGH_BID = 240; // 4*60 +4 Minutes for buy
	}

    function payJackpot() public onlyOwner {
        require(address(this).balance > jackpotBalance);
        address(highestBidder).transfer(jackpotBalance);
        burnKeysFromAll();
        resetJackpot();

        totalKeys = 0;
        currentRound = currentRound.add(1);

        startTime = now;
        delayer = 0;
        
        emit JackpotEnd(highestBidder, jackpotBalance);
    }
    
    function burnKeysFromAll() internal {
        for (uint256 i = 0; i < investors.length; i++) {
           keys[investors[i]] = 0;
        }
    }
    
    function burnKeys(uint256 _value) public {
        keys[tx.origin] = keys[tx.origin].sub(_value);
        emit KeyBurn(tx.origin, _value);
    }
    
    function resetJackpot() internal {
        highestBid = 0;
        highestBidder = 0x0;
        jackpotBalance = nextJackpot;
        nextJackpot = 0;
        total = 0;
        
        for (uint256 i = 0; i < investors.length; i++) {
           delete invested[investors[i]];
           delete investors[i]; 
        }
    }

    //withdraw
    function withdraw() public returns (bool) {
        require(balances[msg.sender] > 0);

        msg.sender.transfer(balances[msg.sender]);
        balances[msg.sender] = 0;
       
        emit Withdrawal(msg.sender);
        
        return true;
    }

    //deposit
    function deposit(address _referredBy) public payable {
        require(msg.value >= keyPrice);
        
        uint256 _income = msg.value;
        
        uint256 _keysBought = msg.value.div(keyPrice);
        
        if (keys[msg.sender] == 0) {
            keys[msg.sender] = _keysBought;
        } else {
            keys[msg.sender] = keys[msg.sender].add(_keysBought);
        }
        
        if (invested[msg.sender] == 0) {
            investors.push(msg.sender);
            invested[msg.sender] = msg.value;
        } else {
            invested[msg.sender] = invested[msg.sender].add(msg.value);
        }
        
        totalKeys = totalKeys.add(_keysBought);

        //1. Distribute to Devs
        uint256 _devDiv = msg.value.mul(devRate).div(100);
        devBalance = devBalance.add(_devDiv);
        _income = _income.sub(_devDiv);


        //2. Distribute to Referral
        uint256 _refDiv = msg.value.mul(refRate).div(100);
        if(address(this).balance > _refDiv && _refDiv > 0 && _referredBy != msg.sender) {
            address(_referredBy).transfer(_refDiv);
            _income = _income.sub(_refDiv);
        }

        //3. Feed Jackpot
        uint256 _jackpotDiv = msg.value.mul(jackpotRate).div(100);
        jackpotBalance = jackpotBalance.add(_jackpotDiv);
        _income = _income.sub(_jackpotDiv);
        
        //4. Feed next Jackpot
        uint256 _nextJackpotDiv = msg.value.mul(nextJackpotRate).div(100);
        nextJackpot = nextJackpot.add(_nextJackpotDiv);
        _income = _income.sub(_nextJackpotDiv);

         //5. Distribute Income
        for (uint256 i = 0; i < investors.length; i++) {
            balances[investors[i]] = balances[investors[i]].add(_income.mul(keys[investors[i]]).div(totalKeys)); 
        }
        
        //assign new jackpot leader
        if (msg.value > highestBid) {
            highestBidder = msg.sender;
            highestBid = msg.value;
            delayer = delayer.add(TIME_PER_HIGH_BID);
            emit NewLeader(msg.sender, msg.value);
        } else {
            delayer = delayer.add(TIME_PER_BUY);
        }

        emit Deposit(msg.sender, msg.value, _keysBought, currentRound);

        total += msg.value;
    }
	
	//reinvest balance and get compoundBonus free keys rewarded
    function compound(uint256 value) public {
	    require(value >= keyPrice);
        
        balances[msg.sender] = balances[msg.sender].sub(value);
        
        if (invested[msg.sender] == 0) {
            investors.push(msg.sender);
            invested[msg.sender] = value;
        } else {
            invested[msg.sender] = invested[msg.sender].add(value);
        }
        
        uint256 _income = value;
        
        uint256 _keysBought = _income.div(keyPrice);
        _keysBought = _keysBought.add(_keysBought.mul(compoundBonus).div(100));
        
        if (keys[msg.sender] == 0) {
            keys[msg.sender] = _keysBought;
        } else {
            keys[msg.sender] = keys[msg.sender].add(_keysBought);
        }
        
        totalKeys = totalKeys.add(_keysBought);
        
        //1. Distribute to Devs
        uint256 _devDiv = value.mul(devRate).div(100);
        devBalance = devBalance.add(_devDiv);
        _income = _income.sub(_devDiv);


        //2. Feed Jackpot
        uint256 _jackpotDiv = value.mul(jackpotRate).div(100);
        jackpotBalance = jackpotBalance.add(_jackpotDiv);
        _income = _income.sub(_jackpotDiv);
        
        //3. Feed next Jackpot
        uint256 _nextJackpotDiv = value.mul(nextJackpotRate).div(100);
        nextJackpot = nextJackpot.add(_nextJackpotDiv);
        _income = _income.sub(_nextJackpotDiv);

        //4. Distribute Income
        for (uint256 i = 0; i < investors.length; i++) {
            balances[investors[i]] = balances[investors[i]].add(_income.mul(keys[investors[i]]).div(totalKeys)); 
         }
        
        //assign new jackpot leader
        if (value > highestBid) {
            highestBidder = msg.sender;
            highestBid = value;
            delayer = delayer.add(TIME_PER_HIGH_BID);
            emit NewLeader(msg.sender, value);
        } else {
            delayer = delayer.add(TIME_PER_BUY);
        }
        
        
        emit Compound(msg.sender, value, _keysBought, currentRound);
    }
	
    function addToJackpot() public payable {
        uint256 _jackpotDiv = msg.value;
        jackpotBalance = jackpotBalance.add(_jackpotDiv);
    }
	
    function transferBalance(address to, uint256 value) external returns (bool) {
        _transfer(tx.origin, to, value);
        return true;
    }
	
	function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));
        balances[from] = balances[from].sub(value);
        balances[to] = balances[to].add(value);
        emit BalancesTransfer(from, to, value);
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
    
    function getKeys() public view returns (uint256) {
        return totalKeys;
    }
    
    function getJackpot() public view returns (uint256) {
        return jackpotBalance;
    }
    
    function getRound() public view returns (uint256) {
        return currentRound;
    }

    function getBalances(address _address) public view returns (uint256) {
        return balances[_address];
    }
    
    function getInvested(address _address) public view returns (uint256) {
        return invested[_address];
    }
    
    function getKey(address _address) public view returns (uint256) {
        return keys[_address];
    }

    function getKeyPrice() public view returns (uint256) {
        return keyPrice;
    }    

    function getHighestBid() public view returns (uint256) {
        return highestBid;
    }

    function getHighestBidder() public view returns (address) {
        return highestBidder;
    }

    function getCalcCompoundKeys(uint256 _value) public view returns (uint256) {
        uint256 bonus = _value.div(keyPrice);
        uint256 bonusKeys = bonus.add(bonus.mul(compoundBonus).div(100));
        return bonusKeys;
    }

    function getDelayer() public view returns (uint256) {
        return delayer;
    }    

    function getStartTime() public view returns (uint256) {
        return startTime;
    }    
    
    function getDevBalance() external view onlyOwner returns (uint256) {
        return devBalance;
    }
    
    function setKeyPrice(uint256 _price) public onlyOwner {
        keyPrice = _price;
    }
    
    function setRefRate(uint256 _rate) public onlyOwner {
        refRate = _rate;
    }
    
    function setDevRate(uint256 _rate) public onlyOwner {
        devRate = _rate;
    }
    
    function setJackpotRate(uint256 _rate) public onlyOwner {
        jackpotRate = _rate;
    }
    
    function setNextJackpotRate(uint256 _rate) public onlyOwner {
        nextJackpotRate = _rate;
    }

    function setCompoundBonus(uint256 _rate) public onlyOwner {
        compoundBonus = _rate;
    }

    function setStartTime(uint256 _startTime) public onlyOwner {
        startTime = _startTime;
    }

    function setDelayer(uint256 _delayer) public onlyOwner {
        delayer = _delayer;
    }
    
    function setTIME_PER_BUY(uint256 _time) public onlyOwner {
        TIME_PER_BUY = _time;
    }
    
    function setTIME_PER_HIGH_BID(uint256 _time) public onlyOwner {
        TIME_PER_HIGH_BID = _time;
    }
    
    function devWithdraw(address _address) public onlyOwner {
        address(_address).transfer(devBalance);
        emit DevWithdrawal(_address, devBalance);
        devBalance = 0;
    }    
    
    function() payable public {
        deposit(owner);
    }    
}
