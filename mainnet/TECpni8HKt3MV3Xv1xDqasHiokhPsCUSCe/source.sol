pragma solidity ^ 0.4.25;

library SafeMath {

  function mul(uint256 a, uint256 b) internal pure returns(uint256) {
    if (a == 0) {
      return 0;
    }

    uint256 c = a * b;
    require(c / a == b);

    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns(uint256) {
    require(b > 0);
    uint256 c = a / b;

    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns(uint256) {
    require(b <= a);
    uint256 c = a - b;

    return c;
  }

  function add(uint256 a, uint256 b) internal pure returns(uint256) {
    uint256 c = a + b;
    require(c >= a);

    return c;
  }

}


contract Trxbanks {
  using SafeMath for uint256;

    struct Player{
    uint256 deposit;
    uint256 payout;
    address refer;
    uint256 referPayout;
    uint256 time;
    uint256 timeW;
    uint256 timeLo ;
  }


  event Withdraw(address investor, uint256 amount);
  event Balance(address investor,uint256 timeW, uint256 amount);


  uint256 public interest = 2500;  // 25% , this number is divided by 10000
  uint256 public minimum = 1000000; // minimum deposit = 1 trx
  uint256 private referralRate = 10; // 10% to valid referrals
  uint256 private devDivRate = 10; // 10% to marketing and dev
  uint256 public totalPlayers; // 10% to marketing and dev
  uint256 public totalRefPayout; // Total referral payout
  uint256 public totalPayout; // Totale withdraw
  
  mapping(address => Player) public players;
  mapping(address => uint256) public referrer;

  address public owner;

  constructor() public {
    owner = msg.sender;
  }

  modifier onlyOwner(){
    require(msg.sender == owner);
    _;
  }


  function deposit(address _referredBy) public payable{
    require(msg.value > minimum);
    uint256 amount = msg.value;
    Player storage player = players[msg.sender];

     if( player.deposit >0 ){
      
      withdraw();
    }
    player.deposit = player.deposit.add(msg.value);
    if (player.time == 0) {
      player.time = now;
      player.timeW = now;
     
      if (_referredBy != address(0) && _referredBy != msg.sender) {
        player.refer = _referredBy;
      } else {
        player.refer = msg.sender;
      }

    }
    if (address(player.refer) != msg.sender) {
      uint256 divRef = amount.div(referralRate);
      address(player.refer).transfer(divRef);
      totalRefPayout = totalRefPayout.add(divRef);
      referrer[player.refer] = referrer[player.refer].add(divRef);
    }

    owner.transfer(amount.div(devDivRate));

   
    
  }
 
 function getBalance() view public returns(uint256) {
    Player storage player = players[msg.sender];
   if(player.timeW>0){
    uint256 timeW=player.timeW;
    uint256 timediff = (now - timeW).div(60);
    uint256 balance = ((player.deposit.mul(interest).div(10000)).mul(timediff)).div(1440);
    return balance;
    
   }else{
    return 0;
   }
    
  }

  function withdraw()  public returns(bool){
    require(players[msg.sender].timeW > 0);
    uint256 balance = getBalance();
     Player storage player = players[msg.sender];
    //balance=11;
    if (address(this).balance < balance) {
      balance = address(this).balance;
    }
    msg.sender.transfer(balance);
    player.timeW = now;
    player.timeLo = now;
     player.payout= player.payout.add(balance);
    totalPayout = totalPayout.add(balance);
    emit Withdraw(msg.sender, balance);
    return true;
  }

  function changeOwner(address _owner) onlyOwner public{
    owner = _owner;
  }

  function getReferBalance(address _address) public view returns(uint256) {
    return address(_address).balance;
  }

  function getDeposit() public view returns(uint256) {
    return players[msg.sender].deposit;
  }

  function getContractBalance() public view returns(uint256) {
    return address(this).balance;
  }
  function getAContractAddress() public view returns(address) {
    return this;
  }

  function getOwnerAddress() public view returns(address) {
    return owner;
  }

  function getOwnertBalance() public view returns(uint256) {
    return address(owner).balance;
  }

  function getAddress0() public pure returns(address) {
    return address(0);
  }
  
}