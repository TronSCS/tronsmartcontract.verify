pragma solidity ^0.4.25;

contract FastROI {
    
    mapping (address => uint256) public tronDeposit;
    mapping (address => uint256) public timeStamp;

    mapping (address => uint256) public totalWithdrawn;
    mapping (address => uint256) public affiliateEarned;

    mapping (address => uint256) public affiliateWallet;

    mapping (address => uint256) public withdrawTimer;
    
    function depositTron(address affiliate) public payable {

        require(now > 1554411600, "Contract is not active"); //5PM EST Thursday April 4 2019
        
        require(msg.value >= 1000000);
        
        if(getProfit(msg.sender) > 0){
            uint256 profit = getProfit(msg.sender);
            timeStamp[msg.sender] = now;
            withdrawTimer[msg.sender] = now;
            totalWithdrawn[msg.sender] = SafeMath.add(totalWithdrawn[msg.sender], profit);
            msg.sender.transfer(profit);
        }
        
        uint256 commision = SafeMath.div(SafeMath.mul(msg.value, 10), 100);
        if(affiliate != msg.sender && affiliate != 0x1){
            affiliateWallet[affiliate] = SafeMath.add(affiliateWallet[affiliate], commision);
        }
        
        uint256 otherCommision = SafeMath.div(SafeMath.mul(msg.value, 5), 100);

        /* send tron to feed TronDeposit */
        affiliateWallet[tronDepositAddress] = SafeMath.add(affiliateWallet[tronDepositAddress], otherCommision);
        affiliateWallet[address1] = SafeMath.add(affiliateWallet[address1], otherCommision);
        affiliateWallet[address2] = SafeMath.add(affiliateWallet[address2], otherCommision);
        affiliateWallet[address3] = SafeMath.add(affiliateWallet[address3], SafeMath.div(SafeMath.mul(msg.value, 1), 100));

        timeStamp[msg.sender] = now;
        if(tronDeposit[msg.sender] == 0){
            withdrawTimer[msg.sender] = SafeMath.sub(now, 7200);
        }
        tronDeposit[msg.sender] = SafeMath.add(tronDeposit[msg.sender], msg.value);
    }

    function canWithdraw() public view returns(bool){
        return now - withdrawTimer[msg.sender] > 7200;
    }

    function getWithdrawTimer() public view returns(uint256){
        return withdrawTimer[msg.sender];
    }
    
    function withdraw() public{
        require(canWithdraw(), "wait");
        uint256 profit = getProfit(msg.sender);
        require(profit > 0);
        timeStamp[msg.sender] = now;
        withdrawTimer[msg.sender] = now;
        totalWithdrawn[msg.sender] = SafeMath.add(totalWithdrawn[msg.sender], profit);
        msg.sender.transfer(profit);
    }

    function withdrawAffiliate() public{
        uint256 profit = affiliateWallet[msg.sender];
        require(profit > 0);
        affiliateWallet[msg.sender] = 0;
        affiliateEarned[msg.sender] = SafeMath.add(affiliateEarned[msg.sender], profit);
        msg.sender.transfer(profit);
    }

    function getWithdrawn() public view returns(uint256){
        return totalWithdrawn[msg.sender];
    }
    
    function getProfitFromSender() public view returns(uint256){
        return getProfit(msg.sender);
    }

    function getProfit(address customer) public view returns(uint256){
        uint256 secondsPassed = SafeMath.sub(now, timeStamp[customer]);
        return SafeMath.div(SafeMath.mul(SafeMath.div(SafeMath.mul(44, tronDeposit[customer]), 100), secondsPassed), 86400);
    }
    
    function getAffiliateEarned() public view returns(uint256){
        return affiliateEarned[msg.sender];
    }

    function getRefWallet() public view returns(uint256){
        return affiliateWallet[msg.sender];
    }
    
    function getDeposit() public view returns(uint256){
        return tronDeposit[msg.sender];
    }
    
    address public address1 = 0x0;
    address public address2 = 0x0;
    address public address3 = 0x0;

    address public tronDepositAddress = 0x0;

    constructor(address tronDepositAddress_, address address1_, address address2_, address address3_) public {
        tronDepositAddress = tronDepositAddress_;
        address1 = address1_;
        address2 = address2_;
        address3 = address3_;
    }
}

library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}