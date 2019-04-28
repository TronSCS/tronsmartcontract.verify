pragma solidity ^0.4.23;

contract LOW{
  address private ceoAddress;
  address public hotCountryHolder;
  address public lastHotCountryHolder;
  uint256 public lastBidTime;  
  uint256 public lastPot;
  uint256 public RoundNumber;
  uint256 public World_index;
  address public owner;
  Country[] public Countries; 
  uint256 public BASE_TIME_TO_POT = 1440 minutes; 
  uint256 public TIME_TO_POT = BASE_TIME_TO_POT; 
  uint256 public START_PRICE = 50 trx; 
  uint256 public START_PRICE_REGION = 200 trx; 
  uint256 public START_PRICE_WORLD = 1400 trx; 
  
  struct Country {
    address owner;
    uint256 price;
  }
  
    constructor() public { 
      owner = msg.sender;
      ceoAddress = msg.sender; 
      hotCountryHolder = msg.sender;
      RoundNumber = 1;            
      World_index = 0;
      Country memory newCountry=Country({owner:ceoAddress,price: START_PRICE_WORLD});
      Countries.push(newCountry);
      
      for(uint i = 1; i<7; i++){
        Country memory newCountry1=Country({owner:ceoAddress,price: START_PRICE_REGION});
        Countries.push(newCountry1);
      }
      for(uint j = 7; j<115; j++){
        Country memory newCountry2=Country({owner:ceoAddress,price: START_PRICE});
        Countries.push(newCountry2);
      }

    }
    
    modifier onlyOwner()
    {
        require(msg.sender == owner);
        _;
    }
    
    function getRegionInfo(uint index) public view returns(uint256 regionPrice,address regionOwner){
         return (Countries[index].price, Countries[index].owner);
    }
    
    function getCountryInfo(uint index) public view returns(uint256 _id,uint256 price,address countryOwner){
         return (index,Countries[index+7].price, Countries[index+7].owner);
    }
    
    function getData() public view returns(uint256 _currentPot,uint256 _timeleft,address _lastplayer,address _lastwinner){
         return (address(this).balance,SafeMath.add(lastBidTime,BASE_TIME_TO_POT),hotCountryHolder,lastHotCountryHolder);
    }

    function setDeveloperAccount(address _newDeveloperAccount) public onlyOwner {
        require(_newDeveloperAccount != address(0));
        ceoAddress = _newDeveloperAccount;
    }

    function getDeveloperAccount() public view onlyOwner returns (address) {
        return ceoAddress;
    }
    
    function buyCountry(uint256 index, address _referredBy) public payable{
      if(_endContestIfNeeded()){
       
      }
      else{
        Country storage _CurrentCountry = Countries[index];
        Country storage LOTW = Countries[World_index];
        if (index > 6){
              if(index>=7 && index<=24){Country storage LOTR = Countries[6];}else
              if(index>=25 && index<=56){LOTR = Countries[1];}else
              if(index>=57 && index<=97){LOTR = Countries[2];}else
              if(index>=98 && index<=99){LOTR = Countries[3];}else
              if(index>=100 && index<=101){LOTR = Countries[5];}else
              if(index>=102 && index<=114){LOTR = Countries[4];}
          }
        require(msg.value >= _CurrentCountry.price);
        require(msg.sender != _CurrentCountry.owner);
        uint256 sellingPrice = _CurrentCountry.price;
        uint256 purchaseExcess = SafeMath.sub(msg.value, sellingPrice);
        uint256 payment = uint256(SafeMath.div(SafeMath.mul(sellingPrice, 70), 100));
        uint256 devFee = uint256(SafeMath.div(SafeMath.mul(sellingPrice, 5), 100));        
        uint256 Reg_payment   = uint256(SafeMath.div(SafeMath.mul(sellingPrice, 1), 100));
        uint256 World_payment = uint256(SafeMath.div(SafeMath.mul(sellingPrice, 1), 100));

        if(_CurrentCountry.owner != address(this)){
          _CurrentCountry.owner.transfer(payment);                  
        }
        if(LOTW.owner != address(this)){
          LOTW.owner.transfer(World_payment); 
        }
        if (LOTR.owner != address(this) && index > 6){
              LOTR.owner.transfer(Reg_payment); 
        }
        
        address _customerAddress = msg.sender;

        if(
           _referredBy != address(0) &&
           _referredBy != _customerAddress 
       ){
           _referredBy.transfer(SafeMath.div(SafeMath.mul(msg.value, 3), 100)); 
       }
       else {                      
           ceoAddress.transfer(SafeMath.div(SafeMath.mul(msg.value, 3), 100));
       }
        ceoAddress.transfer(devFee);
        _CurrentCountry.price = SafeMath.div(SafeMath.mul(sellingPrice, 160), 100);
        _CurrentCountry.owner = msg.sender;
        hotCountryHolder = msg.sender;
        lastBidTime=block.timestamp;
        TIME_TO_POT=BASE_TIME_TO_POT; 
        msg.sender.transfer(purchaseExcess);
      }
    }
    
    function getBalance() public view returns(uint256){
      return address(this).balance; 
    }
    
    function timePassed() public view returns(uint256){
      if(lastBidTime==0){
        return 0;
      }
      return SafeMath.sub(block.timestamp,lastBidTime);
    }
       
    function timeLeftToPOT() public view returns(uint256){
      if (TIME_TO_POT>timePassed()){
      return SafeMath.sub(TIME_TO_POT,timePassed());
      } else return 0;
    }
    
    function contestOver() public view returns(bool){
      return timePassed()>=TIME_TO_POT;
    }
    
    function _endContestIfNeeded() private returns(bool){
      if(timePassed()>=TIME_TO_POT){
        msg.sender.transfer(msg.value);  
        lastPot=SafeMath.div(SafeMath.mul(address(this).balance, 60), 100);
        lastHotCountryHolder=hotCountryHolder;                
        if (hotCountryHolder != address(this)){
            hotCountryHolder.transfer(lastPot); 
        }
        lastBidTime=block.timestamp;
        RoundNumber +=1;
        if (hotCountryHolder != address(this)){
            _resetCountries();
        }
        
        hotCountryHolder = address(this);
        TIME_TO_POT = BASE_TIME_TO_POT;
       
        return true;
      }
      return false;
    }
    
    function _resetCountries() private{
      Countries[0].owner = ceoAddress;
      Countries[0].price = START_PRICE_WORLD;
      
      for(uint k = 1; k<7; k++){
        Countries[k].owner = ceoAddress;
        Countries[k].price = START_PRICE_REGION;
      }
      
      for(uint l = 7; l<115; l++){
        Countries[l].owner = ceoAddress;
        Countries[l].price = START_PRICE;
      }
      
    }

  }
  library SafeMath {

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
      if (a == 0) {
        return 0;
      }
      uint256 c = a * b;
      assert(c / a == b);
      return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 c = a / b;
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
  