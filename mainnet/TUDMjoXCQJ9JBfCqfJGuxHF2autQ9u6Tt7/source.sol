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




contract TronHeistPrizes {
    


    // Events    
    event AirdropWon(uint indexed rnd, address by, uint amount, uint timestamp);

    event MegaFundWon(uint indexed rnd, address by, uint amount, uint timestamp);


    address owner;


    uint public airdrop_prize = 0;
    uint public mega_prize = 0;
    
    
    // modifiers
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
    constructor() public {

        owner = msg.sender;
        
    }

    function () public payable {
        
    }

    function getPrizes() public view returns (uint airdropPrize, uint megaPrize) {
        airdropPrize = airdrop_prize;
        megaPrize = mega_prize;
    }

    function updatePrizes(uint _airdrop_prize, uint _mega_prize) public payable onlyOwner {
        airdrop_prize = airdrop_prize + _airdrop_prize;
        mega_prize = mega_prize + _mega_prize;
    }

    function awardAirdropPrize(uint _rnd, address _to) public onlyOwner {
        uint _airdrop_prize = airdrop_prize;
        
        if(_to.send(_airdrop_prize)){
            airdrop_prize = 0;
            emit AirdropWon(_rnd, _to, _airdrop_prize, now);
        }
        
    }

    function awardMegaJackpotPrize(uint _rnd, address _to) public onlyOwner {
        uint _mega_prize = mega_prize;
        
        if(_to.send(_mega_prize)){
            mega_prize = 0;
            emit MegaFundWon(_rnd, _to, _mega_prize, now);
        }
        
    }



}