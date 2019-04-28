pragma solidity ^0.4.25;

contract FastROI {
    
    mapping (address => uint256) public tronDeposit;
    mapping (address => uint256) public timeStamp;

    uint256 public referralPayouts = 0;

    mapping (address => uint256) public totalWithdrawn;
    mapping (address => uint256) public affiliateEarned;

    mapping (address => uint256) public affiliateWallet;
    
    function depositTron(address affiliate) public payable {

        require(now > 1553976000); //4PM EST Saturday March 30 2019
        
        require(msg.value >= 1000000);
        
        if(getProfit(msg.sender) > 0){
            uint256 profit = getProfit(msg.sender);
            timeStamp[msg.sender] = now;
            msg.sender.transfer(profit);
        }
        
        uint256 commision = SafeMath.div(SafeMath.mul(msg.value, 10), 100);
        if(affiliate != msg.sender && affiliate != 0x1 && affiliate != developer && affiliate != marketer){
            affiliateWallet[affiliate] = SafeMath.add(affiliateWallet[affiliate], commision);
            referralPayouts = SafeMath.add(referralPayouts, commision);
        }
        
        uint256 otherCommision = SafeMath.div(SafeMath.mul(msg.value, 5), 100);
        affiliateWallet[developer] = SafeMath.add(affiliateWallet[developer], otherCommision);
        affiliateWallet[marketer] = SafeMath.add(affiliateWallet[marketer], otherCommision);
        
        tronDeposit[msg.sender] = SafeMath.add(tronDeposit[msg.sender], msg.value);
        timeStamp[msg.sender] = now;
    }
    
    function withdraw() public{
        uint256 profit = getProfit(msg.sender);
        require(profit > 0);
        timeStamp[msg.sender] = now;
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
        return SafeMath.div(SafeMath.mul(SafeMath.div(SafeMath.mul(75, tronDeposit[customer]), 100), secondsPassed), 86400);
    }
    
    function getAffiliateEarned() public view returns(uint256){
        return affiliateEarned[msg.sender];
    }

    function getRefWallet() public view returns(uint256){
        return affiliateWallet[msg.sender];
    }

    function getReferralPayouts() public view returns(uint256){
        return referralPayouts;
    }
    
    function getDeposit() public view returns(uint256){
        return tronDeposit[msg.sender];
    }
    
    address public developer = 0x0;
    address public marketer = 0x0;

    constructor(address developer_, address marketer_) public {
        developer = developer_;
        marketer = marketer_;
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