pragma solidity ^0.4.25;

contract P3T2 {
    function deposit() public payable;
}

contract P3T2ROI {

    modifier onlyDev {
        require(msg.sender == dev);
        _;
    }

    // investment tracking for each address
    mapping (address => uint256) public investedTRX;
    mapping (address => uint256) public lastInvest;

    // for referrals and investor positions
    mapping (address => uint256) public affiliateCommision;
    uint256 REF_BONUS = 5; // 5% of the trx invested
    // goes into the ref address' affiliate commision
    uint256 BOT_TAX = 1; // 1% of all trx invested
    // daily interest rate
    uint256 DAILY_RATE = 2400000; // 3.6% per day

    uint256 BASE_PRICE = 1000000000;
    uint256 INHERITANCE_TAX = 75;
    uint256 BOT_TRANSFER_TAX = 125;
    // this means that when purchased the sale will be distributed:
    // principal + 50% to the old position owner
    // 25% to the P3T and MEDA
    // and 25% back to the contract for all the other investors
    // ^ this will encourage a healthy ecosystem
    struct InvestorPosition {
        address investor;
        uint256 startingLevel;
        uint256 startingTime;
        uint256 halfLife;
        uint256 percentageCut;
    }

    InvestorPosition[] investorPositions;
    address public dev;
    P3T2 bot;
    uint256 public totalTrxFundReceived; // total TRX sent to the bot
    uint256 public totalTrxFundCollected; // total TRX collected for the bot

    // start up the contract!
    constructor(address powh, address investor1, address investor2, address investor3) public {

        // set the dev address
        dev = msg.sender;

        // set the bot address
        bot = P3T2(powh);

        // level 1 investor
        investorPositions.push(InvestorPosition({
            investor: investor1,
            startingLevel: 6, // 1000 trx * 2^6 = 64000 trx
            startingTime: now,
            halfLife: 30 days, // 60 days until the level decreases
            percentageCut: 5 // with 5% cut of all investments
            }));

        // level 2 investor
        investorPositions.push(InvestorPosition({
            investor: investor2,
            startingLevel: 5, // 1000 trx * 2^5 = 32000 trx
            startingTime: now,
            halfLife: 30 days, // 60 days until the level decreases
            percentageCut: 3 // with 3% cut of all investments
            }));

        // level 3 investor
        investorPositions.push(InvestorPosition({
            investor: investor3,
            startingLevel: 4, // 1000 trx * 2^4 = 16000 trx
            startingTime: now,
            halfLife: 30 days, // 60 days until the level decreases
            percentageCut: 1 // with 1% cut of all investments
            }));
    }


    /**
     * Fallback function allows the dailyroi contract to receive TRX from the bot
     * Used by payout function so it has to be cheap.
     */
    function() payable public {
    }

    function investTRX(address referral) public payable {

        require(msg.value >= 1000000);

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

        // hand out the bot tax
        uint256 botTax = SafeMath.div(SafeMath.mul(amount, BOT_TAX), 100); // 1%
        totalTrxFundCollected = SafeMath.add(totalTrxFundCollected, botTax);

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

    function inheritInvestorPosition(uint256 index) public payable {

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

        // now do the transfers
        uint256 inheritanceTax = SafeMath.div(SafeMath.mul(currentPrice, INHERITANCE_TAX), 100); // 50% to investor
        position.investor.transfer(inheritanceTax);
        position.investor = msg.sender; // set the new investor address

        // now the bot transfer tax
        uint256 botTransferTax = SafeMath.div(SafeMath.mul(currentPrice, BOT_TRANSFER_TAX), 1000); // 25% to bot
        totalTrxFundCollected = SafeMath.add(totalTrxFundCollected, botTransferTax);

        // and finally the excess
        msg.sender.transfer(purchaseExcess);

        // after this point there will be 25% of currentPrice left in the contract
        // this will be automatically go towards paying for profits and withdrawals

    }

    function payFund() onlyDev public {
        uint256 trxToPay = SafeMath.sub(totalTrxFundCollected, totalTrxFundReceived);
        require(trxToPay >= 1000000);
        totalTrxFundReceived = SafeMath.add(totalTrxFundReceived, trxToPay);
        bot.deposit.value(trxToPay)();
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
        return SafeMath.div(SafeMath.mul(secondsPassed, investedTRX[customer]), DAILY_RATE); // = days * amount * 0.036 (+3.6% per day)
    }

    function getAffiliateCommision() public view returns(uint256){
        return affiliateCommision[msg.sender];
    }

    function getInvested() public view returns(uint256){
        return investedTRX[msg.sender];
    }

    function getBalance() public view returns(uint256){
        return address(this).balance;
    }

    function getPendingFund() public view returns(uint256) {
        return SafeMath.sub(totalTrxFundCollected, totalTrxFundReceived);
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
