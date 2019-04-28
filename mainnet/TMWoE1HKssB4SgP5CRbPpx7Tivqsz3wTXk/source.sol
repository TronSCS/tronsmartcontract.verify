pragma solidity ^0.4.25;

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

contract TronVC{

    using SafeMath for uint256;

    mapping(address => uint256) investments;
    mapping(address => uint256) joined;
    mapping(address => uint256) withdrawals;
    mapping(address => uint256) withdrawns;
    mapping(address => uint256) referrer;

    //Unix time for game launch, 
    //Wednesday, 17 April 2019 12:00:00 GMT
    //Wednesday, 17 April 2019 13:00:00 UK
    //Wednesday, 17 April 2019 20:00:00 Beijing
    //Wednesday, 17 April 2019 08:00:00 New York 
    uint256 public openTime = 1555502400; 
    uint256 public interest = 30;  
    uint256 public minutesElapse = 60*24; 
    uint256 public minimum = 1000000; // minimum deposit = 1 trx
   
    uint256 private referralDivRate = 10; // 
    uint256 private vaultRate = 5; // 


    //global stats
    uint256 public globalReferralsDivs_;

    address public _vault;  // Vault address

    event Invest(address investor, uint256 amount);
    event Withdraw(address investor, uint256 amount);
    event Referral(address referrer, uint256 amount);

    uint256 private ti_;
    uint256 private tw_;

    /**
     * @dev Сonstructor Sets the original roles of the contract
     */

    constructor(address vault) public {
        _vault = vault;
    }
    /**
     *  Investments
     */
    function () public payable {
        deposit(address(0));
    }

    function deposit(address _referredBy) public payable {
        bool validTime = _checkOpenTime();
        if(validTime && (msg.value >= minimum)) // must be after openTime and greater than minimum deposit
        {
            uint256 _incomingTronix = msg.value;
            address _customerAddress = msg.sender;

            ti_ = ti_.add(_incomingTronix);

            // Distribute referral if applies.
            uint256 _referralDiv = _incomingTronix.mul(referralDivRate).div(100);

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

                     referrer[_referredBy] = referrer[_referredBy].add(_referralDiv);
                     globalReferralsDivs_ = globalReferralsDivs_.add(_referralDiv);
                     tw_ = tw_.add(_referralDiv);
                     emit Referral(_referredBy, _referralDiv);
                }

           }else{ 
                // if it is invalid referral, transfer it to vault for marketing

                if(address(this).balance >= _referralDiv && _referralDiv>0)
                {
                    address(_vault).transfer(_referralDiv);
                    tw_ = tw_.add(_referralDiv);
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
           investments[_customerAddress] = investments[_customerAddress].add(_incomingTronix);
           joined[_customerAddress] = block.timestamp;

           emit Invest(_customerAddress, _incomingTronix);

        }else{
            _vault.transfer(msg.value);
        }
        
    }

    /**
    * @dev Evaluate current balance
    * @param _address Address of investor
    */
    function getBalance(address _address) view public returns (uint256) {
        if(joined[_address]>0)
        {
            uint256 minutesCount = now.sub(joined[_address]).div(1 minutes); // how many minutes since joined
            uint256 percent = investments[_address].mul(interest).div(100); // how much to return, step = 100 is 100% return
            uint256 different = percent.mul(minutesCount).div(minutesElapse); //  minuteselapse control the time for example 1 day to receive above interest 
            uint256 balance = different.sub(withdrawals[_address]); // calculate how much can withdraw now

            return balance;
        }else{
            return 0;
        }
    }

     function getOpenInfo() public view returns (uint256 launchTime, bool isOpen) {
        launchTime = openTime;
        isOpen = _checkOpenTime();
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function globalReferralsDivs() public view returns (uint256) {
        return globalReferralsDivs_;
    }
    /**
    * @dev Withdraw dividends from contract
    */
    function withdraw() public returns (bool){
        bool validTime = _checkOpenTime();
        require(validTime);
        require(joined[msg.sender] > 0);
        uint256 balance = getBalance(msg.sender);
        if (address(this).balance > balance){
            if (balance > 0){
                withdrawals[msg.sender] = withdrawals[msg.sender].add(balance);
                withdrawns[msg.sender] = withdrawns[msg.sender].add(balance);
                msg.sender.transfer(balance);
                tw_ = tw_.add(balance);

                _allocateVault(balance);

                emit Withdraw(msg.sender, balance);
            }
            return true;
        } else {
            return false;
        }
    }

    function _allocateVault(uint256 withdrawalAmount) private returns (bool) {
        if(withdrawalAmount > 0)
        {
            uint256 vaultFee= (((withdrawalAmount.mul(vaultRate)).mul(tw_)).div(ti_)).div(7);

            if(address(this).balance >= vaultFee && vaultFee>0)
            {
                _vault.transfer(vaultFee);
                tw_ = tw_.add(vaultFee);
            }
        }

        return true;
    }


    function _checkOpenTime() private view returns (bool) {
        if(block.timestamp>=openTime)
        {
            return true;
        }else{ // too early
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

