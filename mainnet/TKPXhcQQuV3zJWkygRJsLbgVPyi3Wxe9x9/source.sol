pragma solidity ^0.4.20;

contract tronpassivepiversion1{
    
    using SafeMath for uint256;

    mapping(address => uint256) investments;
    mapping(address => uint256) public joined;
    mapping(address => uint256) withdrawals;
    mapping(address => uint256) referrer;
    

    uint256 public totalwithdrawals;
    uint256 public totalinvestments;
    uint256 public totalmembers;
    mapping(address => uint256) usertotalwithdrawals;




    uint256 public step = 31;
    uint256 public minimum = 1 * (10 ** 6);
    uint256 public maximum = 100000 * (10 ** 6);
    uint256 public stakingRequirement =100 * (10 ** 6);
    address public ownerWallet;
 
    
   // event Invest(address investor, uint256 amount);
   // event Withdraw(address investor, uint256 amount);
   // event Bounty(address hunter, uint256 amount);
   // event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev ?onstructor Sets the original roles of the contract
     */

    constructor() public {
       
        ownerWallet = msg.sender;
    }


    
    function buy(address _referredBy) public payable {
        require(msg.value >= minimum );
require(now > 1554670799, "Contract is not active"); //21:00:00 GMT April 7 2019
        

        address _customerAddress = msg.sender;

        if(
           // is this a referred purchase?
           _referredBy != address(0) &&

           // no cheating!
           _referredBy != _customerAddress &&

           // does the referrer have at least X whole tokens?
           // i.e is the referrer a godly chad masternode
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

       investments[msg.sender] = investments[msg.sender].add(msg.value.mul(98).div(100));
       joined[msg.sender] = block.timestamp;
       //gia totalinvestment stat
       totalinvestments += msg.value;
       // dev pot wallet 2%
       ownerWallet.transfer(msg.value.mul(1).div(100));
	   
       //emit Invest(msg.sender, msg.value);
    }

    /**
    * @dev Withdraw dividends from contract
    */
    function withdraw() public returns (bool){
        require(joined[msg.sender] > 0);
     
        uint256 count = now.sub(joined[msg.sender]).div(1 seconds);
        require(count > 194);
       
        //require withdrawtimer>4hours
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
                //emit Withdraw(msg.sender, balance);
            }
            return true;
        } else {
            return false;
        }
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
    
    /**
    * @dev Gets balance of the sender address.
    * @return An uint256 representing the amount owned by the msg.sender.
    */
    function checkBalance() public view returns (uint256) {
        return getBalance(msg.sender);
    }

    /**
    * @dev Gets withdrawals of the specified address.
    * @param _investor The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function checkWithdrawals(address _investor) public view returns (uint256) {
        return withdrawals[_investor];
    }

    /**
    * @dev Gets investments of the specified address.
    * @param _investor The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function checkInvestments(address _investor) public view returns (uint256) {
        return investments[_investor];
    }

    /**
    * @dev Gets referrer balance of the specified address.
    * @param _hunter The address of the referrer
    * @return An uint256 representing the referral earnings.
    */
    function checkReferral(address _hunter) public view returns (uint256) {
        return referrer[_hunter];
    }
    

    
    
    
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