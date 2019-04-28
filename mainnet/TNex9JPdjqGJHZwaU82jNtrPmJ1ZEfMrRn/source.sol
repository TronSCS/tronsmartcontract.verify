pragma solidity ^0.4.25;
contract test{
  uint public key;
  function set(uint inkey) public returns(uint){
    key=inkey;
    return inkey;
  }
}