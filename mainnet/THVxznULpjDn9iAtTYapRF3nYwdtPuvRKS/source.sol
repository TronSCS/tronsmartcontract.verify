pragma solidity ^0.4.25;

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



contract rando {
    function getRandoUInt(uint _max, address _sender) public returns(uint random_val);
}




contract TronHeist3 {
    
    using SafeMath for uint256;
    using Percent for Percent.percent;



    // Events    

    event KeysIssued(uint indexed rnd, address indexed to, uint keys, uint timestamp,
        uint InstantWinGuess,
        uint InstantWinResult, uint InstantWinAmount,
        uint SafetyDepositGuess,
        uint SafetyDepositResult, uint SafetyDepositAmount);

    event JackpotWon(uint indexed rnd, address by, uint amount, 
            uint lucky_key_percent, 
            uint winners_start_percent,
            uint winners_end_percent,
            uint round_final_keys, 
            uint timestamp);

    //event SafetyDepositResult(uint indexed rnd, address by, uint amount, uint result, uint timestamp); // TODO update UI to new event name
    //event InstantWinResult(uint indexed rnd, address by, uint amount, uint result, uint timestamp);

    event TrxDistributed(uint indexed rnd, uint amount, uint timestamp);
    event ReturnsWithdrawn(uint indexed rnd, address indexed by, uint amount, uint timestamp);
    
    
    

    event InstantWinEnd(uint indexed rnd, uint amount, uint timestamp);
    event RoundStarted(uint indexed ID, uint hardDeadline, uint timestamp);
    event PrizesUpdated(uint SafetyDeposit, uint InstantWin, uint timestamp);

    event DailyPrize(uint indexed day, address indexed to, uint amt, uint timestamp);


    address owner;
    address devAddress;



    

    // settings
    uint256 public HARD_DEADLINE_DURATION = 2592000; //30 * 86400 = 30 days hard deadline is this much after the round start
    uint256 public STARTING_KEY_PRICE = 10000000; // 10TRX 
    uint256 public PRICE_INCREASE_PERIOD = 3600; // 1 * 3600; // how often the price doubles after the hard deadline (1 hour)
    
    uint256 internal time_per_key = 30; //5 * 60; // how much time is added to the soft deadline per key purchased (30 secs now)
    uint256 internal base_time_per_key = 10;
    uint256 internal bonus_potential_key_time = 15;

    

    // 1 SUN = 0.000001 TRX 
    // 1 WEI = 0.000000000000001 ETH 

    // give the keys 18 decimal places...
    uint constant WAD = 10 ** 18;
    uint constant RAY = 10 ** 27;
    


    Percent.percent private m_currentRoundJackpotPercent = Percent.percent(15, 100);

    Percent.percent private m_currentDailyTopPlayersPercent = Percent.percent(15, 100);
        Percent.percent private m_currentDailySplitPercent = Percent.percent(20, 100); // how much of the above it distributed each day
        uint m_currentDailyTopPlayers = 4; // how many top players receive the above

    Percent.percent private m_investorsPercent = Percent.percent(40, 100); // dividend split
    Percent.percent private m_nextRoundSeedPercent = Percent.percent(2, 100); 
    Percent.percent private m_airdropPercent = Percent.percent(10, 100);  // safetydeposit prize
    Percent.percent private m_instantwinPercent = Percent.percent(8, 100); 

    Percent.percent private m_devMarketingPercent = Percent.percent(10, 100); // dev + marketing
    

    

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
        uint safetyDepositPot;
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



    struct NumOfKeys {
        address player;
        uint    keys;
    }

    mapping(uint => address[]) playersInCurrentRound;
    mapping (uint => mapping(address => bool)) safeBreakersInRound;
    mapping (uint => mapping(address => uint)) dayBuys; // (day => player => keys)


    
    mapping (uint => NumOfKeys[]) dayTopKeys; // day => numOfKeys // USED

    

    uint256 public devHoldings = 0;


    uint public currentDay;

    // profit days
    struct DayChart {
        uint256 dailyInvestments; // number of investments
        uint256 dayStartTs;
        uint256 day;
        bool isFinalized;
        uint totalKeys;
    }

    DayChart[] public gameDays;

    function getDayChartSize(uint day) public view returns (uint size) {
        size = dayTopKeys[day].length;
    }
    function getDayChartAtPos(uint day, uint pos) public view returns(address player, uint keys) {

        player = dayTopKeys[day][pos].player;
        keys = dayTopKeys[day][pos].keys;
    }
    function getCurrentDayChartSize() public view returns (uint size, uint day) {

        size = dayTopKeys[currentDay].length;
        day = currentDay;
    }

    uint256 public dayDuration = (24 hours);




    modifier checkDayRollover() {
        
        if(now.sub(gameDays[currentDay].dayStartTs).div(dayDuration) > 0) {
            rolloverDay();
        }
        _;
    }

    modifier validPlayer() {
        require(msg.sender == tx.origin);
        _;
    }

    function rollover() public {
        require(now.sub(gameDays[currentDay].dayStartTs).div(dayDuration) > 0);
        rolloverDay();
    }

    function rolloverDay() internal {
        _finalizeDay(currentDay);    
        currentDay++;
        gameDays.push(DayChart(0,now,currentDay,false,0));    
    }

    function p_rolloverDay() public onlyOwner {
        _finalizeDay(currentDay);    
        currentDay++;
        gameDays.push(DayChart(0,now,currentDay,false,0));
    }




    function getRoundPlayersInRound(uint round) public view returns(address[]) {
        return playersInCurrentRound[round];
    }

    mapping (address => Vault) vaults;
    mapping (address => uint)  lastDailyFreeKeyTime;

    uint public latestRoundID;// the first round has an ID of 0
    GameRound[] rounds;

    uint public dailyTotalPot;
    
    
    uint256 public minInvestment = 10000000; // 10TRX
    uint256 public maxInvestment = 100000000000; // 100000 trx 
    uint256 public roundDuration = (24 hours); //(24 hours); // debug
    uint public soft_deadline_duration = (24 hours); //24 hours; // // max soft deadline // debug
    uint m_DarkMinutes = 4 minutes; // DEBUG (SHOULD BE 4 minutes)


    bool public gamePaused = false;
    bool public limitedReferralsMode = true; 
    uint public MAX_JACKPOT_ROLLOVERS = 10; 


    uint public instantWinChance = 300; 
    uint public safetyDepositChance = 150; 
    uint public safetyDepositMinSun = 100000000; // 100 TRX
    

    mapping(address => uint) public round_final_keys;
    address[] public playersInFinalDraw;
    uint public totalFinalKeys = 0;
    uint private lastKeySizePurchase = 0;

    mapping(address => bool) private m_referrals; // we only pay out on the first set of referrals
    
    
    // Game vars
    uint public jackpotSeed = 0;// Jackpot from previous rounds
    uint public instantWinJackpot = 0;
    uint public instantWin_startRnd = 0;

    
    uint public unclaimedReturns = 0;
    uint public constant MULTIPLIER = RAY;
    
    // Main stats:
    uint public totalJackpotsWon = 0;
    uint public totalInstantWinsWon = 0;
    uint public totalSafetyDepositsWon = 0;
    uint public totalKeysSold = 0;
    uint public totalEarningsGenerated = 0;
    uint public totalDistributedReturns = 0;

    
    // modifiers
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    modifier notOnPause() {
        require(gamePaused == false, "Game Paused");
        _;
    }
    


   // mainnet 4135f2719c2521c260a5f12d7fc3838e410a44e0c9
   // shasta 41666f5919fdf97dbd0d13f66658cf32ed5d2f938c
    rando internal rando_I = rando(0x35f2719c2521c260a5f12d7fc3838e410a44e0c9);

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
        gameDays.push(DayChart(0,now,currentDay,false,0));
        
    }
    function receiveInstantWinSeed() public payable {
        instantWinJackpot = instantWinJackpot.add(msg.value);
    }
    function receiveSafetyDepositSeed() public payable {
        rounds[latestRoundID].safetyDepositPot = rounds[latestRoundID].safetyDepositPot.add(msg.value);
    }

    function () public payable {
        buyKeys(address(0x0), instantWinChance, safetyDepositChance);
    }
    function pay() public payable {
    }

    // not working for previous rounds!
    function investorInfo(address investor, uint roundID) external view
    returns(uint keys, uint totalReturns, uint referralReturns, uint lastCumulativeReturnsPoints) 
    {

        GameRound storage rnd = rounds[roundID];
        keys = rnd.safeBreakers[investor].keys;
        lastCumulativeReturnsPoints = rnd.safeBreakers[investor].lastCumulativeReturnsPoints;
        (totalReturns, referralReturns) = estimateReturns(investor, roundID);
    }


    function investorFinalkeyInfo(address investor) external view returns (
            uint roundFinalKeys,
            uint roundFinalStartPercent,
            uint roundFinalEndPercent,
            uint roundTotalFinalKeys){

        roundFinalKeys = round_final_keys[investor];

        if(roundFinalKeys > 0) {

            uint _current_start_percent = 0;
            for(uint i=0; i< playersInFinalDraw.length; i++) {
                // 1000000000000000 = max
                // 100000 = 1 to 100,000 key difference
                uint _current_percent = 
                    round_final_keys[playersInFinalDraw[i]] * 100000 
                        /  totalFinalKeys;
                

                if(playersInFinalDraw[i] == investor) {

                    roundFinalStartPercent = _current_start_percent;
                    roundFinalEndPercent = (_current_percent + _current_start_percent);
                    break;

                }

                _current_start_percent = _current_start_percent + _current_percent;

            } 
        }
        else{
            roundFinalKeys = 0;
            roundFinalStartPercent = 0;
            roundFinalEndPercent = 0;
        }
            

        roundTotalFinalKeys = totalFinalKeys;




    }



      

        

    
    function roundInfo(uint roundID) external view 
    returns(
        address leader, 
        uint price,
        uint jackpot,  
        uint keys, 
        uint totalInvested,
        uint distributedReturns,
        uint _hardDeadline,
        uint _softDeadline,
        bool finalized,
        uint startTime,
        uint cumulativeReturnsPoints,
        bool isDark,

        uint safetyDepositPot

        )
    {
        GameRound storage rnd = rounds[roundID];
        
        price = rnd.price;
        
        //wmul(rnd.totalInvested, RETURNS_FRACTION);
        _hardDeadline = rnd.hardDeadline;

        // rnd.softDeadline is the time round ends
        // if within the last 2 minutes we enter blind phase and don't output it!

        if(isRoundOnDark()) {
            _softDeadline = 0;
            leader = address(0x0);

            isDark = true;
        } else {
            _softDeadline = rnd.softDeadline;
            leader = rnd.lastInvestor;

            isDark = false;
        }

        totalInvested = rnd.totalInvested;
        distributedReturns = rnd.distributedReturns; // m_currentRoundJackpotPercent.mul(rnd.totalInvested);
        jackpot = rnd.jackpot;
        keys = rnd.totalKeys;
        safetyDepositPot = rnd.safetyDepositPot;
        
        finalized = rnd.finalized;

        startTime = rnd.startTime;
        cumulativeReturnsPoints = rnd.cumulativeReturnsPoints;
        
    }

    // WORKING


    function isRoundOnDark() internal view returns (bool) {
        if(rounds[latestRoundID].softDeadline - now <= m_DarkMinutes 
                && rounds[latestRoundID].softDeadline - now > 0 seconds) {  
            return true;
        } else {

            return false;

        }
    }

    function dailyInfo() external view returns(
        uint dailyTotal,
        uint dayStartTs
        ) {

        dailyTotal = m_currentDailySplitPercent.mul(dailyTotalPot);
        dayStartTs = gameDays[currentDay].dayStartTs;
    }

    
    function totalsInfo() external view 
    returns(
        uint totalReturns,
        uint totalKeys,
        uint totalJackpots,
        uint totalInstantWins,
        uint totalSafetyDeposits,
        uint _totalDistributedReturns
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
        totalInstantWins = totalInstantWinsWon;
        totalSafetyDeposits = totalSafetyDepositsWon;
        _totalDistributedReturns = totalDistributedReturns;
    }

    
    function reinvestReturns(uint value, uint _instantWinCode, uint _safetyDepositCode) public validPlayer  {        
        reinvestReturns(value, address(0x0), _instantWinCode, _safetyDepositCode);
    }

    function reinvestReturns(uint value, address ref, uint _instantWinCode, uint _safetyDepositCode) public validPlayer  {        
        GameRound storage rnd = rounds[latestRoundID];
        _updateReturns(msg.sender, rnd);        
        require(vaults[msg.sender].totalReturns >= value, "Can't spend what you don't have");        
        vaults[msg.sender].totalReturns = vaults[msg.sender].totalReturns.sub(value);
        vaults[msg.sender].refReturns = min(vaults[msg.sender].refReturns, vaults[msg.sender].totalReturns);
        unclaimedReturns = unclaimedReturns.sub(value);
        _purchase(rnd, value, ref, _instantWinCode, _safetyDepositCode, true);
    }


    function estimateReturns(address investor, uint roundID) public view validPlayer 
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

        outstanding = outstanding.add(_outstandingReturns(investor, rnd));
        
        totalReturns = vaults[investor].totalReturns + outstanding;
        refReturns = vaults[investor].refReturns;
    }

    function withdrawReturns() public validPlayer {

        GameRound storage rnd = rounds[latestRoundID];

        if(latestRoundID > 0) {
             //if(rounds.length > 1) {// check if they also have returns from before
            if(hasReturns(msg.sender, latestRoundID - 1)) {
                GameRound storage prevRnd = rounds[latestRoundID - 1];
                _updateReturns(msg.sender, prevRnd);
            }
        }


        _updateReturns(msg.sender, rnd); // fail here when round has ended

        uint amount = vaults[msg.sender].totalReturns;
        require(amount > 0, "Nothing to withdraw!");
        
        if(amount > unclaimedReturns) {
        } else {
            unclaimedReturns = unclaimedReturns.sub(amount);
        }
        
        vaults[msg.sender].totalReturns = 0;
        vaults[msg.sender].refReturns = 0;
        
        rnd.safeBreakers[msg.sender].lastCumulativeReturnsPoints = rnd.cumulativeReturnsPoints;
        msg.sender.transfer(amount);

        emit ReturnsWithdrawn(latestRoundID, msg.sender, amount, now);
    }



    function hasReturns(address investor, uint roundID) public view validPlayer returns (bool) {
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


    function finalizeAndRestart(address _referer, uint _instantWinCode, uint _safetyDepositCode) public payable validPlayer {
        finalizeLastRound();
        startNewRound(_referer, _instantWinCode, _safetyDepositCode);
    }
    
    
    function startNewRound(address _referer, uint _instantWinCode, uint _safetyDepositCode) public payable checkDayRollover validPlayer {
        
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

        // clear final draw keys
        for(uint i=0; i< playersInFinalDraw.length; i++) {
            delete round_final_keys[playersInFinalDraw[i]];
        }
        delete playersInFinalDraw;
        totalFinalKeys = 0;


        if(latestRoundID - instantWin_startRnd > MAX_JACKPOT_ROLLOVERS) {
            // can't rollover instantWinJackpot more than MAX_JACKPOT_ROLLOVERS rounds!
            jackpotSeed = jackpotSeed.add(instantWinJackpot);
            emit InstantWinEnd(_rID, instantWinJackpot, now);
            instantWinJackpot = 0;
            instantWin_startRnd = latestRoundID;

        }

        rnd.jackpot = jackpotSeed;
        jackpotSeed = 0; 

        _purchase(rnd, msg.value, _referer, _instantWinCode, _safetyDepositCode, true);
        emit RoundStarted(_rID, rnd.hardDeadline, now);
    }
    

    function lastFreeKeyTime(address _player) validPlayer public view returns (uint _lastFreeKeyTime) {
        return lastDailyFreeKeyTime[_player];
    }
    function timeToFreeKey(address _player) validPlayer public view  returns(uint _timeToFreeKey) {
        return now - lastDailyFreeKeyTime[_player];
    }
    
    function dailyFreeKey(uint _instantWinCode) public notOnPause checkDayRollover validPlayer {
        // check last time free key was awarded for this player for > 24 hours ago...
        require(now - lastDailyFreeKeyTime[msg.sender] > 24 hours);
        // round mustn't be in dark phase...
        require(isRoundOnDark() == false);
        // round mustn't be on price double phase...
        require(rounds[latestRoundID].hardDeadline > now);
        // player must of purchased one key in this round to claim a free key...
        require(dayBuys[currentDay][msg.sender] > 0);
        
        lastDailyFreeKeyTime[msg.sender] = now;

        if(rounds.length > 0) {
            GameRound storage rnd = rounds[latestRoundID];   
            if( safeBreakersInRound[latestRoundID][msg.sender] == true ) {

            } else {
                safeBreakersInRound[latestRoundID][msg.sender] = true;
                playersInCurrentRound[latestRoundID].push(msg.sender);
            }

            _purchase(rnd, minInvestment, address(0x0), _instantWinCode, safetyDepositChance, false); // false = no funds added to the pot
        } else {
            revert("Not yet started");
        }
    }

    function buyKeys(address _referer, uint _instantWinCode, uint _safetyDepositCode) public payable notOnPause validPlayer  checkDayRollover {
        require(msg.value >= minInvestment);
        if(rounds.length > 0) {
            GameRound storage rnd = rounds[latestRoundID];   
            if( safeBreakersInRound[latestRoundID][msg.sender] == true ) {

            } else {
                safeBreakersInRound[latestRoundID][msg.sender] = true;
                playersInCurrentRound[latestRoundID].push(msg.sender);
            }

            _purchase(rnd, msg.value, _referer, _instantWinCode, _safetyDepositCode, true);
        } else {
            revert("Not yet started");
        }
        
    }
    
    


    function _purchase(GameRound storage rnd, uint value, address referer, uint _instantWinCode, uint _safetyDepositCode, bool _hasFunds) internal  {

        require(now >= rnd.startTime, "Round now started!");
        require(rnd.softDeadline >= now, "After deadline!");
        require(value >= rnd.price, "Not enough TRX!");

        if(_hasFunds == true){


            rnd.totalInvested = rnd.totalInvested.add(value);

            
            
        }

        // Set the last investor (to win the jackpot after the deadline if no final keys bought)
        rnd.lastInvestor = msg.sender;


        uint safetyDepositPrize;
        uint instantWinPrize;
        uint safetyDepositResult;
        uint instantWinResult;
        
        (safetyDepositPrize,safetyDepositResult) = _safetyDepositPrize(rnd, value, _safetyDepositCode);
        (instantWinPrize,instantWinResult) = _instantWin(_instantWinCode);

        if(_hasFunds == true){
            _splitRevenue(rnd, value, referer);
        }

        _updateReturns(msg.sender, rnd);


        uint newKeys = _issueKeys(rnd, msg.sender, value, 
                _instantWinCode,
                instantWinResult, instantWinPrize,
                _safetyDepositCode,
                safetyDepositResult, safetyDepositPrize);


        processDay(newKeys);


        if(!isRoundOnDark())
            // in case there are no final keys bought....
            lastKeySizePurchase = newKeys;
        else {

            // add the players keys to the final draw system...
            // final draw keys are then valid for the entire round! 
            if(round_final_keys[msg.sender] == 0){
                playersInFinalDraw.push(msg.sender);
                round_final_keys[msg.sender] = newKeys;
            } else {
                round_final_keys[msg.sender] = round_final_keys[msg.sender] + newKeys;
            }
            totalFinalKeys = totalFinalKeys + newKeys;
        }



        uint timeIncreases = newKeys/WAD;// since 1 key is represented by 1 * 10^18, divide by 10^18
        // adjust soft deadline to new soft deadline
        uint newDeadline = rnd.softDeadline.add( timeIncreases.mul(get_time_per_key()));
        
        rnd.softDeadline = min(newDeadline, now + soft_deadline_duration);
        // If after hard deadline, double the price every price increase periods
        if(now > rnd.hardDeadline) {
            if(now > rnd.lastPriceIncreaseTime + PRICE_INCREASE_PERIOD) {
                rnd.price = rnd.price * 2;
                rnd.lastPriceIncreaseTime = now;
            }
        }
    }




    function processDay(uint newKeys) internal {
        dayBuys[currentDay][msg.sender] = dayBuys[currentDay][msg.sender] + newKeys;
        //dayBuysTotals[currentDay].totalKeys = dayBuysTotals[currentDay].totalKeys + newKeys;
        gameDays[currentDay].dailyInvestments = gameDays[currentDay].dailyInvestments + newKeys;


        uint i = 0;
        uint c = 0;

        // check dayTopKeys[currentDay].length to see if player current keys is within and also if already within
        // if so.... push to dayTopKeys[currentDay] or update
        // if was push then...
        // ... then loop through to find new lowest and delete

        if(dayTopKeys[currentDay].length == 0) {
            //1st player of the day push and return;
            dayTopKeys[currentDay].push(NumOfKeys(msg.sender, dayBuys[currentDay][msg.sender]) );
            return;
        }

        bool playerCanJoinHighPlayers = false;
        uint currentPlayerPosition = 999;

        for(i; i< dayTopKeys[currentDay].length; i++) {
            if(dayTopKeys[currentDay][i].keys < dayBuys[currentDay][msg.sender]) {
                // new high score
                playerCanJoinHighPlayers = true;
            }
            if(dayTopKeys[currentDay][i].player == msg.sender) {
                currentPlayerPosition = i;
            }
        }
        if(!playerCanJoinHighPlayers) {
            if(dayTopKeys[currentDay].length < m_currentDailyTopPlayers) {
                dayTopKeys[currentDay].push(NumOfKeys(msg.sender, dayBuys[currentDay][msg.sender]) );
            }
            return;
        } else {
            if(currentPlayerPosition < 999) {
                dayTopKeys[currentDay][currentPlayerPosition].keys = dayBuys[currentDay][msg.sender];
            } else {
                dayTopKeys[currentDay].push(NumOfKeys(msg.sender, dayBuys[currentDay][msg.sender]));


                if(dayTopKeys[currentDay].length > m_currentDailyTopPlayers) {
                    c=9999999999999999999999;
                    for(i=0;i<dayTopKeys[currentDay].length;i++) {
                        if(dayTopKeys[currentDay][i].keys < c) {
                            c = i;
                        }
                    }
                    // remove position c...
                    for (i = c; i<dayTopKeys[currentDay].length-1; i++){
                        dayTopKeys[currentDay][i] = dayTopKeys[currentDay][i+1];
                    }
                    delete dayTopKeys[currentDay][dayTopKeys[currentDay].length-1];
                    dayTopKeys[currentDay].length--;
                }
            }

        }

        return;


        if(dayTopKeys[currentDay].length == 0) {
            //1st player of the day push and return;
            dayTopKeys[currentDay].push(NumOfKeys(msg.sender, dayBuys[currentDay][msg.sender]) );
            return;
        }

        
        bool foundResult = false;
        bool iIsSender = false;
        /** get the index of the current max element **/
        for(i; i < dayTopKeys[currentDay].length && i < m_currentDailyTopPlayers-1; i++) {

            if(dayTopKeys[currentDay][i].keys < dayBuys[currentDay][msg.sender]) {
                if(dayTopKeys[currentDay][i].player == msg.sender) {
                    iIsSender = true;
                }
                foundResult = true;
                break;
            }

        } // i = the position we should insert at

        // check if player position hasn't changed - if so do nothing...
        if(iIsSender){
            for(c=0; c < dayTopKeys[currentDay].length; c++) {
                if(dayTopKeys[currentDay][c].player == msg.sender) {
                    if(c==i) {
                        // no position change
                        // update
                        dayTopKeys[currentDay][c].keys = dayBuys[currentDay][msg.sender];
                        return;
                    } else {
                        // player has improved on their last so should be removed first
                        break;
                    }
                }
            }        
        } 

        if(foundResult){

            // is the player in the list at a lower position? - remove it if so
            uint posToRemove = 99999;
            for(c=i+1; c< dayTopKeys[currentDay].length; c++) {
                if(dayTopKeys[currentDay][c].player == msg.sender) {
                    posToRemove = c;
                    break;
                }
            }
            if(posToRemove < 99999){
                for (uint i2 = posToRemove; i2<dayTopKeys[currentDay].length-1; i2++){
                    dayTopKeys[currentDay][i2] = dayTopKeys[currentDay][i2+1];
                }
                delete dayTopKeys[currentDay][dayTopKeys[currentDay].length-1];
                dayTopKeys[currentDay].length--;
            }
        }
        


    
        if(i < m_currentDailyTopPlayers-1 && foundResult == false) {
            //push and return at the end;
            dayTopKeys[currentDay].push(NumOfKeys(msg.sender, dayBuys[currentDay][msg.sender]) );
            return;
        }


        
        if(i < dayTopKeys[currentDay].length){
            // only shift if i <= length...


            // take copy of last element if we have space at the end...
            NumOfKeys memory _temp;
            if(dayTopKeys[currentDay].length < m_currentDailyTopPlayers) {
                _temp.player= dayTopKeys[currentDay][dayTopKeys[currentDay].length-1].player;
                _temp.keys = dayTopKeys[currentDay][dayTopKeys[currentDay].length-1].keys;
            }



            /** shift the array of one position (getting rid of the last element) **/
            if(dayTopKeys[currentDay].length > 0 && i <= dayTopKeys[currentDay].length){
                for(uint j = dayTopKeys[currentDay].length - 1; j > i; j--) {
                    if(iIsSender && j -1 == i)
                        break;
                        
                    dayTopKeys[currentDay][j] = dayTopKeys[currentDay][j - 1];
                }
            }
            /** update the new max element **/
             
            dayTopKeys[currentDay][i].keys =  dayBuys[currentDay][msg.sender];
            dayTopKeys[currentDay][i].player =  msg.sender;

            if(dayTopKeys[currentDay].length < m_currentDailyTopPlayers) {
                // push last element 
                dayTopKeys[currentDay].push(_temp);

            }


        }
    }
    function TIME_PER_KEY() public view returns (uint) {
        if(isRoundOnDark()) {
            return 0; // Can't be viewed when the game goes Dark!
        } else {
            return time_per_key;
        }
    }

    // WORKING
    function get_time_per_key() internal returns (uint) {
        if(isRoundOnDark()) { 

            uint _bonus_time = rando_I.getRandoUInt(30, msg.sender);

            return base_time_per_key + _bonus_time;

        } else {
            return time_per_key;
        }
        
    }
    function _issueKeys(GameRound storage rnd, address _safeBreaker, uint value, 
                uint _instantWinCode,
                uint instantWinResult, uint instantWinPrize,
                uint _safetyDepositCode,
                uint safetyDepositResult, uint safetyDepositPrize

        ) internal returns(uint) { 

        if(rnd.safeBreakers[_safeBreaker].lastCumulativeReturnsPoints == 0) {
            rnd.safeBreakers[_safeBreaker].lastCumulativeReturnsPoints = rnd.cumulativeReturnsPoints;
        }    
        
        uint newKeys = wdiv(value, rnd.price);
        
        //bonuses:
        if(value >= 100000000000) { // 100,000 TRX
            newKeys = newKeys.mul(2);//get double keys if you paid more than 100 trx
        } else if(value >= 10000000000) { // 10,000 TRX
            newKeys = newKeys.add(newKeys/2);//50% bonus
        } else if(value >= 1000000000) { // 1,000 TRX
            newKeys = newKeys.add(newKeys/3);//33% bonus
        } else if(value >= 100000000) { // 100 TRX
            newKeys = newKeys.add(newKeys/10);//10% bonus
        }


        rnd.safeBreakers[_safeBreaker].keys = rnd.safeBreakers[_safeBreaker].keys.add(newKeys);
        rnd.totalKeys = rnd.totalKeys.add(newKeys);
        


        emit KeysIssued(latestRoundID, msg.sender, newKeys, now,
                _instantWinCode,
                instantWinResult, instantWinPrize,
                _safetyDepositCode,
                safetyDepositResult, safetyDepositPrize);


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
        uint newReturns = 0;

        if(rnd.cumulativeReturnsPoints > rnd.safeBreakers[_safeBreaker].lastCumulativeReturnsPoints){
            if(rnd.cumulativeReturnsPoints.sub(
                rnd.safeBreakers[_safeBreaker].lastCumulativeReturnsPoints
                ) > 0) {
                newReturns = rnd.cumulativeReturnsPoints.sub(
                                rnd.safeBreakers[_safeBreaker].lastCumulativeReturnsPoints
                             );        
            }
        }

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
        
        roundReturns = m_investorsPercent.mul(value); // 50%

        
        
        
        
        dailyTotalPot = dailyTotalPot.add(m_currentDailyTopPlayersPercent.mul(value));
        unclaimedReturns = unclaimedReturns.add(m_currentDailyTopPlayersPercent.mul(value));
        
        uint dev_value = m_devMarketingPercent.mul(value);

        

        // if this is the first purchase, roundReturns goes to jackpot (no one can claim these returns otherwise)
        if(rnd.totalKeys == 0) {
            rnd.jackpot = rnd.jackpot.add(roundReturns);
        } else {
            _disburseReturns(rnd, roundReturns);
        }
        
        rnd.safetyDepositPot = rnd.safetyDepositPot.add(m_airdropPercent.mul(value));
        instantWinJackpot = instantWinJackpot.add(m_instantwinPercent.mul(value)); // is failing out of energy here
        rnd.jackpot = rnd.jackpot.add(m_currentRoundJackpotPercent.mul(value));

        if(!devAddress.send(dev_value)){
            devHoldings = devHoldings + dev_value;
        }
        
    }
    function withdrawDevHoldings() public onlyOwner {
        if(devAddress.send(devHoldings))
            devHoldings = 0;
    }
    function _disburseReturns(GameRound storage rnd, uint value) internal {
        emit TrxDistributed(latestRoundID, value, now);
        rnd.distributedReturns = rnd.distributedReturns.add(value);
        totalDistributedReturns = totalDistributedReturns.add(value);

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
        }

    }
    function _safetyDepositPrize(GameRound storage rnd, uint value, uint _safetyDepositCode) internal returns (uint _SafetyDepositAmount, uint _safetyDepositResult) {

        if(value >= safetyDepositMinSun) { // 1000 TRX - TOTEST

             
            uint chance = rando_I.getRandoUInt(safetyDepositChance, msg.sender);

            _safetyDepositResult = chance;

            if(chance == _safetyDepositCode) {
                uint prize = rnd.safetyDepositPot;// win airdrop pot
                rnd.safetyDepositPot = 0;
                vaults[msg.sender].totalReturns = vaults[msg.sender].totalReturns.add(prize);
                unclaimedReturns = unclaimedReturns.add(prize);
                totalSafetyDepositsWon = totalSafetyDepositsWon.add(prize);

                //emit SafetyDepositResult(latestRoundID, msg.sender, prize, prize, now);
                //return prize;
                _SafetyDepositAmount = prize;
            } else {
                //emit SafetyDepositResult(latestRoundID, msg.sender, 0, prize, now);
                //return 0;
                _SafetyDepositAmount = 0;
            }
        } else {
            //return 0;
            _SafetyDepositAmount = 0;
        }
    }
    function _instantWin(uint _instantWinCode) internal returns (uint _instantWinAmount, uint _instantWinResult) {


        uint chance = rando_I.getRandoUInt(instantWinChance, msg.sender);
        _instantWinResult = chance;

        if(chance == _instantWinCode) {// once in 300 chance
            uint prize = instantWinJackpot;
            instantWinJackpot = 0;
            vaults[msg.sender].totalReturns = vaults[msg.sender].totalReturns.add(prize);
            unclaimedReturns = unclaimedReturns.add(prize);
            totalInstantWinsWon = totalInstantWinsWon.add(prize);
            //emit InstantWinResult(latestRoundID, msg.sender, prize, chance, now);
            //return prize;
            _instantWinAmount = prize;
        } else {
            //emit InstantWinResult(latestRoundID, msg.sender, 0, chance, now);
            //return 0;
            _instantWinAmount = 0;
        }

    }





    function _finalizeDay(uint _day) internal {
        if(gameDays[_day].isFinalized)
            return;
                   
        uint _totalDailySplit = m_currentDailySplitPercent.mul(dailyTotalPot);
        uint _dayTotalKeys = gameDays[_day].dailyInvestments; //dayBuysTotals[_day].totalKeys;


        for(uint c=0; c< dayTopKeys[_day].length; c++) {
            uint _percentOfPot = dayTopKeys[_day][c].keys * 10000  / _dayTotalKeys; 
            uint _amnt = (_totalDailySplit * _percentOfPot) / 10000;


            _processPlayerDayBonus(_day, dayTopKeys[_day][c].player, _amnt);
        }

        dailyTotalPot = dailyTotalPot.sub(_totalDailySplit);
        //dayBuysTotals[_day].totalPaid = _totalDailySplit;
        gameDays[_day].isFinalized = true;
        

    }

    function _processPlayerDayBonus(uint _day, address _player, uint _amnt) internal {
            vaults[_player].totalReturns = vaults[_player].totalReturns.add(_amnt);
            
            emit DailyPrize(_day, _player, _amnt, now);
    }



    
    function _finalizeRound(GameRound storage rnd) internal {
        require(!rnd.finalized, "Already finalized!");
        require(rnd.softDeadline < now, "Round still running!");


        // find vault winner

        if(rnd.jackpot > 0){
            if(playersInFinalDraw.length == 0){
                // use last key bought as the winner...
                vaults[rnd.lastInvestor].totalReturns = vaults[rnd.lastInvestor].totalReturns.add(rnd.jackpot);
                unclaimedReturns = unclaimedReturns.add(rnd.jackpot);
                emit JackpotWon(latestRoundID, rnd.lastInvestor, rnd.jackpot, 0,0,0,0, now);
                totalJackpotsWon = totalJackpotsWon.add(rnd.jackpot);

            } else {
                //uint _lucky_key_num = rando_I.getRandoUInt(totalFinalKeys, msg.sender);
                // 1000000
                // 
                uint _lucky_key_percent = rando_I.getRandoUInt(100000, msg.sender); // = 100.000 %
                
                uint _current_start_percent = 0;

                // keys is long val
                //
                for(uint i=0; i< playersInFinalDraw.length; i++) {
                    // 1000000000000000 = max
                    // 100000 = 1 to 100,000 key difference
                    uint _current_percent = 
                        round_final_keys[playersInFinalDraw[i]] * 100000 
                            /  totalFinalKeys;
                    

                    if(_lucky_key_percent > _current_start_percent  &&
                        _lucky_key_percent <= (_current_percent + _current_start_percent) 
                        ) {
                        // winner
                        vaults[playersInFinalDraw[i]].totalReturns = vaults[playersInFinalDraw[i]].totalReturns.add(rnd.jackpot);
                        unclaimedReturns = unclaimedReturns.add(rnd.jackpot);
                        emit JackpotWon(latestRoundID, playersInFinalDraw[i], rnd.jackpot, 
                                            _lucky_key_percent, 
                                            _current_start_percent,
                                            (_current_percent + _current_start_percent),
                                            round_final_keys[playersInFinalDraw[i]], 
                                            now);

                        totalJackpotsWon = totalJackpotsWon.add(rnd.jackpot);
                        break;                        
                    }

                    _current_start_percent = _current_start_percent + _current_percent;

                }        
            }
        }


        
        if(rnd.totalInvested > 0){
            // transfer the leftover to the next round's jackpot
            jackpotSeed = jackpotSeed.add( m_nextRoundSeedPercent.mul(rnd.totalInvested));        
        }

            
        if(rnd.safetyDepositPot > 0){
            //Empty the AD pot if it has a balance.
            jackpotSeed = jackpotSeed.add(rnd.safetyDepositPot);
            rnd.safetyDepositPot = 0;
        }

        totalKeysSold = totalKeysSold.add(rnd.totalKeys);

        if(rnd.totalInvested > 0)
            totalEarningsGenerated = totalEarningsGenerated.add(m_currentRoundJackpotPercent.mul(rnd.totalInvested));

        rnd.finalized = true;
    }
    
    // Owner only functions    
    function p_setOwner(address _owner) public onlyOwner {
        owner = _owner;
    }
    function p_setDevAddress(address _devAddress) public onlyOwner {
        devAddress = _devAddress;
    }





    function p_AddBonusReferralAccount(address _bonusAddr) public onlyOwner {
        bonusReferralAccounts[_bonusAddr] = true;
    }
    function p_DelBonusReferralAccounts(address _bonusAddr) public onlyOwner {
        bonusReferralAccounts[_bonusAddr] = false;
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

    function p_setSafetyDepositChance(uint _safetyDepositChance) public onlyOwner {
        safetyDepositChance = _safetyDepositChance;
    }

    
    function p_setInstantWinChance(uint _instantWinChance) public onlyOwner {
        instantWinChance = _instantWinChance;
    }
    function p_updateRando(address _randoAddr) public onlyOwner {
        rando_I = rando(_randoAddr);
    }
    function p_updateSafetyDepositMinSun(uint _safetyDepositMinSun) public onlyOwner {
        safetyDepositMinSun = _safetyDepositMinSun;
    }


    function p_settings(uint _type, uint _val) public onlyOwner {
        if(_type==0)
            unclaimedReturns = _val;
        if(_type==1)
            STARTING_KEY_PRICE = _val;
        if(_type==2)
            HARD_DEADLINE_DURATION = _val;
        if(_type==3)
            PRICE_INCREASE_PERIOD = _val;

        if(_type==20){
            m_currentRoundJackpotPercent = Percent.percent(_val, 100);
        }
        if(_type==21){
            m_currentDailyTopPlayersPercent = Percent.percent(_val, 100);
        }
        if(_type==22){
            m_currentDailySplitPercent = Percent.percent(_val, 100);
        }
        if(_type==23){
            m_currentDailyTopPlayers = _val;
        }
        if(_type==24){
            m_investorsPercent = Percent.percent(_val, 100);
        }
        if(_type==25){
            m_nextRoundSeedPercent = Percent.percent(_val, 100); 
        }
        if(_type==26){
            m_airdropPercent = Percent.percent(_val, 100); 
        }
        if(_type==27){
            m_instantwinPercent = Percent.percent(_val, 100);
        }
        if(_type==28){
            m_devMarketingPercent = Percent.percent(_val, 100);
        }
        if(_type==29){
            m_refPercent = Percent.percent(_val, 100);
        }
        if(_type==30){
            m_refPercent2 = Percent.percent(_val, 100);
        }

        if(_type==40){
            m_DarkMinutes = _val;
        }

    }

    function p_updateTimes(uint _type, uint _val) public onlyOwner {
        if(_type==0) {
            time_per_key = _val;   
        }
        if(_type==1) {
            base_time_per_key = _val;
        }
        if(_type==2) {
            bonus_potential_key_time = _val;
        }
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