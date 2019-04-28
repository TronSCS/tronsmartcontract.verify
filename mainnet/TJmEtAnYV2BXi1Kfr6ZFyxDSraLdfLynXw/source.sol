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

contract TronVerza {
    using SafeMath for uint256;

    /**
     * Variable definations
    **/
    address public owner;
    uint256 public jackpotBalance;
    uint256 public rewardRate;
    uint256 public refRate;
    uint256 public devRate;
    uint256 public jackpotRate;
    uint256 public devBalance;
    uint256 public seed;
    uint256 public roundExpiry;
    uint256 public highestBid;
    uint256 public minWithdraw;
    uint256 public minDeposit;

    mapping(address => uint256) public invested;
    mapping(address => uint256) public balances;
    
    address [] public investors;
    address public highestBidder;

    /**
     * Events
    **/
    event Deposit(address investor, uint256 value);
    event NewLeader(address from, uint256 value);
    event JackpotEnd(address highestBidder, uint256 value);
    event PayoutCustomers(uint256 total);
    event Withdrawal(address from);
    
    /**
     * constructor
    **/
    constructor () public {
		owner = msg.sender;

        rewardRate = 6;
		refRate = 5;
		devRate = 5;
		jackpotRate = 5;
		seed = 4;

		highestBid = 0;
        highestBidder = 0x0;
		roundExpiry = now + 24 hours;
		minWithdraw =  10000000; // 10 trx
		minDeposit =  10000000; // 10 trx
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
             
    function setRefRate(uint256 _rate) public onlyOwner {
        refRate = _rate;
    }
    
    function setDevRate(uint256 _rate) public onlyOwner {
        devRate = _rate;
    }

    function setRewardRate(uint256 _rewardRate) public onlyOwner {
        rewardRate = _rewardRate;
    }    
    
    function setJackpotRate(uint256 _rate) public onlyOwner {
        jackpotRate = _rate;
    }
    
    function setSeed(uint256 _seed) public onlyOwner {
        seed = _seed;
    }
    
     function setminWithdraw (uint256 _price) public onlyOwner {
        minWithdraw = _price;
    }
    
    function devWithdraw(address _address) public onlyOwner {
        address(_address).transfer(devBalance);
        devBalance = 0;
    }


    function payoutCustomers() internal {
        uint256 total = 0;

        for (uint256 i = 0; i < investors.length; i++) {
           uint256 reward = (invested[investors[i]].mul(rewardRate).div(100)).mul(100-(refRate+devRate+jackpotRate)).div(100);
           balances[investors[i]] = balances[investors[i]] + reward;
           total = total + reward;
        }

        emit PayoutCustomers(total);
    }

    function payoutJackpot() internal {
        address _highestBidder = highestBidder;
        uint256 _jackpotBalance = jackpotBalance;

        address(highestBidder).transfer(_jackpotBalance.mul(100-seed).div(100));
        
        jackpotBalance = _jackpotBalance.mul(seed).div(100);
        highestBidder = 0x0;
        highestBid = 0;

        emit JackpotEnd(_highestBidder, _jackpotBalance);
    }
    
    function payout() public onlyOwner {
        //require (now > roundExpiry);

        payoutCustomers();
        payoutJackpot();

        roundExpiry = now + 24 hours;
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
        require(msg.value >= minDeposit);
        
        if (invested[msg.sender] == 0) {
            investors.push(msg.sender);
            invested[msg.sender] = msg.value;
        } else {
            invested[msg.sender] = invested[msg.sender].add(msg.value);
        }
        
        // 1. Distribute to Devs
        uint256 _devDiv = msg.value.mul(devRate).div(100);
        devBalance = devBalance.add(_devDiv);

        // 2. Distribute to Referral
        uint256 _refDiv = msg.value.mul(refRate).div(100);
        if(address(this).balance > _refDiv && _refDiv > 0 && _referredBy != msg.sender) {
            address(_referredBy).transfer(_refDiv);
        }        

        // 3. Feed Jackpot
        uint256 _jackpotDiv = msg.value.mul(jackpotRate).div(100);
        jackpotBalance = jackpotBalance.add(_jackpotDiv);
        
        // assign new jackpot leader
        if (msg.value > highestBid) {
            highestBidder = msg.sender;
            highestBid = msg.value;
            emit NewLeader(msg.sender, msg.value);
        }
        
        emit Deposit(msg.sender, msg.value);
    }
    
    function() payable public {
        deposit(owner);
    }
    
    function addToJackpot() public payable {
        uint256 _jackpotDiv = msg.value;
        jackpotBalance = jackpotBalance.add(_jackpotDiv);
    }
}
