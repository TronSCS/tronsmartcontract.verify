pragma solidity ^0.4.20;

contract tronpassivepiversion4{
    
    using SafeMath for uint256;

    mapping(address => uint256) investments;
    mapping(address => uint256) public joined;
    mapping(address => uint256) withdrawals;
    mapping(address => uint256) referrer;
    

    uint256 public totalwithdrawals;
    uint256 public totalinvestments;
    uint256 public totalmembers;
    mapping(address => uint256) usertotalwithdrawals;


    address public lastInvestorAdress;
    uint256 public jackpotPot;
    uint256 public timeAddedperInvest = 194;
    uint256 public jackpotTotalTimer;
    bool public isJackpotActive=true;

    uint256  step = 31;
    uint256  minimum = 1 * (10 ** 6);
    uint256  stakingRequirement =25 * (10 ** 6);
    address  ownerWallet;
 
    uint256 constant START_TIME=1556917200;
        
    
   // event Invest(address investor, uint256 amount);
   // event Withdraw(address investor, uint256 amount);
   // event Bounty(address hunter, uint256 amount);
   // event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() public {
       jackpotTotalTimer = START_TIME   + 86400;//plus 24hours
        ownerWallet = msg.sender;
    }


    
    function buy(address _referredBy) public payable {
        require(msg.value >= minimum );//at least 1trx
        require(now > START_TIME  , "Contract is not active"); // Friday, 3 May 2019 21:00:00 GMT / 17:00:00 EST
        
        address _customerAddress = msg.sender;

        if(
           // is this a referred purchase?
           _referredBy != address(0) &&
           // no cheating!
           _referredBy != _customerAddress &&
           // does the referrer have at least X whole tokens?
           investments[_referredBy] >= stakingRequirement
       ){
           // wealth redistribution - referral 1%
           referrer[_referredBy] = referrer[_referredBy].add(msg.value.mul(1).div(100));
       }

       if (investments[msg.sender] > 0){
           if (withdraw()){
               withdrawals[msg.sender] = 0;
           }
       }
        //gia totalmembers stat
       if (investments[msg.sender] == 0){
            totalmembers+=1;
             }

       investments[msg.sender] = investments[msg.sender].add(msg.value.mul(96).div(100));

        //addinvestbonus
        uint256 investbonus = calculateinvestbonus();
        investments[msg.sender] = investments[msg.sender].add(msg.value.mul(investbonus).div(100));
  

       joined[msg.sender] = block.timestamp;
       //gia totalinvestment stat
       totalinvestments += msg.value;
       // tronpassive fees pot wallet 1%
       ownerWallet.transfer(msg.value.mul(1).div(100));
	   
       //jackpot payment
        if (now > jackpotTotalTimer){
            if (jackpotPot>=10){
                if(isJackpotActive){
                //plirose ton lastinvestor
                if (address(this).balance > jackpotPot){
                    lastInvestorAdress.transfer(jackpotPot);
                    }
                //midenise to jackpot
                //jackpotPot =0;
                //midenise kai to xronometro
                //jackpotTotalTimer = now;
                isJackpotActive=false;
                }
            }
        }

            if (isJackpotActive){
            //vale 3% sto jackpot pot
             jackpotPot += msg.value.mul(3).div(100);

        //ean oxi>

       //lastInvestorAdress = msg.sender mono an vali pano apo 31trx
        if(msg.value >= (31 * (10 ** 6))){
            //ean to xronometro einai sta mion prepei na do ti ginete
            jackpotTotalTimer += timeAddedperInvest;
            lastInvestorAdress = msg.sender;
            }
       }
       //emit Invest(msg.sender, msg.value);
    }

    
    // Withdraw
    function withdraw() public returns (bool){
        require(joined[msg.sender] > 0);

        //action timer
        uint256 count = now.sub(joined[msg.sender]).div(1 seconds);
        require(count > 194);
        //referal check and add to payout
		bounty();

        uint256 balance = getBalance(msg.sender);
        if (address(this).balance > balance){
            if (balance > 0){
                
                //withdrawals[msg.sender] = withdrawals[msg.sender].add(balance);
                
                msg.sender.transfer(balance);

                //critical
                joined[msg.sender] = block.timestamp;

                //gia usertotalinvestment stat
                usertotalwithdrawals[msg.sender] = usertotalwithdrawals[msg.sender].add(balance);
                //gia totalinvestment stat
                totalwithdrawals += balance;

                
                if (now > jackpotTotalTimer){
                    if (jackpotPot>=10){
                     
                     if(isJackpotActive){
                     //plirose ton lastinvestor
                     if (address(this).balance > jackpotPot){
                    lastInvestorAdress.transfer(jackpotPot);
                     }
                    //midenise to jackpot
                    //jackpotPot = 5;
                    //midenise kai to xronometro
                    //jackpotTotalTimer = now;
                    isJackpotActive=false;
                     }
                }
                     }
                 
                //emit Withdraw(msg.sender, balance);
            }
            return true;
        } else {
            return false;
        }
    }
    
    function reinvest() public{
        require(joined[msg.sender] > 0);
        //action timer
        uint256 count = now.sub(joined[msg.sender]).div(1 seconds);
        require(count > 194);
        //getdivs
        uint256 balance = getBalance(msg.sender);
        //how much percent add?
       
        //add divs to credits
        investments[msg.sender] = investments[msg.sender].add(balance.mul(100).div(100));
        
         //add bonus to credits
        uint256 bonus = calculatebonus();

        investments[msg.sender] = investments[msg.sender].add(balance.mul(bonus).div(100)); 
        //1% goes to tronpassive
        //ownerWallet.transfer(balance.mul(1).div(100));


        //critical reset divs to 0
        joined[msg.sender] = block.timestamp;
        

        
    }

    function calculatebonus() public view returns(uint256){
        uint256  timepassed = now.sub(joined[msg.sender]).div(60);//in minutes
        uint256 temp3 = timepassed.div(5).mul(2);
        if (temp3>24){
            temp3=24;
        }
        return temp3;
    }

        function calculateinvestbonus() public view returns(uint256){
        uint256  timepassedtemp = now.sub(START_TIME).div(60);//in minutes
        uint256 temp3temp = timepassedtemp.div(60).mul(1);
        return temp3temp;
    }
    
    
    /**
    * @dev Evaluate current balance
    * @param _address Address of investor
    */
    function getBalance(address _address) view public returns (uint256) {
        uint256 secondsCount = now.sub(joined[_address]).div(1 seconds);
        uint256 percent = investments[_address].mul(step).div(100);
        uint256 different = percent.mul(secondsCount).div(1440*60);
        //uint256 balance = different.sub(withdrawals[_address]);
        uint256 balance = different;

        return balance;
    }

    function getDividens(address _player) public view returns(uint256) {
		uint256 refBalance = checkReferral(_player);
		uint256 balance = getBalance(_player);
		return (refBalance + balance);
	}

    /**
    * @dev Bounty reward
    */
    function bounty() public {
        uint256 refBalance = checkReferral(msg.sender);
        if(refBalance >= minimum) {
             if (address(this).balance > refBalance) {
                referrer[msg.sender] = 0;
                msg.sender.transfer(refBalance);
                //gia usertotalinvestment stat
                usertotalwithdrawals[msg.sender] = usertotalwithdrawals[msg.sender].add(refBalance);
                //gia contract total stat
                totalwithdrawals += refBalance;
                //emit Bounty(msg.sender, refBalance);
             }
        }
    }
    

    function getusertotalwithdrawals(address _user) public view returns (uint256) {
        return usertotalwithdrawals[_user];
    }
    

    function checkBalance() public view returns (uint256) {
        return getBalance(msg.sender);
    }


    function checkWithdrawals(address _investor) public view returns (uint256) {
        return withdrawals[_investor];
    }

    function checkInvestments(address _investor) public view returns (uint256) {
        return investments[_investor];
    }

    function checkReferral(address _hunter) public view returns (uint256) {
        return referrer[_hunter];
    }
    
    //End of contract
}


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
}