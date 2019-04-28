pragma solidity ^0.4.23;

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

contract ClashRoyale {

    using SafeMath for uint256;

    uint constant COIN_PRICE = 40000;
    uint constant TYPES_WARRIORS = 12;
    uint constant PERIOD = 60 minutes;
				
    uint[TYPES_WARRIORS] prices = [3025, 6000, 11900, 23500, 46500, 92200, 182500, 361300, 715200, 1415600, 2801600, 5544300];
    uint[TYPES_WARRIORS] profit = [4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192];
	// income per month:         95% 96% 97% 98% 99% 100% 101% 102% 103%  104%  105%  106%

    uint public totalPlayers;
    uint public totalWarriors;
    uint public totalPayout;

    address owner;
    address manager;

    struct Player {
        uint coinsForBuy;
        uint coinsForSale;
        uint time;
        uint[TYPES_WARRIORS] warriors;
    }

    mapping(address => Player) public players;

    constructor(address _owner, address _manager) public {
        owner = _owner;
        manager = _manager;
    }

    function deposit() public payable {
        require(msg.value >= COIN_PRICE);

        Player storage player = players[msg.sender];
        player.coinsForBuy = player.coinsForBuy.add(msg.value.div(COIN_PRICE));

        if (player.time == 0) {
            player.time = now;
            totalPlayers++;
        }
    }

    function buy(uint _type, uint _number) public {
        require(_type < TYPES_WARRIORS && _number > 0);
        collect(msg.sender);

        uint paymentCoins = prices[_type].mul(_number);
        Player storage player = players[msg.sender];

        require(paymentCoins <= player.coinsForBuy.add(player.coinsForSale));

        if (paymentCoins <= player.coinsForBuy) {
            player.coinsForBuy = player.coinsForBuy.sub(paymentCoins);
        } else {
            player.coinsForSale = player.coinsForSale.add(player.coinsForBuy).sub(paymentCoins);
            player.coinsForBuy = 0;
        }

        player.warriors[_type] = player.warriors[_type].add(_number);
        players[owner].coinsForSale = players[owner].coinsForSale.add( paymentCoins.mul(75).div(1000) );
        players[manager].coinsForSale = players[manager].coinsForSale.add( paymentCoins.mul(25).div(1000) );

        totalWarriors = totalWarriors.add(_number);
    }

    function withdraw(uint _coins) public {
        require(_coins > 0);
        collect(msg.sender);
        require(_coins <= players[msg.sender].coinsForSale);

        players[msg.sender].coinsForSale = players[msg.sender].coinsForSale.sub(_coins);
        transfer(msg.sender, _coins.mul(COIN_PRICE));
    }

    function collect(address _addr) internal {
        Player storage player = players[_addr];
        require(player.time > 0);

        uint hoursPassed = ( now.sub(player.time) ).div(PERIOD);
        if (hoursPassed > 0) {
            uint hourlyProfit;
            for (uint i = 0; i < TYPES_WARRIORS; i++) {
                hourlyProfit = hourlyProfit.add( player.warriors[i].mul(profit[i]) );
            }
            uint collectCoins = hoursPassed.mul(hourlyProfit);
            player.coinsForBuy = player.coinsForBuy.add( collectCoins.div(2) );
            player.coinsForSale = player.coinsForSale.add( collectCoins.div(2) );
            player.time = player.time.add( hoursPassed.mul(PERIOD) );
        }
    }

    function transfer(address _receiver, uint _amount) internal {
        if (_amount > 0 && _receiver != address(0)) {
            uint contractBalance = address(this).balance;
            if (contractBalance > 0) {
                uint payout = _amount > contractBalance ? contractBalance : _amount;
                totalPayout = totalPayout.add(payout);
                msg.sender.transfer(payout);
            }
        }
    }

    function warriorsOf(address _addr) public view returns (uint[TYPES_WARRIORS]) {
        return players[_addr].warriors;
    }

}