pragma solidity ^0.4.25;

/***********************************************************
 * TronDouble contract for btt 
 *  - GAIN 3.8% PER DAY for 50 days 
 *  - GAIN 4.0% PER DAY for 40 days 
 *  - GAIN 4.4% PER DAY for 30 days 
 *  - GAIN 5.6% PER DAY for 20 days 
 *  
 *  https://www.TronDouble.com/btt
 ***********************************************************/

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
        uint256 aff;    // affiliate vault,directly send
        uint256 laff;   // parent id
        uint256 planCount;
        mapping(uint256=>PalyerPlan) plans;
        uint256 aff1sum; //3 level
        uint256 aff2sum;
        uint256 aff3sum;
    }
    
    struct PalyerPlan {
        uint256 planId;
        uint256 startTime;
        uint256 startTimeSec;
        uint256 invested;    //
        uint256 atTimeSec;    // 
        uint256 payTrx;
        bool isClose;
    }

    struct Plan {
        uint256 interest;    // interest per day %%
        uint256 dayRange;    // days, 0 means No time limit
    }    
}

contract TDBtt {
    using SafeMath              for *;

    address public devAddr_;

    address public partnerAddr_;

    address public affiAddr_;
    
    uint256 ruleSum_ = 4;

    trcToken bttID = 1002000;

    function initUsers() private {

        uint256 pId = G_NowUserId;
        pIDxAddr_[msg.sender] = pId;
        player_[pId].addr = msg.sender;
    }

    uint256 public G_NowUserId = 1000; //first user
    uint256 public G_AllTron = 0;

    mapping (address => uint256) public pIDxAddr_;  
    mapping (uint256 => SDDatasets.Player) public player_; 
    mapping (uint256 => SDDatasets.Plan) private plan_;   
	
    function GetBalance() public 
        view returns(uint256)
    {
		return address(this).tokenBalance(bttID);
	}

    function GetMyBalance(address addr) public 
        view returns(uint256)
    {
		return address(addr).tokenBalance(bttID);
	}

	function GetIdByAddr(address addr) public 
	    view returns(uint256)
	{
	    return pIDxAddr_[addr];
	}
	

	function GetPlayerByUid(uint256 uid) public 
	    view returns(uint256,uint256,uint256,uint256,uint256,uint256)
	{
	    SDDatasets.Player storage player = player_[uid];

	    return
	    (
	        player.aff,
	        player.laff,
	        player.aff1sum,
	        player.aff2sum,
	        player.aff3sum,
	        player.planCount
	    );
	}
	
    function GetPlanByUid(uint256 uid) public 
	    view returns(uint256[],uint256[],uint256[],uint256[],uint256[],bool[])
	{
	    uint256[] memory planIds = new  uint256[] (player_[uid].planCount);
	    uint256[] memory startTimeSecs = new  uint256[] (player_[uid].planCount);
	    uint256[] memory investeds = new  uint256[] (player_[uid].planCount);
	    uint256[] memory atTimeSecs = new  uint256[] (player_[uid].planCount);
	    uint256[] memory payTrxs = new  uint256[] (player_[uid].planCount);
	    bool[] memory isCloses = new  bool[] (player_[uid].planCount);
	    
        for(uint i = 0; i < player_[uid].planCount; i++) {
	        planIds[i] = player_[uid].plans[i].planId;
	        startTimeSecs[i] = player_[uid].plans[i].startTimeSec;
	        investeds[i] = player_[uid].plans[i].invested;
	        atTimeSecs[i] = player_[uid].plans[i].atTimeSec;
	        payTrxs[i] = player_[uid].plans[i].payTrx;
	        isCloses[i] = player_[uid].plans[i].isClose;
	    }
	    
	    return
	    (
	        planIds,
	        startTimeSecs,
	        investeds,
	        atTimeSecs,
	        payTrxs,
	        isCloses
	    );
	}
	
function GetPlanTimeByUid(uint256 uid) public 
	    view returns(uint256[])
	{
	    uint256[] memory startTimes = new  uint256[] (player_[uid].planCount);

        for(uint i = 0; i < player_[uid].planCount; i++) {
	        startTimes[i] = player_[uid].plans[i].startTime;
	    }
	    
	    return
	    (
	        startTimes
	    );
	}	

    constructor(address devAddr, address partnerAddr, address affiAddr) public {
        plan_[1] = SDDatasets.Plan(380,50);
        plan_[2] = SDDatasets.Plan(400,40);
        plan_[3] = SDDatasets.Plan(440,30);
        plan_[4] = SDDatasets.Plan(560,20);

		devAddr_ = devAddr;
		partnerAddr_ = partnerAddr;
		affiAddr_ = affiAddr;
        
        initUsers();
    }
	
	function register_(address addr, uint256 _affCode) private{
        G_NowUserId = G_NowUserId.add(1);
        
        address _addr = addr;
        
        pIDxAddr_[_addr] = G_NowUserId;

        player_[G_NowUserId].addr = _addr;
        player_[G_NowUserId].laff = _affCode;
        player_[G_NowUserId].planCount = 0;
        
        uint256 _affID1 = _affCode;
        uint256 _affID2 = player_[_affID1].laff;
        uint256 _affID3 = player_[_affID2].laff;
        
        player_[_affID1].aff1sum = player_[_affID1].aff1sum.add(1);
        player_[_affID2].aff2sum = player_[_affID2].aff2sum.add(1);
        player_[_affID3].aff3sum = player_[_affID3].aff3sum.add(1);
	}
	
    
    // this function called every time anyone sends a transaction to this contract
    function () external payable {
    } 	
    
    function invest(uint256 _affCode, uint256 _planId) public payable {
	    require(_planId >= 1 && _planId <= ruleSum_, "_planId error");
        require(msg.tokenid==bttID);
		require(msg.tokenvalue >= 1000000, "invest amount error, min depost 1 btt");

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
		
        // record block number and invested amount (msg.tokenvalue) of this transaction
        uint256 planCount = player_[uid].planCount;
        player_[uid].plans[planCount].planId = _planId;
        player_[uid].plans[planCount].startTime = now;
        player_[uid].plans[planCount].startTimeSec = now;
        player_[uid].plans[planCount].atTimeSec = now;
        player_[uid].plans[planCount].invested = msg.tokenvalue;
        player_[uid].plans[planCount].payTrx = 0;
        player_[uid].plans[planCount].isClose = false;
        
        player_[uid].planCount = player_[uid].planCount.add(1);

        G_AllTron = G_AllTron.add(msg.tokenvalue);
        
        if (msg.tokenvalue >= 1000000) {
            distributeRef(msg.tokenvalue, player_[uid].laff);
            
            uint256 devFee = (msg.tokenvalue.mul(4)).div(100);
            devAddr_.transferToken(devFee,bttID);
            
            uint256 partnerFee = (msg.tokenvalue.mul(4)).div(100);
            partnerAddr_.transferToken(partnerFee,bttID);
        } 
        
    }
   
	
	function withdraw() public payable {
	    uint256 uid = pIDxAddr_[msg.sender];
	    require(uid != 0, "no invest");

        uint256 allWithdraw = 0;
        for(uint i = 0; i < player_[uid].planCount; i++) {
	        if (player_[uid].plans[i].isClose) {
	            continue;
	        }

            SDDatasets.Plan plan = plan_[player_[uid].plans[i].planId];
            
            bool bClose = false;
			uint256 calSec = now;
            if (plan.dayRange > 0) {
                
                uint256 endTime = player_[uid].plans[i].startTimeSec.add(plan.dayRange*60*60*24);
                if (now >= endTime){
                    calSec = endTime;
                    bClose = true;
                }
            }
            
            uint256 amount = player_[uid].plans[i].invested * plan.interest / 10000 * (calSec - player_[uid].plans[i].atTimeSec) / (60*60*24);
            allWithdraw = allWithdraw.add(amount);

            // record block number and invested amount (msg.tokenvalue) of this transaction
            player_[uid].plans[i].atTimeSec = calSec;
            player_[uid].plans[i].isClose = bClose;
            player_[uid].plans[i].payTrx += amount;
        }

        if (allWithdraw > 0) {
            msg.sender.transferToken(allWithdraw, bttID);
        }
	}

	
    function distributeRef(uint256 _trx, uint256 _affID) private{
        
        uint256 _allaff = (_trx.mul(8)).div(100);
        
        uint256 _affID1 = _affID;
        uint256 _affID2 = player_[_affID1].laff;
        uint256 _affID3 = player_[_affID2].laff;
        uint256 _aff = 0;

        if (_affID1 != 0) {   
            _aff = (_trx.mul(5)).div(100);
            _allaff = _allaff.sub(_aff);
            player_[_affID1].aff = _aff.add(player_[_affID1].aff);
            player_[_affID1].addr.transferToken(_aff,bttID);
        }

        if (_affID2 != 0) {   
            _aff = (_trx.mul(2)).div(100);
            _allaff = _allaff.sub(_aff);
            player_[_affID2].aff = _aff.add(player_[_affID2].aff);
            player_[_affID2].addr.transferToken(_aff,bttID);
        }

        if (_affID3 != 0) {   
            _aff = (_trx.mul(1)).div(100);
            _allaff = _allaff.sub(_aff);
            player_[_affID3].aff = _aff.add(player_[_affID3].aff);
            player_[_affID3].addr.transferToken(_aff,bttID);
       }

        if(_allaff > 0 ){
            affiAddr_.transferToken(_allaff,bttID);
        }      
    }	

}
