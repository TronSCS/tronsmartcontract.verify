pragma solidity ^0.4.18;

contract TronHEX{

    /* Contract-only Token (not TRC); */
    mapping (address => uint256) public tokenBalance;
    uint256 tokenPriceTimestamp = 1551915024;
    uint256 public tokenSupply = 0;
    
    /* Investment Program */
    mapping (address => uint256) public activeInvestment;
    mapping (address => uint256) public lastInvest;
    mapping (address => uint256) public totalInvestmentProfitEarned;
    uint256 dailyVariationRate = 0;

    /* Staking Program */
    mapping (address => uint256) public activeStake;
    mapping (address => uint256) public lastStake;
    mapping (address => uint256) public totalStakingProfitEarned;
    
    /* Affiliate Program*/
    mapping (address => uint256) public affiliateCommision;
    mapping (address => uint256) public totalAffiliateCommisionEarned;

    /* EXCHANGE START */
    function purchaseHEXTokens() public payable {
        require(msg.value >= 1000000);

        uint256 amountOfTokensToReceive = SafeMath.div(SafeMath.mul(msg.value, 1000000), getTokenPrice());

        tokenSupply = SafeMath.add(tokenSupply, amountOfTokensToReceive);
        tokenBalance[msg.sender] = SafeMath.add(tokenBalance[msg.sender], amountOfTokensToReceive);
    }

    function sellHEXTokens(uint256 amountToSell) public {
        require(amountToSell >= 1000000 && tokenBalance[msg.sender] >= amountToSell);

        uint256 amountOfTRXToReceive = SafeMath.mul(getTokenPrice(), amountToSell);
        uint256 fee = SafeMath.div(SafeMath.mul(amountOfTRXToReceive, 2), 100);
        uint256 commision = SafeMath.div(SafeMath.mul(amountOfTRXToReceive, 5), 100);

        amountOfTRXToReceive = SafeMath.sub(amountOfTRXToReceive, fee);

        tokenSupply = SafeMath.sub(tokenSupply, amountToSell);
        tokenBalance[msg.sender] = SafeMath.sub(tokenBalance[msg.sender], amountToSell);

        if(msg.sender != dev){
            affiliateCommision[dev] = SafeMath.add(affiliateCommision[dev], SafeMath.div(SafeMath.add(fee, commision), 1000000));
        }

        msg.sender.transfer(SafeMath.div(amountOfTRXToReceive, 1000000));
    }

    function getTokenBalance() public view returns(uint256) {
        return tokenBalance[msg.sender];
    }

    function getTokenBalanceFrom(address _address) public view returns(uint256) {
        return tokenBalance[_address];
    }

    function getTokenPrice() public view returns(uint256) {
        uint256 secondsPassed = SafeMath.sub(now, tokenPriceTimestamp);
        return SafeMath.add(1000000, SafeMath.div(SafeMath.mul(SafeMath.div(SafeMath.mul(5, 1000000), 1000), secondsPassed), 86400));
    }
    /* EXCHANGE END */
    
    /* INVESTMENT PROGRAM START */
    function invest(uint256 HEXtoInvest, address referral) public {
        require(HEXtoInvest >= 1000000 && tokenBalance[msg.sender] >= HEXtoInvest);
        tokenBalance[msg.sender] = SafeMath.sub(tokenBalance[msg.sender], HEXtoInvest);
        tokenSupply = SafeMath.sub(tokenSupply, HEXtoInvest);
        uint256 amount = SafeMath.div(SafeMath.mul(getTokenPrice(), HEXtoInvest), 1000000);
        uint256 commision = SafeMath.div(SafeMath.mul(amount, 6), 100);
        if(referral != msg.sender && referral != 0x1 && activeInvestment[referral] >= 2000000000){
            affiliateCommision[referral] = SafeMath.add(affiliateCommision[referral], commision);
        }
        lastInvest[msg.sender] = now;
        activeInvestment[msg.sender] = SafeMath.add(activeInvestment[msg.sender], amount);
    }

    function getInvested() public view returns(uint256){
        return activeInvestment[msg.sender];
    }
    
    function withdraw() public {
        uint256 profit = getProfit(msg.sender);
        require(profit > 0);
        lastInvest[msg.sender] = now;
        totalInvestmentProfitEarned[msg.sender] = SafeMath.add(totalInvestmentProfitEarned[msg.sender], profit);
        uint256 amountOfTokensToReceive = SafeMath.div(SafeMath.mul(profit, 1000000), getTokenPrice());
        tokenBalance[msg.sender] = SafeMath.add(tokenBalance[msg.sender], amountOfTokensToReceive);
        tokenSupply = SafeMath.add(tokenSupply, amountOfTokensToReceive);
    }

    function getInvestmentEarned() public view returns(uint256){
        return totalInvestmentProfitEarned[msg.sender];
    }
    
    function getProfitFromSender() public view returns(uint256){
        return getProfit(msg.sender);
    }

    function getProfit(address customer) public view returns(uint256){
        uint256 secondsPassed = SafeMath.sub(now, lastInvest[customer]);
        uint256 profit = SafeMath.div(SafeMath.mul(SafeMath.div(SafeMath.mul(SafeMath.add(35, dailyVariationRate), activeInvestment[customer]), 1000), secondsPassed), 86400);
        return profit;
    }
    /* INVESTMENT PROGRAM END */

    /* STAKING PROGRAM START */
    function stake(uint256 HEXtoStake) public {
        require(HEXtoStake >= 1000000 && tokenBalance[msg.sender] >= HEXtoStake);
        tokenBalance[msg.sender] = SafeMath.sub(tokenBalance[msg.sender], HEXtoStake);
        tokenSupply = SafeMath.sub(tokenSupply, HEXtoStake);
        lastStake[msg.sender] = now;
        activeStake[msg.sender] = SafeMath.add(activeStake[msg.sender], HEXtoStake);
    }

    function unstake() public {
        require(activeStake[msg.sender] > 0);
        if(getStakeProfit(msg.sender) > 0){
            uint256 profit = getStakeProfit(msg.sender);
            require(profit > 0);
            lastStake[msg.sender] = now;
            totalStakingProfitEarned[msg.sender] = SafeMath.add(totalStakingProfitEarned[msg.sender], profit);
            tokenBalance[msg.sender] = SafeMath.add(tokenBalance[msg.sender], profit);
            tokenSupply = SafeMath.add(tokenSupply, profit);
        }
        uint256 releaseAmount = activeStake[msg.sender];
        releaseAmount = SafeMath.sub(releaseAmount, SafeMath.div(SafeMath.mul(10, releaseAmount), 100));
        activeStake[msg.sender] = 0;
        tokenSupply = SafeMath.add(tokenSupply, releaseAmount);
        tokenBalance[msg.sender] = SafeMath.add(tokenBalance[msg.sender], releaseAmount);
    }

    function withdrawStakeProfit() public {
        uint256 profit = getStakeProfit(msg.sender);
        require(profit > 0);
        lastStake[msg.sender] = now;
        totalStakingProfitEarned[msg.sender] = SafeMath.add(totalStakingProfitEarned[msg.sender], profit);
        tokenBalance[msg.sender] = SafeMath.add(tokenBalance[msg.sender], profit);
        tokenSupply = SafeMath.add(tokenSupply, profit);
    }

    function getStake() public view returns(uint256){
        return activeStake[msg.sender];
    }

    function getStakeEarned() public view returns(uint256){
        return totalStakingProfitEarned[msg.sender];
    }

    function getStakeProfitFromSender() public view returns(uint256){
        return getStakeProfit(msg.sender);
    }

    function getStakeProfit(address customer) public view returns(uint256){
        uint256 secondsPassed = SafeMath.sub(now, lastStake[customer]);
        uint256 profit = SafeMath.div(SafeMath.mul(SafeMath.div(SafeMath.mul(10, activeStake[customer]), 1000), secondsPassed), 86400);
        return profit;
    }
    /* STAKING PROGRAM END */

    /* AFFILIATE PROGRAM START */
    function getAffiliateCommision() public view returns(uint256){
        return affiliateCommision[msg.sender];
    }
    
    function getAffiliateCommisionEarned() public view returns(uint256){
        return totalAffiliateCommisionEarned[msg.sender];
    }
    
    function withdrawAffiliate() public {
        require(affiliateCommision[msg.sender] > 0);
        uint256 commision = affiliateCommision[msg.sender];
        affiliateCommision[msg.sender] = 0;
        totalAffiliateCommisionEarned[msg.sender] = SafeMath.add(totalAffiliateCommisionEarned[msg.sender], commision);
        msg.sender.transfer(commision);
    }
    /* AFFILIATE PROGRAM END */
    
    function getContractBalance() public view returns(uint256){
        return address(this).balance;
    }

    address public dev = 0x0;

    /*
    * Only dev can call this function.
    * It sets the daily variation rate.
    * The daily variaiton rate is an addition to the base rate (3% a day) which cannot be changed.
    * CAN ONLY BE SET to +0%-3%+ (never less or more)
    */
    function setDailyVariationRate(uint256 _rate) public {
        require(
            dev == msg.sender &&
            30 >= _rate &&
            _rate >= 0
        );
        dailyVariationRate = _rate;
    }

    function setDev() public {
        require(dev == 0x0);
        dev = msg.sender;
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