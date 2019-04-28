pragma solidity ^0.4.25;
/**
 * ROI Contract
 * Every 24 hours generates 5% of deposit value

 * Commissions: 10% for referral, 2% for marketing and dev，
 * Minimum deposit value is 1 trx
 */
contract Dailyroi{
    mapping(address => uint256) investments;
    mapping(address => uint256) joined;
    mapping(address => uint256) withdrawals;
    mapping(address => uint256) withdrawns;
    mapping(address => uint256) referrer;

    uint256 public interest = 500;  // 5% daily, div 10000
    uint256 public minimum = 1000000; // minimum deposit = 1 trx
    uint256 private referralDivRate = 10; // 10% to valid referrals
    uint256 private devDivRate = 2; // 2% to marketing and dev
    //global stats
    uint256 public globalReferralsDivs_;
    address public devAccount; // devAccount
    event Invest(address investor, uint256 amount);
    event Withdraw(address investor, uint256 amount);
    event Referral(address referrer, uint256 amount);
    /**
     * @dev Сonstructor Sets the original roles of the contract
     */
    constructor() public {
        devAccount = msg.sender;
    }
    function () public payable {
        deposit(address(0));
    }
    function deposit(address _referredBy) public payable {
        require(msg.value >= minimum);
        uint256 _incomingTronix = msg.value;
        address _customerAddress = msg.sender;

        // 1. Distribute to Devs
        uint256 _devDiv = _incomingTronix * devDivRate / 100;
        if(address(this).balance >= _devDiv && _devDiv>0)
        {
            address(devAccount).transfer(_devDiv);
        }
        // 2. Distribute referral if applies.
        uint256 _referralDiv = _incomingTronix * referralDivRate / 100;
        if(
           // is this a referred purchase?
           _referredBy != address(0) &&
           // no cheating!
           _referredBy != _customerAddress
       ){
           // wealth redistribution, referral needs to be claimed along with daily divs
           if(address(this).balance >= _referralDiv && _referralDiv>0)
            {
                 address(_referredBy).transfer(_referralDiv);
                 referrer[_referredBy] = referrer[_referredBy] + _referralDiv;
                 globalReferralsDivs_ = globalReferralsDivs_ + _referralDiv;
                 emit Referral(_referredBy, _referralDiv);
            }
       }else{ 
            // if it is invalid referral, transfer it to vault for marketing
            if(address(this).balance >= _referralDiv && _referralDiv>0)
            {
                address(devAccount).transfer(_referralDiv);
            }
       }
       // the rest will be stored in contract
       // new deposit will trigger deposit withdraw first
       if (investments[_customerAddress] > 0){
           if (withdraw()){
               withdrawals[_customerAddress] = 0;
           }
       }
       // add new despoit to curent deposit, and update joined timer
       investments[_customerAddress] = investments[_customerAddress] + _incomingTronix;
       joined[_customerAddress] = block.timestamp;
       emit Invest(_customerAddress, _incomingTronix);
    }
    /**
    * @dev Evaluate current balance
    * @param _address Address of investor
    */
    function getBalance(address _address) view public returns (uint256) {
        if(joined[_address]>0){
            return investments[_address] * interest * (now - joined[_address])/ 864000000 - withdrawals[_address];
        }else{
            return 0;
        }
    }
    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }
    function globalReferralsDivs() public view returns (uint256) {
        return globalReferralsDivs_;
    }
    function withdraw() public returns (bool){
        require(joined[msg.sender] > 0);
        uint256 balance = getBalance(msg.sender);

        if (address(this).balance < balance){
            balance = address(this).balance;
        }
        if (balance > 0){
            withdrawals[msg.sender] = withdrawals[msg.sender]+ balance;
            withdrawns[msg.sender] = withdrawns[msg.sender]+ balance;
            msg.sender.transfer(balance);
            emit Withdraw(msg.sender, balance);
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
        return (withdrawns[_investor],getBalance(_investor),investments[_investor],referrer[_investor]);
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

