pragma solidity ^0.4.23;
/**
 * @TronGem Daily ROI
 * Every 24 hours generates 3.35% of deposit value. 
 * Can withdraw every minute, withdraw amount depends on the deposit value and time elapsed since last withdraw
 * For every deposit, contract takes 10% for GEM holder airdrop, 5% for referral(if apply), and 5% for TronGem team.
 * Minimum deposit value is 1 trx, and minimum of 1 trx deposit to activate the referral function
 */


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

contract TronGemDailyROI{

    using SafeMath for uint256;

    mapping(address => uint256) investments;
    mapping(address => uint256) joined;
    mapping(address => uint256) withdrawals;
    mapping(address => uint256) referrer;

    uint256 public interest = 335;  // 3.35% , this number is divided by 10000
    uint256 public minutesElapse = 60*24; // production 60 * 24 to return interest 3.35%
    uint256 public minimum = 1000000; // minimum deposit = 1 trx
    uint256 public stakingRequirement = 1000000; // minimum 100 trx of staking to receive referral bonus
    
    uint256 private referralDivRate = 5; // 5% to valid referrals
    uint256 private devDivRate = 5; // 5% to TronGem platform
    uint256 private airdropDivRate = 10; // 10% to GEM holders airdrop


    address public _vault;  // TronGem Vault address
    address public _airdrop;  // TronGem holder airdrop address
    address public owner;

    event Invest(address investor, uint256 amount);
    event Withdraw(address investor, uint256 amount);
    event Referral(address referrer, uint256 amount);
    /**
     * @dev Сonstructor Sets the original roles of the contract
     */

    constructor() public {
        owner = msg.sender;
        _vault = msg.sender;
        _airdrop = msg.sender;
    }

    /**
     * @dev Modifiers
     */

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
     * @dev Allows current owner to set Vault address.
     */

    function setVault(address a) onlyOwner() public
    {
        _vault = a;
    }

    function setAirdrop(address a) onlyOwner() public
    {
        _airdrop = a;
    }

    /**
     *  Investments
     */
    function () public payable {
        deposit(address(0));
    }

    function deposit(address _referredBy) public payable {
        require(msg.value >= minimum);
        uint256 _incomingTronix = msg.value;
        address _customerAddress = msg.sender;

        // 1. Distribute to Devs
        uint256 _devDiv = _incomingTronix.mul(devDivRate).div(100);
        if(address(this).balance >= _devDiv && _devDiv>0)
        {
            address(_vault).transfer(_devDiv);
        }

        // 2. Distribute referral if applies.
        if(
           // is this a referred purchase?
           _referredBy != address(0) &&

           // no cheating!
           _referredBy != _customerAddress &&

           // does the referrer have at least X whole tokens?
           // i.e is the referrer a godly chad masternode - just 1 trx will do :)
           investments[_referredBy] >= stakingRequirement
       ){
           // wealth redistribution, referral needs to be claimed along with daily roi
          
           uint256 _referralDiv = _incomingTronix.mul(referralDivRate).div(100);

           if(address(this).balance >= _referralDiv && _referralDiv>0)
            {
                 address(_referredBy).transfer(_referralDiv);

                 referrer[_referredBy] = referrer[_referredBy].add(_referralDiv);
                 emit Referral(_referredBy, _referralDiv);
            }

       }
       
        // 3. Distribute to GEM holders airdrop pot
        uint256 _airdropDiv = _incomingTronix.mul(airdropDivRate).div(100);
        if(address(this).balance >= _airdropDiv && _airdropDiv>0)
        {
            address(_airdrop).transfer(_airdropDiv);
        }

       // the rest will be stored in contract

       // new deposit will trigger deposit withdraw first
       if (investments[_customerAddress] > 0){
           if (withdraw()){
               withdrawals[_customerAddress] = 0;
           }
       }

       // add new despoit to curent deposit, and update joined timer
       investments[_customerAddress] = investments[_customerAddress].add(_incomingTronix);
       joined[_customerAddress] = block.timestamp;

       emit Invest(_customerAddress, _incomingTronix);
    }

    /**
    * @dev Evaluate current balance
    * @param _address Address of investor
    */
    function getBalance(address _address) view public returns (uint256) {
        uint256 minutesCount = now.sub(joined[_address]).div(1 minutes); // how many minutes since joined
        uint256 percent = investments[_address].mul(interest).div(10000); // how much to return, step = 100 is 100% return
        uint256 different = percent.mul(minutesCount).div(minutesElapse); //  minuteselapse control the time for example 1 day to receive above interest 
        uint256 balance = different.sub(withdrawals[_address]); // calculate how much can withdraw now

        return balance;
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /**
    * @dev Withdraw dividends from contract
    */
    function withdraw() public returns (bool){
        require(joined[msg.sender] > 0);
        uint256 balance = getBalance(msg.sender);
        if (address(this).balance > balance){
            if (balance > 0){
                withdrawals[msg.sender] = withdrawals[msg.sender].add(balance);
                msg.sender.transfer(balance);
                emit Withdraw(msg.sender, balance);
            }
            return true;
        } else {
            return false;
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
    * @dev Gets all information of the specified address.
    * @param _investor The address to query the the balance of.
    * @return An uint256 representing the amount owned by the passed address.
    */
    function getAllData(address _investor) 
    public view returns (uint256 withdrawn, uint256 withdrawable, uint256 investment, uint256 referral) {
        return (withdrawals[_investor],getBalance(_investor),investments[_investor],referrer[_investor]);
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
    * @param _referrer The address of the referrer
    * @return An uint256 representing the referral earnings.
    */
    function checkReferral(address _referrer) public view returns (uint256) {
        return referrer[_referrer];
    }
}