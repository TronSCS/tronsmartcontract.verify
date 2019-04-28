pragma solidity ^0.4.18; // solhint-disable-line

contract ShrimpFarm {
    using SafeMath for uint;
    uint256 public EGGS_TO_HATCH_1SHRIMP=86400;//86400
    uint public VRF_EGG_COST=(1000000000000000000*300)/EGGS_TO_HATCH_1SHRIMP;
    uint256 public STARTING_SHRIMP=300;
    uint256 PSN=100000000000000;
    uint256 PSNH=50000000000000;
    uint public potDrainTime=4 hours;//
    uint public POT_DRAIN_INCREMENT=4 hours;
    uint public POT_DRAIN_MAX=3 days;
    uint public HATCH_COOLDOWN_MAX=1 hours;//1 hour;
    bool public initialized=false;
   
    //bool public completed=false;

    address public ceoAddress;
    mapping (address => uint256) public hatchCooldown;//the amount of time you must wait now varies per user
    mapping (address => uint256) public hatcheryShrimp;
    mapping (address => uint256) public claimedEggs;
    mapping (address => uint256) public lastHatch;
    mapping (address => bool) public hasClaimedFree;
    uint256 public marketEggs;
    mapping (address => bool) public ambassadors;
    uint public lastBidTime;//last time someone bid for the pot
    address public currentWinner;
    uint public potEth=0;//eth specifically set aside for the pot
    uint public totalHatcheryShrimp=0;
    uint public prizeTron=0;

    function ShrimpFarm() public{
        ceoAddress=msg.sender;
        lastBidTime=now;
        currentWinner=msg.sender;
    }
    function finalizeIfNecessary() public{
      if(lastBidTime.add(potDrainTime)<now){
        currentWinner.transfer(this.balance);//winner gets everything
        initialized=false;
        //completed=true;
      }
    }
    function addAmbassadors(address customer) public{
        require(ceoAddress==msg.sender);
        ambassadors[customer]=true;
    }
    function getPotCost() public view returns(uint){
        return totalHatcheryShrimp.div(100);
    }
    function stealPot() public {

      if(initialized){
          _hatchEggs(msg.sender);
          uint cost=getPotCost();
          hatcheryShrimp[msg.sender]=hatcheryShrimp[msg.sender].sub(cost);//cost is 1% of total shrimp
          totalHatcheryShrimp=totalHatcheryShrimp.sub(cost);
          setNewPotWinner();
          hatchCooldown[msg.sender]=0;
      }
    }
    function setNewPotWinner() private {
      finalizeIfNecessary();
      if(initialized && msg.sender!=currentWinner){
        potDrainTime=lastBidTime.add(potDrainTime).sub(now).add(POT_DRAIN_INCREMENT);//time left plus one hour
        if(potDrainTime>POT_DRAIN_MAX){
          potDrainTime=POT_DRAIN_MAX;
        }
        lastBidTime=now;
        currentWinner=msg.sender;
      }
    }
    function isHatchOnCooldown() public view returns(bool){
      return lastHatch[msg.sender].add(hatchCooldown[msg.sender])<now;
    }
    function hatchEggs(address ref) public{
      _hatchEggs(ref);
    }
    function _hatchEggs(address ref) private{
        require(initialized);
        uint256 eggsUsed=getMyEggs();
        require(eggsUsed>0);
        uint256 newShrimp=SafeMath.div(eggsUsed,EGGS_TO_HATCH_1SHRIMP);
        hatcheryShrimp[msg.sender]=SafeMath.add(hatcheryShrimp[msg.sender],newShrimp);
        totalHatcheryShrimp=totalHatcheryShrimp.add(newShrimp);
        claimedEggs[msg.sender]=0;
        lastHatch[msg.sender]=now;
        hatchCooldown[msg.sender]=HATCH_COOLDOWN_MAX;
        //send referral eggs
        if(ref!=msg.sender){
          claimedEggs[ref]=claimedEggs[ref].add(eggsUsed.div(7));
        }
        //boost market to nerf shrimp hoarding
        marketEggs=SafeMath.add(marketEggs,SafeMath.div(eggsUsed,7));
    }
    function getHatchCooldown(uint eggs) public view returns(uint){
      uint targetEggs=marketEggs.div(50);
      if(eggs>=targetEggs){
        return HATCH_COOLDOWN_MAX;
      }
      return (HATCH_COOLDOWN_MAX.mul(eggs)).div(targetEggs);
    }
    function reduceHatchCooldown(address addr,uint eggs) private{
      uint reduction=getHatchCooldown(eggs);
      if(reduction>=hatchCooldown[addr]){
        hatchCooldown[addr]=0;
      }
      else{
        hatchCooldown[addr]=hatchCooldown[addr].sub(reduction);
      }
    }
    function sellEggs() public{
        require(initialized);
        finalizeIfNecessary();
        uint256 hasEggs=getMyEggs();
        require(hasEggs>0);
        uint256 eggValue=calculateEggSell(hasEggs);
        //uint256 fee=devFee(eggValue);
        uint potfee=potFee(eggValue);
        claimedEggs[msg.sender]=0;
        lastHatch[msg.sender]=now;
        marketEggs=SafeMath.add(marketEggs,hasEggs);
        //ceoAddress.transfer(fee);
        prizeTron=prizeTron.add(potfee);
        msg.sender.transfer(eggValue.sub(potfee));
    }
    function buyEggs(address ref) public payable{
        require(initialized);
        require(msg.value<=10000000000 || this.balance-msg.value>=100000000000);
        require(ambassadors[msg.sender]==true || block.timestamp >=1552843800);
        
        uint256 eggsBought=calculateEggBuy(msg.value,SafeMath.sub(this.balance,msg.value));
        eggsBought=eggsBought.sub(devFee(eggsBought));
        ceoAddress.transfer(devFee(msg.value));
        claimedEggs[msg.sender]=SafeMath.add(claimedEggs[msg.sender],eggsBought);
        reduceHatchCooldown(msg.sender,eggsBought); //reduce the hatching cooldown based on eggs bought

        //steal the pot if bought enough
        uint potEggCost=getPotCost().mul(EGGS_TO_HATCH_1SHRIMP);//the equivalent number of eggs to the pot cost in shrimp
        if(eggsBought>potEggCost){
          //hatcheryShrimp[msg.sender]=hatcheryShrimp[msg.sender].add(getPotCost());//to compensate for the shrimp that will be lost when calling the following
          //stealPot();
          setNewPotWinner();
        }
        _hatchEggs(ref);
    }
    //magic trade balancing algorithm
    function calculateTrade(uint256 rt,uint256 rs, uint256 bs) public view returns(uint256){
        //(PSN*bs)/(PSNH+((PSN*rs+PSNH*rt)/rt));
        return SafeMath.div(SafeMath.mul(PSN,bs),SafeMath.add(PSNH,SafeMath.div(SafeMath.add(SafeMath.mul(PSN,rs),SafeMath.mul(PSNH,rt)),rt)));
    }
    function calculateEggSell(uint256 eggs) public view returns(uint256){
        return calculateTrade(eggs,marketEggs,this.balance.sub(prizeTron));
    }
    function calculateEggBuy(uint256 eth,uint256 contractBalance) public view returns(uint256){
        return calculateTrade(eth,contractBalance.sub(prizeTron),marketEggs);
    }
    function calculateEggBuySimple(uint256 eth) public view returns(uint256){
        return calculateEggBuy(eth,this.balance);
    }
    function potFee(uint amount) public view returns(uint){
        return SafeMath.div(SafeMath.mul(amount,20),100);
    }
    function devFee(uint256 amount) public view returns(uint256){
        return SafeMath.div(SafeMath.mul(amount,6),100);
    }
    function seedMarket(uint256 eggs) public payable{
        require(msg.sender==ceoAddress);
        require(!initialized);
        //require(marketEggs==0);
        initialized=true;
        marketEggs=eggs;
        lastBidTime=now;
    }
   
    //allow sending eth to the contract
    function () public payable {}

    function getBalance() public view returns(uint256){
        return this.balance;
    }
    function getMyShrimp() public view returns(uint256){
        return hatcheryShrimp[msg.sender];
    }
    function getMyEggs() public view returns(uint256){
        return SafeMath.add(claimedEggs[msg.sender],getEggsSinceLastHatch(msg.sender));
    }
    function getEggsSinceLastHatch(address adr) public view returns(uint256){
        uint256 secondsPassed=min(EGGS_TO_HATCH_1SHRIMP,SafeMath.sub(now,lastHatch[adr]));
        return SafeMath.mul(secondsPassed,hatcheryShrimp[adr]);
    }
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}

library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
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
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}