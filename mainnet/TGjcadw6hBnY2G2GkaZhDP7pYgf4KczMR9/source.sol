pragma solidity ^0.4.25;

/***********************************************************
 * TronPaysTRX contract
 * 
 * Receive 2% PER DAY Plus optionally 2% of your deposit unless contract runs out of trx
 * Contract can be feed by transferring trx to contract address
 * 
 * Developer Fee: 2% of buy
 * Dapp Fee: 3% of buy and used to support other dapp
 * 
 * Referral Reward: 2% of buy
 * 
 * At least 93% of all deposits are in contract to give back to those that deposited.
 *  
 *  https://TronPays.com
 */
 
contract TronPaysTRX {

    using SafeMath for uint256;

    mapping(address => uint256) deposits;
    mapping(address => uint256) joined;
    mapping(address => uint256) lastwithdrawtime;
    mapping(address => uint256) withdrawals;
    mapping(address => uint256) referrer;
    mapping(address => uint256) totwithdraws;

    uint256 public rate = 2;
    uint256 public DepositWithdrawRate = 2; // Option to withdraw 2 percent of deposit
    uint256 public devFee = 2;
    uint256 public dappFee = 3;
    uint256 public refReward = 2;
    uint256 public users = 0;
    uint256 public minimum = 1000000;
    uint256 public stakingRequirement = 1000000;
    uint256 public totaldeposited=0;
    uint256 public totalwithdrawn=0;
    uint256 public totaldonated=0;
    address public devAddr;
    address public dappAddr;
    address public owner;

    event DepositTRX(address depositor, address referredBy, uint256 amount);
    event Withdraw(address depositor, uint256 amount);
    event WithdrawPlus(address depositor, uint256 total, uint256 depositback);
    event Reward(address _address, uint256 amount);
    event Donated(address _address, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev ?onstructor Sets the original roles of the contract
     */

    constructor() public {
        owner = msg.sender;
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

    function setDevAddr(address newdevAddr) public onlyOwner {
        devAddr = newdevAddr;
    }
    
    
    function setDappAddr(address newdappAddr) public onlyOwner {
        dappAddr = newdappAddr;
    }
    
    // this function called every time anyone sends a transaction to this contract
    // dapps can simply send trx to contract to feed it
    function () external payable {
        
    } 
    
    function donate() public payable {
        totaldonated = totaldonated.add(msg.value);
        emit Donated(msg.sender, msg.value);
    }
    
    function buy(address _customerAddress, address _referredBy) public payable {
        require(msg.value >= minimum);
        if(
           // is this a referred purchase?
           _referredBy != address(0) &&

           // no cheating!
           _referredBy != _customerAddress &&

           // does the referrer have at least X whole tokens?
           // i.e is the referrer a godly chad masternode
           deposits[_referredBy] >= stakingRequirement
       ){
           // wealth redistribution
           referrer[_referredBy] = referrer[_referredBy].add(msg.value.mul(refReward).div(100));
       }

       if (deposits[_customerAddress] > 0){
           if (withdraw(_customerAddress)){
               withdrawals[_customerAddress] = 0;
           }
       } else {
           users += 1;
       }
       totaldeposited = totaldeposited.add(msg.value);
       deposits[_customerAddress] = deposits[_customerAddress].add(msg.value);
       joined[_customerAddress] = block.timestamp;
        if (lastwithdrawtime[_customerAddress] == 0) lastwithdrawtime[_customerAddress] = block.timestamp;
       devAddr.transfer(msg.value.mul(devFee).div(100));
       dappAddr.transfer(msg.value.mul(dappFee).div(100));

       emit DepositTRX(_customerAddress, _referredBy, msg.value);
    }

    function getContractBalance() public 
        view returns(uint256)
    {
		return address(this).balance;
    }
	
    /**
    * @dev Evaluate current balance
    * @param _address Address of depositor
    */
    function getBalance(address _address) view public returns (uint256) {
        uint256 minutesCount = now.sub(joined[_address]).div(1 minutes);
        uint256 percent = deposits[_address].mul(rate).div(100);
        uint256 different = percent.mul(minutesCount).div(1440);
        uint256 balance = different.sub(withdrawals[_address]);

        return balance;
    }
    
    /**
    * @dev Withdraw dividends from contract
    */
    function withdraw(address _customerAddress) public returns (bool){
        require(joined[_customerAddress] > 0);
        uint256 balance = getBalance(_customerAddress);
        uint256 referral = checkReferral(_customerAddress);
        if (address(this).balance >= balance + referral){
            if (balance + referral > 0){
                withdrawals[_customerAddress] = withdrawals[_customerAddress].add(balance);
                balance = balance + referral;
                referrer[_customerAddress] = 0;
                totwithdraws[_customerAddress] = totwithdraws[_customerAddress].add(balance);
                totalwithdrawn = totalwithdrawn.add(balance);
                _customerAddress.transfer(balance);
                emit Withdraw(_customerAddress, balance);
            }
            return true;
        } else {
            return false;
        }
    }
    
    /**
    * @dev Withdraw dividends from contract plus 2% of your deposit
    */
    function withdrawplusrate(address _customerAddress) public returns (bool){
        require(msg.sender == _customerAddress);
        require(joined[_customerAddress] > 0);
        uint256 balance = getBalance(_customerAddress);
        uint256 referral = checkReferral(_customerAddress);
        uint256 withper = 0;
        bool totalwithdraw = false;
        if (deposits[_customerAddress] > 0) {
            if (block.timestamp >= lastwithdrawtime[_customerAddress].add(23 hours)) {
                withper = deposits[_customerAddress].mul(DepositWithdrawRate).div(100);
                // Allow total withdraw if 100 TRX or less in their deposits
                if (deposits[_customerAddress] <= 100000000) {
                    withper = deposits[_customerAddress];
                    totalwithdraw = true;
                }
            }
        }
        if (address(this).balance >= balance + referral + withper){
            if (balance + referral + withper > 0){
                if (withper>0) {
                    joined[_customerAddress] = block.timestamp;
                    withdrawals[_customerAddress] = 0;
                    lastwithdrawtime[_customerAddress] = block.timestamp;
                    deposits[_customerAddress] = deposits[_customerAddress].sub(withper);
                    if (totalwithdraw == true) users -= 1;
                } else {
                    withdrawals[_customerAddress] = withdrawals[_customerAddress].add(balance);
                }
                balance = balance + referral + withper;
                totalwithdrawn = totalwithdrawn.add(balance);
                totaldeposited = totaldeposited.sub(withper);
                referrer[_customerAddress] = 0;
                totwithdraws[_customerAddress] = totwithdraws[_customerAddress].add(balance);
                _customerAddress.transfer(balance);
                emit WithdrawPlus(_customerAddress, balance, withper);
            }
            return true;
        } else {
            return false;
        }
    }

    /**
    * @dev Referral reward
    */
    function refWithdraw() public {
        uint256 refBalance = checkReferral(msg.sender);
        if(refBalance >= minimum) {
             if (address(this).balance > refBalance) {
                referrer[msg.sender] = 0;
                totwithdraws[msg.sender] = totwithdraws[msg.sender].add(refBalance);
                msg.sender.transfer(refBalance);
                emit Reward(msg.sender, refBalance);
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
    * @param _depositor The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function checkWithdrawals(address _depositor) public view returns (uint256) {
        return withdrawals[_depositor];
    }

    /**
    * @dev Gets deposits of the specified address.
    * @param _depositor The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function checkdeposits(address _depositor) public view returns (uint256) {
        return deposits[_depositor];
    }
    
    /**
    * @dev Gets lastwithdrawtime
    * @param _depositor The address to query the lastwithdrawtime
    * @return An uint256 representing the lastwithdrawtime
    */
    function minutesSinceListWithdrawDeposit(address _depositor) public view returns (uint256) {
        if (lastwithdrawtime[_depositor]>0) {
            return now.sub(lastwithdrawtime[_depositor]).div(1 minutes);
        } else {
            return 0;
        }
    }

    /**
    * @dev Gets Total Withdrawals of the specified address.
    * @param _depositor The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function checkTotalWithdrawal(address _depositor) public view returns (uint256) {
        return totwithdraws[_depositor];
    }

    /**
    * @dev Gets referrer balance of the specified address.
    * @param _referrer The address of the referrer
    * @return An uint256 representing the referral earnings.
    */
    function checkReferral(address _referrer) public view returns (uint256) {
        return referrer[_referrer];
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