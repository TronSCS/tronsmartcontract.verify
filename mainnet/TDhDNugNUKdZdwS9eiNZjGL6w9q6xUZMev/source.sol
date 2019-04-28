pragma solidity ^0.4.25;

contract PERCENT25 {

    modifier onlyDev {
        require(msg.sender == dev);
        _;
    }

    uint ACTIVATION_TIME = 1553360400;

    modifier isActivated {
        require(now >= ACTIVATION_TIME);
        _;
    }

    // investment tracking for each address
    mapping (address => uint256) public investedTRX;
    mapping (address => uint256) public lastInvest;

    // total investors
    uint256 totalInvestor = 0;

    // for referrals and investor positions
    mapping (address => uint256) public affiliateCommision;
    uint256 REF_BONUS = 3; // 3% of the trx invested
    // goes into the ref address' affiliate commision
    uint256 DEV_TAX = 3; // 3% of all trx invested
    // daily interest rate
    uint256 DAILY_RATE = 345600; // 25% per day

    // card sale will be distributed in the following manner:
    // principal + 50% to the old position owner
    // 40% back to the contract for all the other investors
    // 10% to the dev
    // ^ this will encourage a healthy ecosystem
    uint256 BASE_PRICE = 10000000;
    uint256 INHERITANCE_TAX = 75;
    uint256 DEV_TRANSFER_TAX = 5;
    struct InvestorPosition {
        address investor;
        uint256 startingLevel;
        uint256 startingTime;
        uint256 halfLife;
        uint256 percentageCut;
    }

    InvestorPosition[] investorPositions;
    address public dev;

    // start up the contract!
    constructor() public {

        // set the dev address
        dev = msg.sender;

        // level 1 investor
        investorPositions.push(InvestorPosition({
            investor: dev,
            startingLevel: 0,
            startingTime: now,
            halfLife: 4 days,
            percentageCut: 5
            }));

        // level 2 investor
        investorPositions.push(InvestorPosition({
            investor: dev,
            startingLevel: 0,
            startingTime: now,
            halfLife: 4 days,
            percentageCut: 3
            }));

        // level 3 investor
        investorPositions.push(InvestorPosition({
            investor: dev,
            startingLevel: 0,
            startingTime: now,
            halfLife: 4 days,
            percentageCut: 1
            }));
    }


    /**
     * Fallback function allows the dailyroi contract to receive donations
     */
    function() payable public {
    }

    function investTRX(address referral) isActivated public payable {

        require(msg.value >= 1000000);

        if (getInvested() == 0) {
          totalInvestor += 1;
        }

        if (getProfit(msg.sender) > 0) {
            uint256 profit = getProfit(msg.sender);
            lastInvest[msg.sender] = now;
            msg.sender.transfer(profit);
        }

        uint256 amount = msg.value;

        // handle all of our investor positions first
        bool flaggedRef = (referral == msg.sender || referral == dev); // ref cannot be the sender or the dev
        for(uint256 i = 0; i < investorPositions.length; i++) {

            InvestorPosition memory position = investorPositions[i];

            // check that our ref isn't an investor too
            if (position.investor == referral) {
                flaggedRef = true;
            }

            // we cannot claim on our own investments
            if (position.investor != msg.sender) {
                uint256 commision = SafeMath.div(SafeMath.mul(amount, position.percentageCut), 100);
                affiliateCommision[position.investor] = SafeMath.add(affiliateCommision[position.investor], commision);
            }

        }

        // now for the referral (if we have one)
        if (!flaggedRef && referral != 0x0) {
            uint256 refBonus = SafeMath.div(SafeMath.mul(amount, REF_BONUS), 100); // 5%
            affiliateCommision[referral] = SafeMath.add(affiliateCommision[referral], refBonus);
        }

        // hand out the dev tax
        uint256 devTax = SafeMath.div(SafeMath.mul(amount, DEV_TAX), 100); // 5%
        affiliateCommision[dev] = SafeMath.add(affiliateCommision[dev], devTax);

        // now put it in your own piggy bank!
        investedTRX[msg.sender] = SafeMath.add(investedTRX[msg.sender], amount);
        lastInvest[msg.sender] = now;

    }

    function withdraw() public{

        uint256 profit = getProfit(msg.sender);

        require(profit > 0);
        lastInvest[msg.sender] = now;
        msg.sender.transfer(profit);

    }

    function withdrawAffiliateCommision() public {

        require(affiliateCommision[msg.sender] > 0);
        uint256 commision = affiliateCommision[msg.sender];
        affiliateCommision[msg.sender] = 0;
        msg.sender.transfer(commision);

    }

    function reinvestProfit() public {

        uint256 profit = getProfit(msg.sender);

        require(profit > 0);
        lastInvest[msg.sender] = now;
        investedTRX[msg.sender] = SafeMath.add(investedTRX[msg.sender], profit);

    }

    function inheritInvestorPosition(uint256 index) isActivated public payable {

        // because of extra 41 head
        address origin = tx.origin;

        require(investorPositions.length > index);
        require(msg.sender == origin);

        InvestorPosition storage position = investorPositions[index];
        uint256 currentLevel = getCurrentLevel(position.startingLevel, position.startingTime, position.halfLife);
        uint256 currentPrice = getCurrentPrice(currentLevel);

        require(msg.value >= currentPrice);
        uint256 purchaseExcess = SafeMath.sub(msg.value, currentPrice);
        position.startingLevel = currentLevel + 1;
        position.startingTime = now;

        // 50% to investor for card
        uint256 inheritanceTax = SafeMath.div(SafeMath.mul(currentPrice, INHERITANCE_TAX), 100);
        position.investor.transfer(inheritanceTax);
        position.investor = msg.sender; // set the new investor address

        // 10% to dev for card
        uint256 devTransferTax = SafeMath.div(SafeMath.mul(currentPrice, DEV_TRANSFER_TAX), 100);
        dev.transfer(devTransferTax);

        // and finally the excess
        msg.sender.transfer(purchaseExcess);

        // after this point there will be 40% of currentPrice left in the contract
        // this will be automatically go towards paying for profits and withdrawals

    }

    function getInvestorPosition(uint256 index) public view returns(address investor, uint256 currentPrice, uint256 halfLife, uint256 percentageCut) {
        InvestorPosition memory position = investorPositions[index];
        return (position.investor, getCurrentPrice(getCurrentLevel(position.startingLevel, position.startingTime, position.halfLife)), position.halfLife, position.percentageCut);
    }

    function getCurrentPrice(uint256 currentLevel) internal view returns(uint256) {
        return BASE_PRICE * 2**currentLevel; // ** is exponent, price doubles every level
    }

    function getCurrentLevel(uint256 startingLevel, uint256 startingTime, uint256 halfLife) internal view returns(uint256) {
        uint256 timePassed = SafeMath.sub(now, startingTime);
        uint256 levelsPassed = SafeMath.div(timePassed, halfLife);
        if (startingLevel < levelsPassed) {
            return 0;
        }
        return SafeMath.sub(startingLevel,levelsPassed);
    }

    function getProfitFromSender() public view returns(uint256){
        return getProfit(msg.sender);
    }

    function getProfit(address customer) public view returns(uint256){
        uint256 secondsPassed = SafeMath.sub(now, lastInvest[customer]);
        return SafeMath.div(SafeMath.mul(secondsPassed, investedTRX[customer]), DAILY_RATE);
    }

    function getAffiliateCommision() public view returns(uint256){
        return affiliateCommision[msg.sender];
    }

    function getInvested() public view returns(uint256){
        return investedTRX[msg.sender];
    }

    function getTotalInvestor() public view returns(uint256){
        return totalInvestor;
    }

    function getBalance() public view returns(uint256){
        return address(this).balance;
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
