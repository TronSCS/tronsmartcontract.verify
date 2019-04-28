pragma solidity ^0.4.25;

contract TronOwls {

    using SafeMath for uint256;
    
	uint constant TO_SUN = 1000000; //trx to sun
	uint constant PERIOD = 30 days; 
	
    uint[5] owlsPrices = [100, 532, 1500, 5000, 15000]; //trx price
    uint[5] magicIncome = [60, 62, 64, 66, 68]; //% per 30 days

    uint public totalPlayers;
    uint public totalOwls;
    uint public totalPayout;

    struct lastInvestor {
		address investor;
        uint time;
        uint value;
    }	

	lastInvestor[5] public lastFiveInvestors; 
	
    struct Player {
        uint time;
		uint magic;
		uint invested;
		uint payout;
		uint bonus;
		address referrer;
        uint[5] owls;
    }
	
    mapping(address => Player) public players;

    address owner;	
	address manager;
	
    constructor(address _manager) public {
        owner = msg.sender;
		manager = _manager;
    }
	
    function buyForTrx(uint _owl, uint _number, address _referredBy) public payable {
        require(_owl >= 0 && _owl <= 4 && _number > 0);
		
		uint owlsPrice = owlsPrices[_owl].mul(_number).mul(TO_SUN);
		
		require(owlsPrice == msg.value);
		
		if (msg.value >= 5000000000) //5000trx
			addLastInvestor(msg.sender,msg.value);

        Player storage player = players[msg.sender];

        if (player.time > 0)
			collectMagic(msg.sender);		
		
        if (player.time == 0) {
			if (player.referrer == address(0)) {
				if (_referredBy != address(0) && _referredBy != msg.sender && players[_referredBy].time > 0) {
					player.referrer = _referredBy;
				} else {
					player.referrer = manager;
				}
			}
			
            player.time = now;
            totalPlayers++;
        }	
		
        player.owls[_owl] = player.owls[_owl].add(_number);
		//save stat
		player.invested = player.invested.add(msg.value);
        totalOwls = totalOwls.add(_number);
		players[owner].magic = players[owner].magic.add(msg.value.div(10)); //10%
    }	
	
    function buyForMagic(uint _owl, uint _number) public {
        require(_owl >= 0 && _owl <= 4 && _number > 0);
		
		uint owlsMagicPrice = owlsPrices[_owl].mul(_number).mul(TO_SUN).mul(70).div(100);
		
        Player storage player = players[msg.sender];

        if (player.time > 0)
			collectMagic(msg.sender);		
			
		require(player.magic >= owlsMagicPrice);
		
        player.owls[_owl] = player.owls[_owl].add(_number);
		player.magic = player.magic.sub(owlsMagicPrice);
		
        totalOwls = totalOwls.add(_number);		
    }		
	
	function addLastInvestor(address _addr, uint _value) internal {
		lastInvestor storage investor;
		lastInvestor storage investorPrev;
		collectMagicBonus();
		for (uint i = 4; i >= 1; i--) {
			investor = lastFiveInvestors[i];
			investorPrev = lastFiveInvestors[i-1];
			investor.investor = investorPrev.investor;
			investor.time = now;
			investor.value = investorPrev.value;
		}
		investor = lastFiveInvestors[0];
		investor.investor = _addr;
        investor.time = now;
        investor.value = _value;
	}
	
	function collectMagicBonus() internal {	
		lastInvestor storage investor;
		uint profit;
		for (uint i = 0; i <= 4; i++) {
			investor = lastFiveInvestors[i];
			if (investor.value > 0) {
				//3% per day
				profit = investor.value.mul( now.sub(investor.time) ).mul(3).div(1 days).div(100);	
				players[investor.investor].magic = players[investor.investor].magic.add(profit);
				//save stat
				players[investor.investor].bonus = players[investor.investor].bonus.add(profit);
			}
		}
	}
	
    function withdraw(uint _magic) public {
        require(_magic > 0);
		Player storage player = players[msg.sender];
		require (player.time > 0);
		
        collectMagic(msg.sender);
		
        require(_magic <= player.magic);
		
		player.magic = player.magic.sub(_magic);
		
		//1 magic = 1 trx;
		msg.sender.transfer(_magic);
		//save stat
		player.payout = player.payout.add(_magic);
		totalPayout = totalPayout.add(_magic);
    }	

    function collectMagic(address _addr) public {
        Player storage player = players[_addr];
		if (player.time > 0) {			
			uint profit = getMagicProfit(_addr);

			address referrer = player.referrer;
			if (referrer != address(0)) 
				players[referrer].magic = players[referrer].magic.add(profit.mul(5).div(100)); //5% to refferer

			player.magic = player.magic.add(profit);
			player.time = now;
		}
    }	
		
	function getMagicProfit(address _addr) public view returns(uint) {
		uint profit;
		if (players[_addr].time > 0) {
			for (uint i = 0; i <= 4; i++) {
				profit = profit.add( players[_addr].owls[i].mul(owlsPrices[i]).mul(magicIncome[i]).mul(TO_SUN) );
			}
			profit = profit.mul( now.sub(players[_addr].time) ).div(PERIOD).div(100);	
		}
		return profit;
	}
	
    function owlsOf(address _addr) public view returns (uint[5]) {
        return players[_addr].owls;
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