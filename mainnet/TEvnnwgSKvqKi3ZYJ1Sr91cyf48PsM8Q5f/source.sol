pragma solidity ^0.4.23;

/**
*
*
*  Telegram: https://t.me/joinchat/HKD4Akt_o6PIyex0D8urcw
*  Discord: https://discord.gg/eyp7sxx
*  Twitter: https://twitter.com/tronheist
*  Reddit: https://www.reddit.com/r/tronheist
*  Facebook: https://www.facebook.com/TronHeist-265469804376432
*  Email: support (at) tronheist.app
*
* PLAY NOW: https://tronheist.app/
*  
* --- TRON HEIST! ------------------------------------------------
*
* Hold the final key to complete the bank heist and win the entire vault funds!
* 
* = Passive income while the vault time lock runs down - as others buy into the 
* game you earn $TRX! 
* 
* = Buy enough keys for a chance to open the safety bank deposit boxes for a 
* instant $TRX win! 
* 
* = Game designed with 4 dimensions of income for you, the players!
*   (See https://tronheist.app/ for details)
* 
* = Can you hold the last key to win the game!
* = Can you win the safety deposit box!
*
* = Play NOW: https://tronheist.app/
*
* Keys priced as low as 50 $TRX!
*
* 
* The more keys you own in each round, the more distributed TRX you'll earn!
* *
*
* --- COPYRIGHT ----------------------------------------------------------------
* 
*   This source code is provided for verification and audit purposes only and 
*   no license of re-use is granted.
*   
*   (C) Copyright 2019 TronHeist.app - A FutureConcepts Production
*   
*   
*   Sub-license, white-label, solidity, Eth Or Tron development enquiries please 
*   contact support (at) tronheist.app
*   
*   
* PLAY NOW: https://tronheist.app/
* 
*/



library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
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

library Percent {

  struct percent {
    uint num;
    uint den;
  }
  function mul(percent storage p, uint a) internal view returns (uint) {
    if (a == 0) {
      return 0;
    }
    return a*p.num/p.den;
  }

  function div(percent storage p, uint a) internal view returns (uint) {
    return a/p.num*p.den;
  }

  function sub(percent storage p, uint a) internal view returns (uint) {
    uint b = mul(p, a);
    if (b >= a) return 0;
    return a - b;
  }

  function add(percent storage p, uint a) internal view returns (uint) {
    return a + mul(p, a);
  }
}



contract TronHeist {
    
    using SafeMath for uint256;
    using Percent for Percent.percent;



    // Events    

    event KeysIssued(uint indexed rnd, address indexed to, uint keys, uint timestamp);
    event JackpotWon(uint indexed rnd, address by, uint amount, uint timestamp);
    event AirdropWon(uint indexed rnd, address by, uint amount, uint timestamp);

    event TrxDistributed(uint indexed rnd, uint amount, uint timestamp);
    event ReturnsWithdrawn(uint indexed rnd, address indexed by, uint amount, uint timestamp);
    
    
    event MegaFundWon(uint indexed rnd, address by, uint amount, uint timestamp);
    event MegaFundEnd(uint indexed rnd, uint amount, uint timestamp);
    event RoundStarted(uint indexed ID, uint hardDeadline, uint timestamp);

    address owner;
    address devAddress;

    

    // settings
    uint256 public constant HARD_DEADLINE_DURATION = 2592000; //30 * 86400 = 30 days hard deadline is this much after the round start
    
    uint256 public constant STARTING_KEY_PRICE = 50000000; // 50TRX //100000000; // 100 trx

    
    uint256 public constant TIME_PER_KEY = 300; //5 * 60; // how much time is added to the soft deadline per key purchased (5mins)

    uint256 public constant PRICE_INCREASE_PERIOD = 3600; // 1 * 3600; // how often the price doubles after the hard deadline (1 hour)

    // 1 SUN = 0.000001 TRX 
    // 1 WEI = 0.000000000000001 ETH 

    // give the keys 18 decimal places...
    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;
    
    Percent.percent private m_currentRoundJackpotPercent = Percent.percent(15, 100);
    Percent.percent private m_investorsPercent = Percent.percent(65, 100); // 65/100*100% = 65%
    Percent.percent private m_nextRoundSeedPercent = Percent.percent(2, 100); 
    Percent.percent private m_airdropPercent = Percent.percent(3, 100); 
    Percent.percent private m_megaFundPercent = Percent.percent(5, 100); 

    Percent.percent private m_devMarketingPercent = Percent.percent(10, 100); // need to update UI
    

    // referrals come off first
    Percent.percent private m_refPercent = Percent.percent(3, 100);
    Percent.percent private m_refPercent2 = Percent.percent(5, 100);

    mapping (address => bool) bonusReferralAccounts;
    
    struct SafeBreaker {
        //uint lastCumulativeReturnsPoints;
        uint lastCumulativeReturnsPoints;
        uint keys;
    }
    
    struct GameRound {
        uint totalInvested;        
        uint jackpot;
        uint airdropPot;
        uint totalKeys;
        uint cumulativeReturnsPoints; // this is to help calculate returns when the total number of keys changes
        uint hardDeadline;
        uint softDeadline;
        uint price;
        uint lastPriceIncreaseTime;
        uint distributedReturns;
        address lastInvestor;
        bool finalized;
        mapping (address => SafeBreaker) safeBreakers;
        uint startTime;
    }
    
    struct Vault {
        uint totalReturns; // Total balance = returns + referral returns + jackpots/airdrops 
        uint refReturns; // how much of the total is from referrals
    }

    mapping (address => Vault) vaults;

    uint public latestRoundID;// the first round has an ID of 0
    GameRound[] rounds;
    
    
    uint256 public minInvestment = 50000000; // 50TRX 100000000; // 100trx; 
    uint256 public maxInvestment = 100000000000; // 100000 trx 
    uint256 public roundDuration = (24 hours);
    uint public soft_deadline_duration = 1 days; // max soft deadline
    bool public gamePaused = false;
    bool public limitedReferralsMode = true;
    uint public MAX_JACKPOT_ROLLOVERS = 10;
    uint public airdropChance = 100;
    uint public megaJackpotChance = 600;


    mapping(address => bool) private m_referrals; // we only pay out on the first set of referrals
    
    
    // Game vars
    uint public jackpotSeed;// Jackpot from previous rounds
    uint public megaJackpot;
    uint public megaJackpot_startRnd = 0;

    
    uint public unclaimedReturns;
    uint public constant MULTIPLIER = RAY;
    
    // Main stats:
    uint public totalJackpotsWon;
    uint public megaJackpotsWon;
    uint public totalKeysSold;
    uint public totalEarningsGenerated;

    
    // modifiers
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    modifier notOnPause() {
        require(gamePaused == false, "Game Paused");
        _;
    }
    


    
    constructor() public {

        owner = msg.sender;
        devAddress = msg.sender;

        
        rounds.length++;
        
        latestRoundID = 0;

        rounds[0].lastInvestor = msg.sender;
        rounds[0].price = STARTING_KEY_PRICE;
        rounds[0].hardDeadline = now + HARD_DEADLINE_DURATION;
        rounds[0].softDeadline = now + soft_deadline_duration;
        jackpotSeed = 0; 
        rounds[0].jackpot = jackpotSeed;

        rounds[0].startTime = now;
        
    }

    function () public payable {
        buyKeys(address(0x0));
    }

    function investorInfo(address investor, uint roundID) external view
    returns(uint keys, uint totalReturns, uint referralReturns) 
    {
        GameRound storage rnd = rounds[roundID];
        keys = rnd.safeBreakers[investor].keys;
        (totalReturns, referralReturns) = estimateReturns(investor, roundID);
    }

    function estimateReturns(address investor, uint roundID) public view 
    returns (uint totalReturns, uint refReturns) 
    {
        GameRound storage rnd = rounds[roundID];
        uint outstanding;
        if(rounds.length > 1) {
            if(hasReturns(investor, roundID - 1)) {
                GameRound storage prevRnd = rounds[roundID - 1];
                outstanding = _outstandingReturns(investor, prevRnd);
            }
        }

        outstanding += _outstandingReturns(investor, rnd);
        
        totalReturns = vaults[investor].totalReturns + outstanding;
        refReturns = vaults[investor].refReturns;
    }
    
    function roundInfo(uint roundID) external view 
    returns(
        address leader, 
        uint price,
        uint jackpot, 
        uint airdrop, 
        uint keys, 
        uint totalInvested,
        uint distributedReturns,
        uint _hardDeadline,
        uint _softDeadline,
        bool finalized,
        uint _megaJackpot,
        uint startTime
        )
    {
        GameRound storage rnd = rounds[roundID];
        leader = rnd.lastInvestor;
        price = rnd.price;
        jackpot = rnd.jackpot;
        airdrop = rnd.airdropPot;
        keys = rnd.totalKeys;
        totalInvested = rnd.totalInvested;
        distributedReturns = rnd.distributedReturns; // m_currentRoundJackpotPercent.mul(rnd.totalInvested);
        //wmul(rnd.totalInvested, RETURNS_FRACTION);
        _hardDeadline = rnd.hardDeadline;
        _softDeadline = rnd.softDeadline;
        finalized = rnd.finalized;
        _megaJackpot = megaJackpot;
        startTime = rnd.startTime;
    }
    
    function totalsInfo() external view 
    returns(
        uint totalReturns,
        uint totalKeys,
        uint totalJackpots,
        uint totalMegaJackpots
    ) {
        GameRound storage rnd = rounds[latestRoundID];
        if(rnd.softDeadline > now) {
            totalKeys = totalKeysSold + rnd.totalKeys;
            totalReturns = totalEarningsGenerated + m_currentRoundJackpotPercent.mul(rnd.totalInvested); 
            // wmul(rnd.totalInvested, RETURNS_FRACTION);
        } else {
            totalKeys = totalKeysSold;
            totalReturns = totalEarningsGenerated;
        }
        totalJackpots = totalJackpotsWon;
        totalMegaJackpots = megaJackpotsWon;
    }

    
    function reinvestReturns(uint value) public returns (uint airdropPrize, uint megaJackpotPrize) {        
        (airdropPrize, megaJackpotPrize) = reinvestReturns(value, address(0x0));
    }

    function reinvestReturns(uint value, address ref) public returns (uint airdropPrize, uint megaJackpotPrize) {        
        GameRound storage rnd = rounds[latestRoundID];
        _updateReturns(msg.sender, rnd);        
        require(vaults[msg.sender].totalReturns >= value, "Can't spend what you don't have");        
        vaults[msg.sender].totalReturns = vaults[msg.sender].totalReturns.sub(value);
        vaults[msg.sender].refReturns = min(vaults[msg.sender].refReturns, vaults[msg.sender].totalReturns);
        unclaimedReturns = unclaimedReturns.sub(value);
        (airdropPrize, megaJackpotPrize) = _purchase(rnd, value, ref);
    }
    function withdrawReturns() public {
        GameRound storage rnd = rounds[latestRoundID];

        if(rounds.length > 1) {// check if they also have returns from before
            if(hasReturns(msg.sender, latestRoundID - 1)) {
                GameRound storage prevRnd = rounds[latestRoundID - 1];
                _updateReturns(msg.sender, prevRnd);
            }
        }
        _updateReturns(msg.sender, rnd);
        uint amount = vaults[msg.sender].totalReturns;
        require(amount > 0, "Nothing to withdraw!");
        unclaimedReturns = unclaimedReturns.sub(amount);
        vaults[msg.sender].totalReturns = 0;
        vaults[msg.sender].refReturns = 0;
        
        rnd.safeBreakers[msg.sender].lastCumulativeReturnsPoints = rnd.cumulativeReturnsPoints;
        msg.sender.transfer(amount);

        emit ReturnsWithdrawn(latestRoundID, msg.sender, amount, now);
    }
    function hasReturns(address investor, uint roundID) public view returns (bool) {
        GameRound storage rnd = rounds[roundID];
        return rnd.cumulativeReturnsPoints > rnd.safeBreakers[investor].lastCumulativeReturnsPoints;
    }
    function updateMyReturns(uint roundID) public {
        GameRound storage rnd = rounds[roundID];
        _updateReturns(msg.sender, rnd);
    }
    
    function finalizeLastRound() public {
        GameRound storage rnd = rounds[latestRoundID];
        _finalizeRound(rnd);
    }


    function finalizeAndRestart(address _referer) public payable returns (uint airdropPrize, uint megaJackpotPrize) {
        finalizeLastRound();
        (airdropPrize, megaJackpotPrize) = startNewRound(_referer);
    }
    
    
    function startNewRound(address _referer) public payable returns (uint airdropPrize, uint megaJackpotPrize) {
        
        require(rounds[latestRoundID].finalized, "Previous round not finalized");
        require(rounds[latestRoundID].softDeadline < now, "Previous round still running");
        
        uint _rID = rounds.length++; // first round is 0
        GameRound storage rnd = rounds[_rID];
        latestRoundID = _rID;

        rnd.lastInvestor = msg.sender;
        rnd.price = STARTING_KEY_PRICE;
        rnd.hardDeadline = now + HARD_DEADLINE_DURATION;
        rnd.softDeadline = now + soft_deadline_duration;
        rnd.startTime = now;


        if(latestRoundID - megaJackpot_startRnd > MAX_JACKPOT_ROLLOVERS) {
            // can't rollover more than MAX_JACKPOT_ROLLOVERS rounds!
            jackpotSeed = jackpotSeed.add(megaJackpot);
            emit MegaFundEnd(_rID, megaJackpot, now);
            megaJackpot = 0;
            megaJackpot_startRnd = latestRoundID;

        }

        rnd.jackpot = jackpotSeed;
        jackpotSeed = 0; 

        (airdropPrize, megaJackpotPrize) = _purchase(rnd, msg.value, _referer);
        emit RoundStarted(_rID, rnd.hardDeadline, now);
    }
    
    
    function buyKeys(address _referer) public payable notOnPause returns (uint airdropPrize, uint megaJackpotPrize) {
        require(msg.value >= minInvestment);
        if(rounds.length > 0) {
            GameRound storage rnd = rounds[latestRoundID];   
               
            (airdropPrize, megaJackpotPrize) = _purchase(rnd, msg.value, _referer);            
        } else {
            revert("Not yet started");
        }
        
    }
    
    
    function _purchase(GameRound storage rnd, uint value, address referer) internal returns (uint airdropPrize, uint megaJackpotPrize) {
        require(now >= rnd.startTime, "Round now started!");
        require(rnd.softDeadline >= now, "After deadline!");
        require(value >= rnd.price, "Not enough TRX!"); // TOTEST
        rnd.totalInvested = rnd.totalInvested.add(value);

        // Set the last investor (to win the jackpot after the deadline)
        //if(value >= rnd.price)
        rnd.lastInvestor = msg.sender;
        
        
        airdropPrize = _airDrop(rnd, value);
        megaJackpotPrize = _megaJackpot();
        

        _splitRevenue(rnd, value, referer);
        
        _updateReturns(msg.sender, rnd);
        
        uint newKeys = _issueKeys(rnd, msg.sender, value);


        uint timeIncreases = newKeys/WAD;// since 1 key is represented by 1 * 10^18, divide by 10^18
        // adjust soft deadline to new soft deadline
        uint newDeadline = rnd.softDeadline.add( timeIncreases.mul(TIME_PER_KEY));
        
        rnd.softDeadline = min(newDeadline, now + soft_deadline_duration);
        // If after hard deadline, double the price every price increase periods
        if(now > rnd.hardDeadline) {
            if(now > rnd.lastPriceIncreaseTime + PRICE_INCREASE_PERIOD) {
                rnd.price = rnd.price * 2;
                rnd.lastPriceIncreaseTime = now;
            }
        }
    }
    function _issueKeys(GameRound storage rnd, address _safeBreaker, uint value) internal returns(uint) {    
        if(rnd.safeBreakers[_safeBreaker].lastCumulativeReturnsPoints == 0) {
            rnd.safeBreakers[_safeBreaker].lastCumulativeReturnsPoints = rnd.cumulativeReturnsPoints;
        }    
        
        uint newKeys = wdiv(value, rnd.price);
        
        //bonuses:
        if(value >= 500000000000) { // 500,000 TRX
            newKeys = newKeys.mul(2);//get double keys if you paid more than 100 trx
        } else if(value >= 50000000000) { // 50,000 TRX
            newKeys = newKeys.add(newKeys/2);//50% bonus
        } else if(value >= 5000000000) { // 5,000 TRX
            newKeys = newKeys.add(newKeys/3);//33% bonus
        } else if(value >= 500000000) { // 500 TRX
            newKeys = newKeys.add(newKeys/10);//10% bonus
        }

        rnd.safeBreakers[_safeBreaker].keys = rnd.safeBreakers[_safeBreaker].keys.add(newKeys);
        rnd.totalKeys = rnd.totalKeys.add(newKeys);
        emit KeysIssued(latestRoundID, _safeBreaker, newKeys, now);
        return newKeys;
    }    
    function _updateReturns(address _safeBreaker, GameRound storage rnd) internal {
        if(rnd.safeBreakers[_safeBreaker].keys == 0) {
            return;
        }
        
        uint outstanding = _outstandingReturns(_safeBreaker, rnd);

        // if there are any returns, transfer them to the investor's vaults
        if (outstanding > 0) {
            vaults[_safeBreaker].totalReturns = vaults[_safeBreaker].totalReturns.add(outstanding);
        }

        rnd.safeBreakers[_safeBreaker].lastCumulativeReturnsPoints = rnd.cumulativeReturnsPoints;
    }
    function _outstandingReturns(address _safeBreaker, GameRound storage rnd) internal view returns(uint) {
        if(rnd.safeBreakers[_safeBreaker].keys == 0) {
            return 0;
        }
        // check if there've been new returns
        uint newReturns = rnd.cumulativeReturnsPoints.sub(
            rnd.safeBreakers[_safeBreaker].lastCumulativeReturnsPoints
            );

        uint outstanding = 0;
        if(newReturns != 0) { 
            // outstanding returns = (total new returns points * ivestor keys) / MULTIPLIER
            // The MULTIPLIER is used also at the point of returns disbursment
            outstanding = newReturns.mul(rnd.safeBreakers[_safeBreaker].keys) / MULTIPLIER;
            // 65000000000 * (10**18 / 10**27) = 65 = correct
        }

        return outstanding;
    }
    function _splitRevenue(GameRound storage rnd, uint value, address ref) internal {
        uint roundReturns; // how much to pay in dividends to round players
        

        if(ref != address(0x0)) {

            // only pay referrals for the first investment of each player
            if(
                (!m_referrals[msg.sender] && limitedReferralsMode == true)
                ||
                limitedReferralsMode == false
                ) {
            

                uint _referralEarning;

                if(bonusReferralAccounts[ref] == true)
                    _referralEarning = m_refPercent2.mul(value);
                else
                    _referralEarning = m_refPercent.mul(value);

                unclaimedReturns = unclaimedReturns.add(_referralEarning);
                vaults[ref].totalReturns = vaults[ref].totalReturns.add(_referralEarning);
                vaults[ref].refReturns = vaults[ref].refReturns.add(_referralEarning);
                
                value = value.sub(_referralEarning);
                
                m_referrals[msg.sender] = true;
                
            }
        } else {
        }
        
        roundReturns = m_investorsPercent.mul(value); // 65%
        
        uint airdrop_value = m_airdropPercent.mul(value);
        megaJackpot = megaJackpot.add(m_megaFundPercent.mul(value));
        
        uint jackpot_value = m_currentRoundJackpotPercent.mul(value); 

        
        uint dev_value = m_devMarketingPercent.mul(value);

        
        
        // if this is the first purchase, roundReturns goes to jackpot (no one can claim these returns otherwise)
        if(rnd.totalKeys == 0) {
            rnd.jackpot = rnd.jackpot.add(roundReturns);
        } else {
            _disburseReturns(rnd, roundReturns);
        }
        
        rnd.airdropPot = rnd.airdropPot.add(airdrop_value);
        rnd.jackpot = rnd.jackpot.add(jackpot_value);
        
        devAddress.transfer(dev_value);
        
    }
    function _disburseReturns(GameRound storage rnd, uint value) internal {
        emit TrxDistributed(latestRoundID, value, now);
        rnd.distributedReturns = rnd.distributedReturns.add(value);

        unclaimedReturns = unclaimedReturns.add(value);// keep track of unclaimed returns
        // The returns points represent returns*MULTIPLIER/totalkeys (at the point of purchase)
        // This allows us to keep outstanding balances of keyholders when the total supply changes in real time
        if(rnd.totalKeys == 0) {
            //rnd.cumulativeReturnsPoints = mul(value, MULTIPLIER) / wdiv(value, rnd.price);
            rnd.cumulativeReturnsPoints = value.mul(MULTIPLIER) / wdiv(value, rnd.price);
        } else {
            rnd.cumulativeReturnsPoints = rnd.cumulativeReturnsPoints.add(
                value.mul(MULTIPLIER) / rnd.totalKeys
            );
        } // (65 * 10**27) / 10**18 = 65000000000



    }

    function chanceTest() public view returns (uint a, uint b)  {
        uint chance = uint(keccak256(abi.encodePacked(blockhash(block.number - 1), now)));
        a= chance; b = chance % 600;
    }

    function _airDrop(GameRound storage rnd, uint value) internal returns (uint) {

        if(value > 1000000000 trx) { // 1000 TRX - TOTEST

            //    Creates a random number from the last block hash and current timestamp.
            //    One could add more seemingly random data like the msg.sender, etc, but that doesn't 
            //    make it harder for a miner to manipulate the result in their favor (if they intended to).
             
            uint chance = uint(keccak256(abi.encodePacked(blockhash(block.number - 1), now)));
            if(chance % airdropChance == 0) {// once in 100 chance
                uint prize = rnd.airdropPot;// win airdrop pot
                rnd.airdropPot = 0;
                vaults[msg.sender].totalReturns = vaults[msg.sender].totalReturns.add(prize);
                unclaimedReturns = unclaimedReturns.add(prize);
                totalJackpotsWon += prize;
                emit AirdropWon(latestRoundID, msg.sender, prize, now);
            } else {
                return 0;
            }
        } else {
            return 0;
        }
    }
    
    function _megaJackpot() internal returns (uint) {

        
        //    Creates a random number from the last block hash and current timestamp.
        //    One could add more seemingly random data like the msg.sender, etc, but that doesn't 
        //    make it harder for a miner to manipulate the result in their favor (if they intended to).
        
        uint chance = uint(keccak256(abi.encodePacked(blockhash(block.number - 1), now)));
        if(chance % megaJackpotChance == 0) {// once in 600 chance
            uint prize = megaJackpot;
            megaJackpot = 0;
            vaults[msg.sender].totalReturns = vaults[msg.sender].totalReturns.add(prize);
            unclaimedReturns = unclaimedReturns.add(prize);
            megaJackpotsWon += prize;
            emit MegaFundWon(latestRoundID, msg.sender, prize, now);
            return prize;
        } else {
            return 0;
        }

    }
    
    function _finalizeRound(GameRound storage rnd) internal {
        require(!rnd.finalized, "Already finalized!");
        require(rnd.softDeadline < now, "Round still running!");


        // Transfer jackpot to winner's vault
        vaults[rnd.lastInvestor].totalReturns = vaults[rnd.lastInvestor].totalReturns.add(rnd.jackpot);
        unclaimedReturns = unclaimedReturns.add(rnd.jackpot);
        
        emit JackpotWon(latestRoundID, rnd.lastInvestor, rnd.jackpot, now);
        totalJackpotsWon += rnd.jackpot;
        // transfer the leftover to the next round's jackpot
        jackpotSeed = jackpotSeed.add( m_nextRoundSeedPercent.mul(rnd.totalInvested));
            
        //Empty the AD pot if it has a balance.
        jackpotSeed = jackpotSeed.add(rnd.airdropPot);
        

        totalKeysSold += rnd.totalKeys;
        totalEarningsGenerated += m_currentRoundJackpotPercent.mul(rnd.totalInvested);

        rnd.finalized = true;
    }
    
    // Owner only functions    
    function p_setOwner(address _owner) public onlyOwner {
        owner = _owner;
    }
    function p_setDevAddress(address _devAddress) public onlyOwner {
        devAddress = _devAddress;
    }
    function p_setCurrentRoundJackpotPercent(uint num, uint dem) public onlyOwner {
        m_currentRoundJackpotPercent = Percent.percent(num, dem);
    }
    function p_setInvestorsPercent(uint num, uint dem) public onlyOwner {
        m_investorsPercent = Percent.percent(num, dem);
    }
    function p_setDevMarketingPercent(uint num, uint dem) public onlyOwner {
        m_devMarketingPercent = Percent.percent(num, dem);
    }
    function p_setRefPercent(uint num, uint dem) public onlyOwner {
        m_refPercent = Percent.percent(num, dem);
    }
    function p_setRefPercent2(uint num, uint dem) public onlyOwner {
        m_refPercent2 = Percent.percent(num, dem);
    }
    function p_AddBonusReferralAccount(address _bonusAddr) public onlyOwner {
        bonusReferralAccounts[_bonusAddr] = true;
    }
    function p_DelBonusReferralAccounts(address _bonusAddr) public onlyOwner {
        bonusReferralAccounts[_bonusAddr] = false;
    }
    function p_setNextRoundSeedPercent(uint num, uint dem) public onlyOwner {
        m_nextRoundSeedPercent = Percent.percent(num, dem);
    }
    function p_setAirdropPercent(uint num, uint dem) public onlyOwner {
        m_airdropPercent = Percent.percent(num, dem);
    }

    function p_setMinInvestment(uint _minInvestment) public onlyOwner {
        minInvestment = _minInvestment;
    }
    function p_setMaxInvestment(uint _maxInvestment) public onlyOwner {
        maxInvestment = _maxInvestment;
    }
    function p_setGamePaused(bool _gamePaused) public onlyOwner {
        gamePaused = _gamePaused;
    }
    function p_setRoundDuration(uint256 _roundDuration) public onlyOwner {
        roundDuration = _roundDuration;
    }
    function p_setRoundStartTime(uint256 _round, uint256 _startTime) public onlyOwner {
        rounds[_round].startTime = _startTime;
        rounds[_round].hardDeadline = _startTime + HARD_DEADLINE_DURATION;
        rounds[_round].softDeadline = _startTime + soft_deadline_duration;
    }

    function p_setLimitedReferralsMode(bool _limitedReferralsMode) public onlyOwner {
        limitedReferralsMode = _limitedReferralsMode;
    }
    function p_setSoft_deadline_duration(uint _soft_deadline_duration) public onlyOwner {
        soft_deadline_duration = _soft_deadline_duration;
    }
    function p_setMaxJackpotRollovers(uint _MAX_JACKPOT_ROLLOVERS) public onlyOwner {
        MAX_JACKPOT_ROLLOVERS = _MAX_JACKPOT_ROLLOVERS;
    }
    function p_setAirdropChance(uint _airdropChance) public onlyOwner {
        airdropChance = _airdropChance;
    }
    function p_setMegaJackpotChance(uint _megaJackpotChance) public onlyOwner {
        megaJackpotChance = _megaJackpotChance;
    }
    // Util functions
    function notZeroAndNotSender(address addr) internal view returns(bool) {
        return notZero(addr) && addr != msg.sender;
    }
    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }
    function max(uint x, uint y) internal pure returns (uint z) {
        return x >= y ? x : y;
    }

    function wdiv(uint x, uint y) internal pure returns (uint z) {
        //z = x.mul(WAD).add(y/2)/y;

        // (100000000 * (10 ** 18) + 100000000 /2) / 100000000
        // = 1 key (At 10 ** 18)
        z = (x.mul(WAD).add(y/2))/y;

        //z = add(mul(x, WAD), y / 2) / y;
    }
    function rdiv(uint x, uint y) internal pure returns (uint z) {
        z = (x.mul(RAY).add(y/2))/y;
        //z = add(mul(x, RAY), y / 2) / y;
    }
    
    uint op;
    function gameOp() public {
        op++;
    }


    function notZero(address addr) internal pure returns(bool) {
        return !(addr == address(0));
    }

}