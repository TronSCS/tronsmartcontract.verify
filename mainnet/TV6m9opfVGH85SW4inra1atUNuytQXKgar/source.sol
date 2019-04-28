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

contract Tronkeys2 {
    using SafeMath for uint256;

    /**
     * Variable definations
    **/
    address public owner;
    uint256 public total;
    uint256 public jackpotBalance;
    uint256 public keyPrice;
    uint256 public refRate;
    uint256 public devRate;
    uint256 public jackpotRate;
    uint256 public totalKeys;
    uint256 public devBalance;
    uint256 public currentRound;
    uint256 public seed;
    uint256 public roundExpiry;
    uint256 public carryForwardKeys;
    uint256 public highestBid;
    uint256 public priceIncrease;
    uint256 public initkeyPrice;
    uint256 public legacyPoolBalance;
    uint256 public legacyPoolShare;
    uint256 public minWithdraw;

    mapping(address => uint256) public invested;
    mapping(address => uint256) public balances;
    mapping(address => uint256) public keys;
    
    address [] public investors;
    address public highestBidder;
    address public lastBidder;

    /**
     * Events
    **/
    event Deposit(address investor, uint256 value, uint256 keysBought, uint256 indexed round);
    event BalancesTransfer(address from, address to, uint256 value);
    event NewLeader(address from, uint256 value);
    event JackpotEnd(address highestBidder, address lastBidder, uint256 value, uint256 roundEnded);
    event KeyBurn(address from, uint256 value);
    event Withdrawal(address from);
    event roundStarted(uint256 timeOfStart, uint256 newRound);
    event DevWithdrawal(address to, uint256 amount);
    event WithdrawLegacyEvent(address _to, uint256 amount);
    
    /**
     * constructor
    **/
    constructor () public {
		owner = msg.sender;
		initkeyPrice = 1000000; // 1 trx
		keyPrice = initkeyPrice;
		refRate = 5;
		devRate = 9;
		seed = 4;
		jackpotRate = 16;
		carryForwardKeys = 20; // 20%
		currentRound = 1;
		highestBid = 0;
		roundExpiry = now + 30 minutes;
		priceIncrease = 250; // per key bought
		legacyPoolBalance = 0; 
		legacyPoolShare = 2;
		minWithdraw =  10000000; // 10 trx
	}
	
    /**
     * Internal functions
    **/
    function burnKeysFromAll() internal {
        for (uint256 i = 0; i < investors.length; i++) {
           keys[investors[i]] = keys[investors[i]].mul(carryForwardKeys).div(100);
        }
        
        totalKeys = totalKeys.mul(carryForwardKeys).div(100);
    }
    
    function resetJackpot() internal {        
        highestBidder = 0x0;
        highestBid = 0;
        lastBidder = 0x0;
        total = jackpotBalance;
        keyPrice = initkeyPrice; // 1 trx
        
        
        
        for (uint256 i = 0; i < investors.length; i++) {
           delete invested[investors[i]];
           delete investors[i];
        }
    }

    
    /**
     * modifiers
    **/
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    modifier isActive(){
        require(now < roundExpiry);
        _;
    }
    
    // prevent contracts to Withdraw
    modifier isHuman() {
        address _addr = msg.sender;
        uint256 _codeLength;

        assembly {_codeLength := extcodesize(_addr)}
        require(_codeLength == 0, "sorry humans only");
        _;
    }
    
    /**
     * owner functions
    **/
    
    function changeOwner(address _newOwner) public onlyOwner {
        owner = _newOwner;
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
    
    function setSeed(uint256 _seed) public onlyOwner {
        seed = _seed;
    }
 
    function setcarryForwardKeys(uint256 _keys) public onlyOwner {
        carryForwardKeys = _keys;
    }
    
    function setInitKeyPrice(uint256 _price) public onlyOwner {
        initkeyPrice = _price;
    }
    
    function setpriceIncrease(uint256 _rate) public onlyOwner {
        priceIncrease = _rate;
    }
    
    function setlegacyPoolShare (uint256 _rate) public onlyOwner {
        legacyPoolShare = _rate;
    }
    
     function setminWithdraw (uint256 _price) public onlyOwner {
        minWithdraw = _price;
    }
    
    function devWithdraw(address _address) public onlyOwner {
        address(_address).transfer(devBalance);
        emit DevWithdrawal(_address, devBalance);
        devBalance = 0;
    }
    
    // This will be Distributed to legacy div holders
    function withdrawLegacy(address _toAddress) public onlyOwner returns (bool) {
        require(legacyPoolBalance > 0);

        _toAddress.transfer(legacyPoolBalance);
        legacyPoolBalance = 0;
        emit WithdrawLegacyEvent(_toAddress, legacyPoolBalance);
        
        return true;
    }

    function payJackpot() public onlyOwner {
        
        require (now > roundExpiry);
        require(address(this).balance > jackpotBalance);
    
        address _highestBidder = highestBidder;
        address _lastBidder = lastBidder;
        uint256 _jackpotBalance = jackpotBalance;
        
        uint256 prizeShare = 100 - seed;
        prizeShare = prizeShare.div(2);
        uint256 prize = jackpotBalance.mul(prizeShare).div(100);
        address(lastBidder).transfer(prize);
        address(highestBidder).transfer(prize);
        
        jackpotBalance = jackpotBalance.sub(prize.mul(2));
        
        burnKeysFromAll();
        resetJackpot();

        emit JackpotEnd(_highestBidder, _lastBidder, _jackpotBalance, currentRound);
    }
    
    function startRound() public onlyOwner {
        roundExpiry = now + 30 minutes;
        currentRound = currentRound.add(1);
        emit roundStarted(now, currentRound);
    }

    /**
     * Setter functions
    **/
    // withdraw
    function withdraw() public isHuman returns (bool) {
        require(balances[msg.sender] > minWithdraw);
        msg.sender.transfer(balances[msg.sender]);
        balances[msg.sender] = 0;
       
        emit Withdrawal(msg.sender);
        
        return true;
    }

    // deposit
    function deposit(address _referredBy) public isActive payable {
        require(msg.value >= keyPrice);
        
        uint256 _income = msg.value;

        uint256 _keysBought = msg.value.div(keyPrice);
        keyPrice = keyPrice.add(priceIncrease.mul(_keysBought));
        
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

        // 1. Distribute to Devs
        uint256 _devDiv = msg.value.mul(devRate).div(100);
        devBalance = devBalance.add(_devDiv);
        _income = _income.sub(_devDiv);

        // 2. Distribute to Referral
        uint256 _refDiv = msg.value.mul(refRate).div(100);
        if(address(this).balance > _refDiv && _refDiv > 0 && _referredBy != msg.sender) {
            address(_referredBy).transfer(_refDiv);
            _income = _income.sub(_refDiv);
        }

        // 3. Feed Jackpot
        uint256 _jackpotDiv = msg.value.mul(jackpotRate).div(100);
        jackpotBalance = jackpotBalance.add(_jackpotDiv);
        _income = _income.sub(_jackpotDiv);
        
        // 4. Legacy Div pool
        uint256 _legacyPoolDiv = msg.value.mul(legacyPoolShare).div(100);
        legacyPoolBalance = legacyPoolBalance.add(_legacyPoolDiv);
        _income = _income.sub(_legacyPoolDiv);
        
         // 5. Distribute Income
        for (uint256 i = 0; i < investors.length; i++) {
            balances[investors[i]] = balances[investors[i]].add(_income.mul(keys[investors[i]]).div(totalKeys)); 
        }
        
        lastBidder = msg.sender;
        // assign new jackpot leader
        if (msg.value >= highestBid) {
            highestBidder = msg.sender;
            highestBid = msg.value;
            emit NewLeader(msg.sender, msg.value);
        }
        
        roundExpiry = roundExpiry.add(_keysBought.mul(30 seconds));
   
        if (roundExpiry > now + 24 hours){
            roundExpiry = now + 24 hours;
        }
        
        total += msg.value;
        emit Deposit(msg.sender, msg.value, _keysBought, currentRound);
    }
    
    function() payable public {
        deposit(owner);
    }
    
    function addToJackpot() public payable {
        uint256 _jackpotDiv = msg.value;
        jackpotBalance = jackpotBalance.add(_jackpotDiv);
    }

    /**
     * Getter functions
    **/
    function getBalance() public view returns (uint256) {
        return address(this).balance;
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
}
