pragma solidity ^0.4.23;


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


contract TronWin {

    using SafeMath for uint256;
    using Percent for Percent.percent;

    // events

    event GameResult(uint indexed gameID, address indexed player, uint timestamp,
        uint guess,
        uint result,
        uint winAmount);


    address public owner;



    // settings
    Percent.percent private m_refPercent1 = Percent.percent(10, 100);
    Percent.percent private m_refPercent2 = Percent.percent(15, 100);
    Percent.percent private m_prizePercent = Percent.percent(90, 100);
    Percent.percent private m_devPercent = Percent.percent(10, 100);
    Percent.percent private m_prizeAwardedPercent = Percent.percent(70, 100); // the remainder (30% goes to seed the next game - building an ever growing pot size)

    mapping(address => bool)    referralLvl2Addresses;


    // game data
    struct game {
        uint    maxNum;
        uint    entryFee;
        uint    maxPlayTRX;
        uint    currentPot;
        uint    totalAwarded;
        uint    totalPlayers;
        uint    totalPlays;
        bool    paused;
        uint    startTS;
        uint    endTS;
    }

    struct player {
        uint    referralEarned;
        uint    totalEarned;
        uint    totalAvailable;
        uint    totalPlays;
        uint    lastOnline;
    }

    game[]      games;
    mapping(address => player)  players;
    mapping(address => mapping(uint => bool)) playersInGameIDs;

    address[]    playersList;

    bool public gameOnPause;
    uint public devHoldings;
    address     devAddress;



    
    // modifiers
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier validGame(uint _gameID) {
        require(!gameOnPause, "All games paused!");
        require(games[_gameID].startTS <= now, "Game now started yet!");
        require(games[_gameID].endTS >= now || games[_gameID].endTS == 0, "Game has ended");
        require(!games[_gameID].paused, "Game is on pause!");
        require(msg.value >= games[_gameID].entryFee && msg.value <= games[_gameID].maxPlayTRX, "Incorrect TRX sent!");

        _;
    }


    // rando
    rando internal rando_I = rando(0x35f2719c2521c260a5f12d7fc3838e410a44e0c9);
    

    constructor() public {

        owner = msg.sender;
        devAddress = owner;
    }

    // public functions
    function gamesLen() public view returns (uint) {
        return games.length;
    }
    function getPlayersLen() public view returns (uint) {
        return playersList.length;
    }
    function getPlayerAddr(uint _pos) public view returns (address) {
        return playersList[_pos];
    }

    function getPlayer(address _player) public view returns (
        uint    referralEarned,
        uint    totalEarned,
        uint    totalAvailable,
        uint    totalPlays,
        uint    lastOnline
            ) {
        referralEarned = players[_player].referralEarned;
        totalEarned = players[_player].totalEarned;
        totalAvailable = players[_player].totalAvailable;
        totalPlays = players[_player].totalPlays;
        lastOnline = players[_player].lastOnline;
    }
    function withdraw() public {
        uint _amnt = players[msg.sender].totalAvailable;
        players[msg.sender].totalAvailable = 0;
        msg.sender.transfer(_amnt);
    }

    function getGame(uint _gameID) public view returns 
            (
                uint    maxNum,
                uint    entryFee,
                uint    maxPlayTRX,
                uint    currentPot,
                uint    currentPrize,
                uint    totalAwarded,
                uint    totalPlayers,
                uint    totalPlays,
                bool    paused,
                uint    startTS,
                uint    endTS
            ) {
        maxNum = games[_gameID].maxNum;
        entryFee = games[_gameID].entryFee;
        maxPlayTRX = games[_gameID].maxPlayTRX;
        currentPot = games[_gameID].currentPot;
        currentPrize = m_prizeAwardedPercent.mul(games[_gameID].currentPot);
        totalAwarded = games[_gameID].totalAwarded;
        totalPlayers = games[_gameID].totalPlayers;
        totalPlays = games[_gameID].totalPlays;
        paused = games[_gameID].paused;
        startTS = games[_gameID].startTS;
        endTS = games[_gameID].endTS;
    }


    function playGame(uint _gameID, uint _guess, address _ref) public payable validGame(_gameID) returns (uint prize, uint game_result) {
        uint value = msg.value;

        // any referrals due?
        if(_ref != address(0x0) && _ref != msg.sender) {

            uint _referralEarning;

            if(referralLvl2Addresses[_ref] == true)
                _referralEarning = m_refPercent2.mul(value);
            else
                _referralEarning = m_refPercent1.mul(value);


            players[_ref].referralEarned = players[_ref].referralEarned.add(_referralEarning);
            players[_ref].totalEarned = players[_ref].totalEarned.add(_referralEarning);
            players[_ref].totalAvailable = players[_ref].totalAvailable.add(_referralEarning);
            
            value = value.sub(_referralEarning);
                        
        }

        // send the dev amount...
        uint dev_value = m_devPercent.mul(value);
        if(!devAddress.send(dev_value)){
            devHoldings = devHoldings + dev_value;
        }

        // rest goes into the pot...
        games[_gameID].currentPot = games[_gameID].currentPot.add(m_prizePercent.mul(value));


        if(players[msg.sender].lastOnline == 0){
            // new player
            players[msg.sender].lastOnline = now;
            playersList.push(msg.sender);
        }

        // has this player played in this game??
        if(playersInGameIDs[msg.sender][_gameID] == true) {

        } else {
            playersInGameIDs[msg.sender][_gameID] = true;
            games[_gameID].totalPlayers = games[_gameID].totalPlayers + 1;
        }

        games[_gameID].totalPlays = games[_gameID].totalPlays + 1;
        

        // play each roll separately...
        // TOTEST - if we send 25 we should only get 2 rolls and not 3!
        uint _tries = 1;
        if(msg.value > games[_gameID].entryFee) {
            _tries = msg.value/games[_gameID].entryFee;
        }

        for(uint c=0; c<_tries;c++) {

            // get the random result...
            game_result = rando_I.getRandoUInt(games[_gameID].maxNum, msg.sender);
            
            if(game_result == _guess) {
                // winner
                prize = m_prizeAwardedPercent.mul(games[_gameID].currentPot);

                players[msg.sender].totalEarned = players[msg.sender].totalEarned.add(prize);
                players[msg.sender].totalAvailable = players[msg.sender].totalAvailable.add(prize);
                games[_gameID].totalAwarded = games[_gameID].totalAwarded.add(prize);
                games[_gameID].currentPot = games[_gameID].currentPot.sub(prize);

            } else {
                prize = 0;
            }


            emit GameResult(_gameID, msg.sender, now,
                _guess,
                game_result, 
                prize);

        }

    } 




    // admin functions
    function p_setOwner(address _owner) public onlyOwner {
        owner = _owner;
    }
    function p_setPause(bool _gameOnPause) public onlyOwner {
        gameOnPause = _gameOnPause;
    }
    function p_updateRando(address _randoAddr) public onlyOwner {
        rando_I = rando(_randoAddr);
    }
    function p_updateSettings(uint _type, uint _val) public onlyOwner {
        if(_type == 0){
            m_refPercent1 = Percent.percent(_val, 100);
        }
        if(_type == 1){
            m_refPercent2 = Percent.percent(_val, 100);
        }
        if(_type == 2){
            m_prizePercent = Percent.percent(_val, 100);
        }
        if(_type == 3){
            m_devPercent = Percent.percent(_val, 100);
        }
    }
    function p_updateLvl2Referral(address _addr, bool _allow) public onlyOwner {
        referralLvl2Addresses[_addr] = _allow;
    }
    function p_addGame(
                uint    maxNum,
                uint    entryFee,
                uint    maxPlayTRX,
                bool    paused,
                uint    startTS,
                uint    endTS
            ) public onlyOwner returns (uint _gameID) {

        games.push(game(maxNum, entryFee,maxPlayTRX,0,0,0,0,paused,startTS,endTS));  

        _gameID = games.length-1;
    }
    function p_updateGame(
                uint _gameID,
                uint    maxNum,
                uint    entryFee,
                uint    maxPlayTRX,
                bool    paused,
                uint    startTS,
                uint    endTS
            ) public onlyOwner {
        games[_gameID].maxNum = maxNum;
        games[_gameID].entryFee = entryFee;
        games[_gameID].maxPlayTRX = maxPlayTRX;
        games[_gameID].paused = paused;
        games[_gameID].startTS = startTS;
        games[_gameID].endTS = endTS;
    }
    function p_withdrawDevHoldings() public onlyOwner {
        if(devAddress.send(devHoldings))
            devHoldings = 0;
    }

}