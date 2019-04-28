pragma solidity ^0.4.18;

contract TronBrains {
    
    mapping (address => uint256) public deposit;
    mapping (address => uint256) public lastInvest;
    
    mapping (address => uint256) private affiliateCommision;

    function deposit() public payable {

        require(now > 1555376400);
        
        require(msg.value >= 1000000);
        
        if(getProfit(msg.sender) > 0){
            uint256 profit = getProfit(msg.sender);
            lastInvest[msg.sender] = now;
            msg.sender.transfer(profit);
        }
        
        uint256 amount = msg.value;
        uint256 commision = SafeMath.div(SafeMath.mul(commision, 1), 200);

        affiliateCommision[address1] = SafeMath.add(SafeMath.div(SafeMath.mul(5, msg.value), 100), affiliateCommision[address1]);
        
        lastInvest[msg.sender] = now;
        deposit[msg.sender] = SafeMath.add(deposit[msg.sender], amount);
    }
    
    function takeProfits() public{
        uint256 profit = getProfit(msg.sender);
        require(profit > 0);
        lastInvest[msg.sender] = now;
        msg.sender.transfer(profit);
    }
    
    function getProfitFromSender() public view returns(uint256){
        return getProfit(msg.sender);
    }

    function getProfit(address customer) public view returns(uint256){
        uint256 secondsPassed = SafeMath.sub(now, lastInvest[customer]);
        return SafeMath.div(SafeMath.mul(SafeMath.div(SafeMath.mul(getRate(), deposit[customer]), 10000000), secondsPassed), 86400);
    }

    function getRate() public view returns(uint256){
        uint256 secondsPassed = SafeMath.sub(now, lastInvest[msg.sender]);
        return SafeMath.add(2500000, SafeMath.div(SafeMath.mul(SafeMath.div(SafeMath.mul(100, 50000), 100), secondsPassed), 86400));
    }
    
    function getAffiliateCommision() public view returns(uint256){
        return affiliateCommision[msg.sender];
    }
    
    function withdrawAffiliateCommision() public {
        require(affiliateCommision[msg.sender] > 0);
        uint256 commision = affiliateCommision[msg.sender];
        affiliateCommision[msg.sender] = 0;
        msg.sender.transfer(commision);
    }
    
    function getInvested() public view returns(uint256){
        return deposit[msg.sender];
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
    
    function max(uint256 a, uint256 b) private pure returns (uint256) {
        return a > b ? a : b;
    }

    address private address1 = 0x0;

    constructor(address address1_) public {
        address1 = address1_;
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