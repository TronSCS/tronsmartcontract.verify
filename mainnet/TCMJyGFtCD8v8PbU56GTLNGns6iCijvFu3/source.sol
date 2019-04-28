pragma solidity ^0.4.23;
/**
 * RocketDynamicContract
 * First ever ROI with variable % depending on the contract balance.
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

contract RocketDynamic{

    using SafeMath for uint256;

    mapping(address => uint256) investments;
    mapping(address => uint256) joined;
    mapping(address => uint256) withdrawals;
    mapping(address => uint256) withdrawns;
    mapping(address => uint256) referrer;

    uint256 public interest = 1500;  // 15% base rate, this number is divided by 10000
    uint256 public minutesElapse = 60*24; // production 60 * 24 
    uint256 public minimum = 1000000; // minimum deposit = 1 trx
   
    uint256 private referralDivRate = 125; // 
    uint256 private devDivRate = 125; // 


    //global stats
    uint256 public globalReferralsDivs_;

    address public _vault;  // Vault address

    event Invest(address investor, uint256 amount);
    event Withdraw(address investor, uint256 amount);
    event Referral(address referrer, uint256 amount);
    /**
     * @dev Constructor Sets the original roles of the contract
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
        require(msg.value >= minimum);
        uint256 _incomingTronix = msg.value;
        address _customerAddress = msg.sender;

        // 1. Distribute to Devs
        uint256 _devDiv = _incomingTronix.mul(devDivRate).div(1000);
        if(address(this).balance >= _devDiv && _devDiv>0)
        {
            address(_vault).transfer(_devDiv);
        }

        // 2. Distribute referral if applies.
        uint256 _referralDiv = _incomingTronix.mul(referralDivRate).div(1000);

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
                 emit Referral(_referredBy, _referralDiv);
            }

       }else{ 
            // if it is invalid referral, transfer it to vault for marketing

            if(address(this).balance >= _referralDiv && _referralDiv>0)
            {
                address(_vault).transfer(_referralDiv);
            }

       }

       // the rest will be stored in contract

       // new deposit will trigger deposit withdraw first
       if (investments[_customerAddress] > 0){
           if (withdraw()){
               withdrawals[_customerAddress] = 0;
           }
       }

       // add new deposit to current deposit, and update joined timer
       investments[_customerAddress] = investments[_customerAddress].add(_incomingTronix);
       joined[_customerAddress] = block.timestamp;

       emit Invest(_customerAddress, _incomingTronix);
    }

    /**
    * @dev Evaluate current balance
    * @param _address Address of investor
    */
    function getBalance(address _address) view public returns (uint256) {
        if(joined[_address]>0)
        {
            uint256 minutesCount = now.sub(joined[_address]).div(1 minutes); // how many minutes since joined
            uint256 percent = investments[_address].mul(getDynamicPercentage()).div(10000); // how much to return, step = 100 is 100% return
            uint256 different = percent.mul(minutesCount).div(minutesElapse); //  minuteselapse control the time for example 1 day to receive above interest 
            uint256 balance = different.sub(withdrawals[_address]); // calculate how much can withdraw now

            return balance;
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
    /**
    * @dev Withdraw dividends from contract
    */
    function withdraw() public returns (bool){
        require(joined[msg.sender] > 0);
        uint256 balance = getBalance(msg.sender);

        if (address(this).balance < balance){
            balance = address(this).balance;
        }

        if (balance > 0){
            withdrawals[msg.sender] = withdrawals[msg.sender].add(balance);
            withdrawns[msg.sender] = withdrawns[msg.sender].add(balance);
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

    function getPercentage() public view returns (uint256) {
        return getDynamicPercentage() * 10000;
    }

    function getDynamicPercentage() public view returns (uint256) {
        uint totalPot = getContractBalance();
        if (totalPot <= 1e12) { 
            return interest; // 15%
        } else if (totalPot > 1e12 && totalPot <= 2e12) {
            return (uint256) (interest  + 500); // 20%
        } else if (totalPot > 2e12 && totalPot <= 3e12) {
            return (uint256) (interest  + 1000); // 25%
        } else if (totalPot > 3e12 && totalPot <= 4e12) {
            return (uint256) (interest  + 1500); // 30%
        } else if (totalPot > 4e12 && totalPot <= 5e12) {
            return (uint256) (interest  + 2000); // 35%
        } else if (totalPot > 5e12 && totalPot <= 7e12) {
            return (uint256) (interest  + 3000); // 45%
        } else if (totalPot > 7e12 && totalPot <= 10e12) {
            return (uint256) (interest  + 4000); // 55%
        } else if (totalPot > 10e12 && totalPot <= 15e12) {
            return (uint256) (interest  + 5000); // 65%
        } else if (totalPot > 15e12 && totalPot <= 20e12) {
            return (uint256) (interest  + 6000); // 75%
        } else if (totalPot > 20e12 && totalPot <= 30e12) {
            return (uint256) (interest  + 7000); // 85%
        } else if (totalPot > 30e12 && totalPot <= 40e12) {
            return (uint256) (interest  +8000); // 95%
        }  else {
            return interest + 9000; // 105%
        }
    }
}

