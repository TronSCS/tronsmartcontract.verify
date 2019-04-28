pragma solidity ^0.4.25;


/***********************************************************
 * @title SafeMath v0.1.9
 * @dev Math operations with safety checks that throw on error
 * change notes:  original SafeMath library from OpenZeppelin modified by Inventor
 * - added sqrt
 * - added sq
 * - added pwr 
 * - changed asserts to requires with error log outputs
 * - removed div, its useless
 ***********************************************************/
 library SafeMath {
    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) 
        internal 
        pure 
        returns (uint256 c) 
    {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        require(c / a == b, "SafeMath mul failed");
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
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b)
        internal
        pure
        returns (uint256) 
    {
        require(b <= a, "SafeMath sub failed");
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b)
        internal
        pure
        returns (uint256 c) 
    {
        c = a + b;
        require(c >= a, "SafeMath add failed");
        return c;
    }
    
    /**
     * @dev gives square root of given x.
     */
    function sqrt(uint256 x)
        internal
        pure
        returns (uint256 y) 
    {
        uint256 z = ((add(x,1)) / 2);
        y = x;
        while (z < y) 
        {
            y = z;
            z = ((add((x / z),z)) / 2);
        }
    }
    
    /**
     * @dev gives square. multiplies x by x
     */
    function sq(uint256 x)
        internal
        pure
        returns (uint256)
    {
        return (mul(x,x));
    }
    
    /**
     * @dev x to the power of y 
     */
    function pwr(uint256 x, uint256 y)
        internal 
        pure 
        returns (uint256)
    {
        if (x==0)
            return (0);
        else if (y==0)
            return (1);
        else 
        {
            uint256 z = x;
            for (uint256 i=1; i < y; i++)
                z = mul(z,x);
            return (z);
        }
    }
}

/***********************************************************
 * SDDatasets library
 ***********************************************************/
library SDDatasets {
    struct Player {
        address addr;   // player address
        uint256 laff;
        uint256 invested;
        uint256 aff;    // affiliate vault,directly send
        uint256 reward;
        uint256 divMask;
        uint256 waitPayTrx;
    }  

    struct DailyTop {
        address addr;   // player address
        uint256 invested;
    }  
}


contract Doo {

    using SafeMath              for *;

    uint256 public G_AllInvest = 0;
    uint256 public G_AllDivsPot = 100000*1e6;
    uint256 public G_Mask = 0;

    mapping (address => uint256) public pIDxAddr_;  
    mapping (uint256 => SDDatasets.Player) public player_; 

    uint256 public G_RoundId = 1;
    mapping (uint256 => mapping(uint256 => SDDatasets.DailyTop)) public G_TopPlayer; 
    mapping (uint256 => mapping(address => uint256)) public G_DailyInvest; 

   address public devAddr_ = address(0x41EE30E2F71288A8A92532F355264A4B51843053FF);

	address public botROIAddr_ = address(0x41B5C2A7D8129F42ABB364698F70EB416456C8AF59);
	address public botD3TAddr_ = address(0x4113615A88D963F11C86EF66FCCC42F2F3A01C4E20);

    uint256 public G_NowUserId = 1000; //first user

    uint256 public DivsInterval = 24*60*60; //Dividend interval(second)
    uint256 public BeginTime = 1553954400;

    int256 public StartTime_ = 1553954400;
    function timeLeft() public view returns (int256) {
        return StartTime_ - int256(now);
    }

    function() payable public {
    }

    constructor() public {

        uint256 pId = G_NowUserId;
        pIDxAddr_[msg.sender] = pId;
        player_[pId].addr = msg.sender;

    }

	function register_(address addr, uint256 _affCode) private{
        G_NowUserId = G_NowUserId.add(1);
        
        address _addr = addr;
        
        pIDxAddr_[_addr] = G_NowUserId;

        player_[G_NowUserId].addr = _addr;
        player_[G_NowUserId].laff = _affCode;
        player_[G_NowUserId].invested = 0;
        player_[G_NowUserId].aff = 0;
        player_[G_NowUserId].divMask = G_Mask;
        player_[G_NowUserId].waitPayTrx = 0;
        player_[G_NowUserId].reward = 0;
	}
	

    function invest(uint256 _affCode) public payable {
        require(timeLeft() <= 0, "wait ..."); 
		require(msg.value >= 1000000, "invest amount error, min depost 1 trx");

        dailyDivs();

		//get uid
		uint256 uid = pIDxAddr_[msg.sender];
		
		//first
		if (uid == 0) {
		    if (player_[_affCode].addr != address(0)) {
		        register_(msg.sender, _affCode);
		    } else {
			    register_(msg.sender, 1000);
		    }
		    
			uid = G_NowUserId;
		}

        //buy
        uid = pIDxAddr_[msg.sender];
        uint256 affCode = player_[uid].laff;

        player_[uid].waitPayTrx = player_[uid].waitPayTrx.add(dividendsOf(msg.sender));
        player_[uid].divMask = G_Mask;

        player_[uid].invested = player_[uid].invested.add(msg.value);

        G_AllInvest = G_AllInvest.add(msg.value);

        uint256 pot = msg.value.mul(86).div(100);
        G_AllDivsPot = G_AllDivsPot.add(pot);

        //distribute
        distribute(msg.value, affCode);        

        topRecord(msg.value);
    }

    function reInvest() public payable {
		//get uid
		uint256 uid = pIDxAddr_[msg.sender];
	    require(uid != 0, "no invest");

        uint256 affCode = player_[uid].laff;

        uint256 divs = player_[uid].waitPayTrx.add(dividendsOf(msg.sender));
        divs = divs.add(player_[uid].reward);
        require(divs > 0, "no divs");

        dailyDivs();

        player_[uid].divMask = G_Mask;
        player_[uid].waitPayTrx = 0;
        player_[uid].reward = 0;

        player_[uid].invested = player_[uid].invested.add(divs);

        G_AllInvest = G_AllInvest.add(divs);

        uint256 pot = divs.mul(86).div(100);
        G_AllDivsPot = G_AllDivsPot.add(pot);

        //distribute
        distribute(divs, affCode);     

        topRecord(divs);   
    }

    function distribute(uint256 _trx, uint256 _affID) private{
        //ref
        uint256 ref = (_trx.mul(5)).div(100);
        player_[_affID].addr.transfer(ref);
        player_[_affID].aff = player_[_affID].aff.add(ref);

        //dev
        uint256 dev = (_trx.mul(3)).div(100);
        devAddr_.transfer(dev);

        //d3t
        uint256 d3t = (_trx.mul(3)).div(100);
        botD3TAddr_.transfer(d3t);

        //roi
        uint256 roi = (_trx.mul(3)).div(100);
        botROIAddr_.transfer(roi);

    }
    
	function withdraw() public payable {
	    require(msg.value == 0, "withdraw fee is 0 trx, please set the exact amount");

	    uint256 uid = pIDxAddr_[msg.sender];
	    require(uid != 0, "no invest");

        dailyDivs();

        uint256 waitPay = player_[uid].waitPayTrx.add(dividendsOf(msg.sender));
        waitPay = waitPay.add(player_[uid].reward);

        msg.sender.transfer(waitPay);

        player_[uid].waitPayTrx = 0;
        player_[uid].divMask = G_Mask;
        player_[uid].reward = 0;

    }

    function dailyDivs() private{
        if (now < BeginTime.add(DivsInterval)) {
            return;
        }

        //cal divs
        uint256 allDivs = G_AllDivsPot.mul(8).div(100);
        uint256 nowMask = G_AllDivsPot.mul(1e18).mul(8).div(100).div(G_AllInvest);
        G_Mask = G_Mask.add(nowMask);

        //cal reward
        uint256 allReward = G_AllDivsPot.mul(2).div(100);
        uint256[] memory sort = topSort();
        for (uint256 i=0; i<10; i++) {
            uint256 ratio = 0; //%%
            if (sort[i] == 0) {
                ratio = 4000; 
            } else if (sort[i] == 1) {
                ratio = 2500; 
            } else if (sort[i] == 2) {
                ratio = 1460; 
            } else if (sort[i] == 3) {
                ratio = 800; 
            } else if (sort[i] == 4) {
                ratio = 500; 
            } else if (sort[i] == 5) {
                ratio = 300; 
            } else if (sort[i] == 6) {
                ratio = 200; 
            } else if (sort[i] == 7) {
                ratio = 120; 
            } else if (sort[i] == 8) {
                ratio = 70; 
            } else if (sort[i] == 9) {
                ratio = 50; 
            } 

            uint256 reward = allReward.mul(ratio).div(10000);
            uint256 uid = pIDxAddr_[G_TopPlayer[G_RoundId][i].addr];
            if (uid == 0) {
                continue;
            }
            player_[uid].reward = player_[uid].reward.add(reward);
        }

        G_AllDivsPot = G_AllDivsPot.sub(allDivs).sub(allReward);
        BeginTime = BeginTime.add(DivsInterval);
        G_RoundId = G_RoundId.add(1);
    }

    function topSort() public  view returns(uint256[]) {
		uint256[] memory sort = new uint256[](10);
		for (uint256 i=0; i<10; i++)
		{
		    uint256 sortTemp = 0;
		    for (uint256 j=0; j<10; j++)
		    {
		        if (i==j)
		        {
		            continue;
		        }
		
		        if (G_TopPlayer[G_RoundId][i].invested < G_TopPlayer[G_RoundId][j].invested)
		        {
		            sortTemp = sortTemp + 1;
		        }
		    }
		    sort[i] = sortTemp;
		
		}

        return sort;
    }

   function GetTopPlayer(uint256 roundId) public 
	    view returns(address[],uint256[])
	{
	    address[] memory addrs  = new  address[] (10);
	    uint256[] memory investeds = new  uint256[] (10);
	    
        for(uint i = 0; i < 10; i++) {
	        addrs[i] = G_TopPlayer[roundId][i].addr;
	        investeds[i] = G_TopPlayer[roundId][i].invested;
	    }
	    
	    return
	    (
	        addrs,
	        investeds
	    );
	}
	
    function topRecord(uint256 trx) private{
        G_DailyInvest[G_RoundId][msg.sender] = G_DailyInvest[G_RoundId][msg.sender].add(trx);

        uint256 minPos = 0;
        uint256 minInvest = G_TopPlayer[G_RoundId][0].invested;
        for (uint256 i=0; i<10; i++) {
            if (G_TopPlayer[G_RoundId][i].addr == msg.sender) {
                G_TopPlayer[G_RoundId][i].invested = G_TopPlayer[G_RoundId][i].invested.add(trx);
                return;
            }

            if (G_TopPlayer[G_RoundId][i].invested < minInvest) {
                minInvest = G_TopPlayer[G_RoundId][i].invested;
                minPos = i;
            }
        }

        if (G_TopPlayer[G_RoundId][minPos].invested < G_DailyInvest[G_RoundId][msg.sender]) {
            G_TopPlayer[G_RoundId][minPos].invested = G_DailyInvest[G_RoundId][msg.sender];
            G_TopPlayer[G_RoundId][minPos].addr = msg.sender;
        }
    }

    function dividendsOf(address _customerAddress) public view returns (uint256) {
        uint256 uid = pIDxAddr_[_customerAddress];
        SDDatasets.Player player = player_[uid];

        return player.invested.mul(G_Mask.sub(player.divMask)).div(1e18);
    }
    

}
