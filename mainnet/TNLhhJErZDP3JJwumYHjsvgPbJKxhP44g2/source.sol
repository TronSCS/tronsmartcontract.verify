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

contract TronKnights {

    using SafeMath for uint256;

    uint256 constant COIN_PRICE = 10000;
    uint256 constant KNIGHT_TYPES = 8;
    uint256 constant PERIOD = 60 minutes;
    uint256 constant reminder = 1e6;

    uint256[KNIGHT_TYPES] prices = [6200e6, 12000e6, 47000e6, 178000e6, 620000e6, 1880000e6, 3800000e6, 8000000e6];
    uint256[KNIGHT_TYPES] profit = [8e6, 16e6, 64e6, 248e6,  880e6, 2720e6, 5600e6, 12120e6];
    uint256[KNIGHT_TYPES] glory = [1, 2, 4, 8, 16, 32, 64, 128];

    uint256 public totalPlayers;
    uint256 public totalKnights;
    uint256 public totalPayout;
    uint256 public dividendPerToken;
    uint256 public totalGlorySupply;

    mapping (address => mapping (address => uint256)) private _allowed;
    mapping (address => uint256) public dividendCreditedTo;

    address owner_;

    struct Player {
        uint256 coinsForBuy;
        uint256 coinsForSale;
        uint256 dividendCoins;
        uint256 divCoins;
        uint256 lastCreditedDividend;
        uint256 time;
        uint256[KNIGHT_TYPES] knights;
    }

    mapping(address => Player) public players;

    event Deposit(address indexed from, uint256 value);
    event Purchase(address indexed from, address indexed referredBy, uint256 coinsSpent, uint256 unitType, uint256 number);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Withdrawal(address indexed from, uint256 value);
    event ClaimDividends(address indexed from, uint256 value);

    constructor() public {
        owner_ = msg.sender;
    }

    // Views
    function totalBalance() public view returns(uint256) {
        return address(this).balance;
    }

    function unclaimedCoinsOf(address _addr) public view returns (uint256 coinsForBuy, uint256 coinsForSale) {
        Player memory player = players[_addr];
        uint256 hoursPassed = (now.sub(player.time)).div(PERIOD);

        if (hoursPassed > 0) {
            uint256 hourlyProfit;
            for (uint256 i = 0; i < KNIGHT_TYPES; i++) {
                hourlyProfit = hourlyProfit.add(player.knights[i].mul(profit[i]));
            }
            uint256 collectCoins = hoursPassed.mul(hourlyProfit);
            coinsForBuy = collectCoins.div(2);
            coinsForSale = collectCoins.div(2);
        }

        return (coinsForBuy, coinsForSale);
    }

    function gloryOf(address _addr) public view returns (uint256 gloryTotal) {
        Player memory player = players[_addr];

        for (uint256 i = 0; i < KNIGHT_TYPES; i++) {
            gloryTotal = gloryTotal.add(player.knights[i].mul(glory[i]));
        }

        return gloryTotal;
    }

    function unclaimedDividendsOf(address _addr) public view returns (uint256) {
        Player memory player = players[_addr];
        uint256 owed = dividendPerToken.sub(player.lastCreditedDividend);
        return gloryOf(_addr) * owed;
    }

    function dividendsOf(address _addr) public view returns (uint256) {
        Player memory player = players[_addr];
        return player.dividendCoins.add(unclaimedDividendsOf(_addr));
    }

    function coinsOf(address _addr) public view returns (uint256 coinsForBuy, uint256 coinsForSale) {
        Player memory player = players[_addr];
        (coinsForBuy, coinsForSale) = unclaimedCoinsOf(_addr);
        return (coinsForBuy.add(player.coinsForBuy), coinsForSale.add(player.coinsForSale));
    }

    function knightsOf(address _addr) public view returns (uint256[KNIGHT_TYPES]) {
        return players[_addr].knights;
    }

    // Public methods
    function deposit() public payable {
        require(msg.value >= COIN_PRICE);

        Player storage player = players[msg.sender];
        player.coinsForBuy = player.coinsForBuy.add(msg.value.div(COIN_PRICE).mul(reminder));

        if (player.time == 0) {
            player.time = now;
            totalPlayers++;
        }

        emit Deposit(msg.sender, msg.value);
    }

    function buy(address _referredBy, uint256 _type, uint256 _number) public {
        require(_type < KNIGHT_TYPES && _number > 0, "Item is not found");
        _collect(msg.sender);
        uint256 paymentCoins = prices[_type].mul(_number);
        Player storage player = players[msg.sender];

        require(paymentCoins <= player.coinsForBuy.add(player.coinsForSale),  "Not enough coins");

        totalGlorySupply = totalGlorySupply.add(glory[_type].mul(_number));
        dividendPerToken += paymentCoins.mul(2).div(100).div(totalGlorySupply);

        if (paymentCoins <= player.coinsForBuy) {
            player.coinsForBuy = player.coinsForBuy.sub(paymentCoins);
        } else {
            player.coinsForSale = player.coinsForSale.add(player.coinsForBuy).sub(paymentCoins);
            player.coinsForBuy = 0;
        }

        if (_referredBy != address(0) && _referredBy != msg.sender && players[_referredBy].time > 0) {
            players[_referredBy].coinsForSale = players[_referredBy].coinsForSale.add(paymentCoins.mul(25).div(1000));
            players[owner_].coinsForSale = players[owner_].coinsForSale.add(paymentCoins.mul(75).div(1000));
        } else {
            players[owner_].coinsForSale = players[owner_].coinsForSale.add(paymentCoins.mul(100).div(1000));
        }

        player.knights[_type] = player.knights[_type].add(_number);
        totalKnights = totalKnights.add(_number);
        emit Purchase(msg.sender, _referredBy,  paymentCoins, _number, _type);
    }

    function collectDivs() public {
        Player storage player = players[msg.sender];
        _collect(msg.sender);
        require(player.dividendCoins > 0,  "Not enough coins");
        uint256 divs = player.dividendCoins;
        player.coinsForBuy = player.coinsForBuy.add(divs);
        player.dividendCoins = 0;
        emit ClaimDividends(msg.sender, divs);
    }

    function withdraw(uint256 _coins) public {
        require(_coins > 0);
        _collect(msg.sender);
        require(_coins <= players[msg.sender].coinsForSale);

        players[msg.sender].coinsForSale = players[msg.sender].coinsForSale.sub(_coins);
        _move(msg.sender, _coins.mul(COIN_PRICE).div(reminder));
    }

    // Internal methods
    function _collect(address _addr) internal {
        Player storage player = players[_addr];
        require(player.time > 0);
        uint256 hoursPassed = (now.sub(player.time)).div(PERIOD);

        if (hoursPassed > 0) {
            uint256 hourlyProfit;
            for (uint256 i = 0; i < KNIGHT_TYPES; i++) {
                hourlyProfit = hourlyProfit.add(player.knights[i].mul(profit[i]));
            }
            uint256 collectCoins = hoursPassed.mul(hourlyProfit);
            player.coinsForBuy = player.coinsForBuy.add(collectCoins.div(2));
            player.coinsForSale = player.coinsForSale.add(collectCoins.div(2));
            player.time = player.time.add(hoursPassed.mul(PERIOD));
        }

        player.dividendCoins = player.dividendCoins.add(unclaimedDividendsOf(_addr));
        player.lastCreditedDividend = dividendPerToken;
    }

    function _move(address _receiver, uint256 _amount) internal {
        if (_amount > 0 && _receiver != address(0)) {
            uint256 contractBalance = address(this).balance;
            if (contractBalance > 0) {
                uint256 payout = _amount > contractBalance ? contractBalance : _amount;
                totalPayout = totalPayout.add(payout);
                msg.sender.transfer(payout);

                emit Withdrawal(msg.sender, payout);
            }
        }
    }

    // TRX20-compatible transfer methods
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowed[owner][spender];
    }

    function transfer(address to, uint256 value) public returns (bool) {
        _collect(msg.sender);
        _collect(to);
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _collect(msg.sender);
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool) {
        _collect(from);
        _collect(to);
        _transfer(from, to, value);
        _approve(from, msg.sender, _allowed[from][msg.sender].sub(value));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _collect(msg.sender);
        _collect(spender);
        _approve(msg.sender, spender, _allowed[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _collect(msg.sender);
        _collect(spender);
        _approve(msg.sender, spender, _allowed[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(to != address(0));
        players[from].coinsForSale = players[from].coinsForSale.sub(value);
        players[to].coinsForSale = players[to].coinsForSale.add(value);
        emit Transfer(from, to, value);
    }

    function _approve(address owner, address spender, uint256 value) internal {
        require(spender != address(0));
        require(owner != address(0));
        _allowed[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

}