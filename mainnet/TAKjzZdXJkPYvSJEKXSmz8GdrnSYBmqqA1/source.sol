pragma solidity ^0.4.24;

/***********************************************************
 *  YinYang DailyROI contract for BTT 
 *  Get 2% of investments - Every 24 hours while contract has BTT
 *  Get 7% affiliate reward
 *	5% for marketing / development
 *  Automatic smart contract. Absolute transparency. Withdraw dividends from the first minute 
 
 *  https://www.yinyang.biz
 
 ***********************************************************/

contract YY_DailyROI {

    using SafeMath for uint256;

    mapping(address => uint256) investments;
    mapping(address => uint256) joined;
    mapping(address => uint256) withdrawals;
    mapping(address => uint256) referrer;

    uint256 public step = 2;
    uint256 public minimum = 1000000;
    uint256 public stakingRequirement = 1000000;
    address public Dev_Marketing1;
    address public Dev_Marketing2;
    address public Dev_Marketing3;
    address public owner;

    event Invest(address investor, uint256 amount);
    event Withdraw(address investor, uint256 amount);
    event Bounty(address hunter, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev ?onstructor Sets the original roles of the contract
     */

    constructor() public {
        owner = msg.sender;
        Dev_Marketing1 = msg.sender;
        Dev_Marketing2 = msg.sender;
        Dev_Marketing3 = msg.sender;
    }

    /**
     * @dev Modifiers
     */

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Allows current owner to transfer control of the contract to a newOwner.
     * @param newOwner The address to transfer ownership to.
     */
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setDev_Marketing1(address newDev_Marketing1) public onlyOwner {
        require(newDev_Marketing1 != address(0));
        Dev_Marketing1 = newDev_Marketing1;
    }
    
    function setDev_Marketing2(address newDev_Marketing2) public onlyOwner {
        require(newDev_Marketing2 != address(0));
        Dev_Marketing2 = newDev_Marketing2;
    }

    function setDev_Marketing3(address newDev_Marketing3) public onlyOwner {
        require(newDev_Marketing3 != address(0));
        Dev_Marketing3 = newDev_Marketing3;
    }

    function buy(address _referredBy) public payable {
        require(msg.tokenid==1002000);
        require(msg.tokenvalue >= minimum);

        address _customerAddress = msg.sender;

        if(
           // is this a referred purchase?
           _referredBy != 0x0000000000000000000000000000000000000000 &&

           // no cheating!
           _referredBy != _customerAddress &&

           // does the referrer have at least X whole tokens?
           // i.e is the referrer a godly chad masternode
           investments[_referredBy] >= stakingRequirement
       ){
           // wealth redistribution
           referrer[_referredBy] = referrer[_referredBy].add(msg.tokenvalue.mul(7).div(100));
       }

       if (investments[msg.sender] > 0){
           if (withdraw()){
               withdrawals[msg.sender] = 0;
           }
       }
       investments[msg.sender] = investments[msg.sender].add(msg.tokenvalue);
       joined[msg.sender] = block.timestamp;
       trcToken id = 1002000;
       Dev_Marketing1.transferToken(msg.tokenvalue.mul(2).div(100),id);
       Dev_Marketing2.transferToken(msg.tokenvalue.mul(2).div(100),id);
       Dev_Marketing3.transferToken(msg.tokenvalue.mul(1).div(100),id);
       
       emit Invest(msg.sender, msg.tokenvalue);
    }

    /**
    * @dev Evaluate current balance
    * @param _address Address of investor
    */
    function getBalance(address _address) view public returns (uint256) {
        uint256 minutesCount = now.sub(joined[_address]).div(1 minutes);
        uint256 percent = investments[_address].mul(step).div(100);
        uint256 different = percent.mul(minutesCount).div(1440);
        uint256 balance = different.sub(withdrawals[_address]);

        return balance;
    }

    /**
    * @dev Withdraw dividends from contract
    */
    function withdraw() public returns (bool){
        require(joined[msg.sender] > 0);
        uint256 balance = getBalance(msg.sender);
        if (totalBttBalance() > balance){
            if (balance > 0){
                withdrawals[msg.sender] = withdrawals[msg.sender].add(balance);
                trcToken id = 1002000;
                msg.sender.transferToken(balance, id);
                emit Withdraw(msg.sender, balance);
            }
            refWithdraw();
            return true;
        } else {
            return false;
        }
    }

    /**
    * @dev Bounty reward
    */
    function refWithdraw() public {
        uint256 refBalance = checkReferral(msg.sender);
        if(refBalance >= minimum) {
             if (totalBttBalance() > refBalance) {
                referrer[msg.sender] = 0;
                trcToken id = 1002000;
                msg.sender.transferToken(refBalance, id);
                emit Bounty(msg.sender, refBalance);
             }
        }
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
    function totalBttBalance() public view returns (uint256) {
        return address(this).tokenBalance(1002000);
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