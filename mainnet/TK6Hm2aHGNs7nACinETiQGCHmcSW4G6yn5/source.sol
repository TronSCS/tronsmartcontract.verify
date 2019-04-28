pragma solidity ^0.4.20; // solhint-disable-line

contract TronkarpFarm{
    //uint256 EGGS_TO_HATCH_TRONKARP=1;
    uint256 public EGGS_TO_HATCH_TRONKARP=86400;//for final version should be seconds in a day
    uint256 public STARTING_TRONKARP=5;
    uint256 PSN=100000000000000;
    uint256 PSNH=50000000000000;
    bool public initialized=false;
    address public feeAddress;
    mapping (address => uint256) public TronKarp;
    mapping (address => uint256) public claimedEggs;
    mapping (address => uint256) public lastHatch;
    mapping (address => address) public referrals;
    uint256 public marketEggs;

    event HatchEggs(address indexed from, uint256 eggs);
    event SellEggs(address indexed from, uint256 value, uint256 eggs);
    event BuyEggs(address indexed from, uint256 value, uint256 eggs);
    // event BuyData(address indexed from, uint256 value, uint256 fee, uint256 rawCb, uint256 cb, uint256 valMinusFee, uint256 eggsBought, uint256 parsedEggsBought);

    constructor () public {
        feeAddress = msg.sender;
    }

    function hatchEggs(address ref) public{
        require(initialized, "Not initialized");
        if(referrals[msg.sender]==0 && referrals[msg.sender]!=msg.sender){
            referrals[msg.sender] = ref;
        }
        uint256 eggsUsed = getMyEggs();
        uint256 newTronKarp = div(eggsUsed,EGGS_TO_HATCH_TRONKARP);
        TronKarp[msg.sender] = add(TronKarp[msg.sender],newTronKarp);
        claimedEggs[msg.sender] = 0;
        lastHatch[msg.sender] = now;

        //send referral eggs
        claimedEggs[referrals[msg.sender]] = add(claimedEggs[referrals[msg.sender]],div(eggsUsed,10));

        //boost market to nerf tronKarpFarm hoarding
        marketEggs = add(marketEggs,div(eggsUsed,10));

        // Consider adding information such as the referrer who gained 10%
        emit HatchEggs(msg.sender, newTronKarp);
    }

    function sellEggs() public{
        require(initialized, "Not initialized");
        uint256 hasEggs = getMyEggs();
        uint256 eggValue = calculateEggSell(hasEggs);
        // uint256 fee = devFee(eggValue);
        uint256 fee = calculateFee(eggValue);
        uint256 eggValueMinusFee = sub(eggValue,fee);
        claimedEggs[msg.sender] = 0;
        lastHatch[msg.sender] = now;
        marketEggs = add(marketEggs,hasEggs);
        feeAddress.transfer(fee);
        msg.sender.transfer(eggValueMinusFee);

        emit SellEggs(msg.sender, eggValueMinusFee, div(hasEggs, EGGS_TO_HATCH_TRONKARP));
    }

    function buyEggs() public payable{
        require(initialized, "Not initialized");
        // Why do we remove the trx to be spent from the contract value before calculating? Need to make sure we do we the same when calculating in the frontend
        // Is it because it has already been added at the point we get here, thus we need to make sure they only get what they were supposed to get?
        // Does this mean we should subtract the dev fee as well? Definately need to look deeper into this
        uint256 fee = calculateFee(msg.value);
        uint256 msgValueMinusFee = sub(msg.value, fee);
        uint256 contractBalance = sub(address(this).balance, msg.value);
        uint256 eggsBought = calculateEggBuy(msgValueMinusFee, contractBalance);
        // The line below wants to remove 4 percent of the eggs, which doesnt work anymore
        // instead we should remove the value of eggs that was counted in the dev fee
        // eggsBought = sub(eggsBought,devFee(eggsBought));

        // Remove devFee in egg value from eggsBought:
        // eggsBought = sub(eggsBought, calculateEggBuy(fee, contractBalance)); // Not necessary because we extracted dev fee first

        feeAddress.transfer(fee);
        claimedEggs[msg.sender] = add(claimedEggs[msg.sender],eggsBought);

        // emit BuyData(msg.sender, msg.value, fee, address(this).balance, contractBalance, msgValueMinusFee, eggsBought, div(eggsBought, EGGS_TO_HATCH_TRONKARP));
        emit BuyEggs(msg.sender, msgValueMinusFee, div(eggsBought, EGGS_TO_HATCH_TRONKARP));
    }
    //magic trade balancing algorithm
    function calculateTrade(uint256 rt,uint256 rs, uint256 bs) public view returns(uint256){
        //(PSN*bs)/(PSNH+((PSN*rs+PSNH*rt)/rt));
        return div(mul(PSN,bs),add(PSNH,div(add(mul(PSN,rs),mul(PSNH,rt)),rt)));
    }
    function calculateEggSell(uint256 eggs) public view returns(uint256){
        return calculateTrade(eggs,marketEggs,address(this).balance);
    }
    function calculateEggBuy(uint256 tron,uint256 contractBalance) public view returns(uint256){
        return calculateTrade(tron,contractBalance,marketEggs);
    }
    function calculateEggBuySimple(uint256 tron) public view returns(uint256){
        return calculateEggBuy(tron,address(this).balance);
    }
    // function devFee(uint256 amount) public pure returns(uint256){
    //     // uint256 oneHundredThousandTron = 100000000000;
    //     // return div(mul(amount,4),100);
    //     return 3000000;
    // }

    function calculateFee(uint256 trxInSun) public pure returns(uint256){
        uint256 OneTRXInSun = 1000000; // 1 TRX
        uint256 lowLimit = 10;
        uint256 midLimit = 100;
        uint256 lowLimitInSun = mul(lowLimit,OneTRXInSun);
        uint256 midLimitInSun = mul(midLimit,OneTRXInSun);
        // uint256 fee = 0;
        if (trxInSun <= lowLimitInSun) {
            return add(OneTRXInSun, div(trxInSun,lowLimit));
        } else if (trxInSun <= midLimitInSun) {
            return add(mul(OneTRXInSun,2), div(trxInSun,midLimit));
        } else {
            return mul(OneTRXInSun,3);
        }
    }

    function seedMarket(uint256 eggs) public payable{
        require(msg.sender==feeAddress, "Can only be seeded by admin");
        require(marketEggs==0, "Market eggs not 0");
        require(!initialized, "Market already initialized");
        initialized = true;

        // Give admin 10% of starting eggs due to the fact that we'll be seeding with 1000 TRX
        claimedEggs[msg.sender] = add(claimedEggs[msg.sender],div(eggs,10));

        // Set market eggs to the amount of eggs to be seeded
        marketEggs = eggs;
    }

    function getFreeTronKarps() public{
        require(initialized, "Not initialized");
        require(TronKarp[msg.sender]==0, "User doesnt have 0 tronkarps");
        lastHatch[msg.sender] = now;
        TronKarp[msg.sender] = STARTING_TRONKARP;
    }
    function getBalance() public view returns(uint256){
        return address(this).balance;
    }
    function getMyTronKarp() public view returns(uint256){
        return TronKarp[msg.sender];
    }
    function getMyEggs() public view returns(uint256){
        return add(claimedEggs[msg.sender],getEggsSinceLastHatch(msg.sender));
    }
    function getEggsSinceLastHatch(address adr) public view returns(uint256){
        uint256 secondsPassed = min(EGGS_TO_HATCH_TRONKARP,sub(now,lastHatch[adr]));
        return mul(secondsPassed,TronKarp[adr]);
    }
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
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
