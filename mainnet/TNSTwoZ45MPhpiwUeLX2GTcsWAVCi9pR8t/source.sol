pragma solidity ^0.4.25;
contract transferTokenContract {
    constructor() payable public{}
    function() payable public{}
    function transferTokenTest(address toAddress, uint256 tokenValue, trcToken id) payable public    {
        toAddress.transferToken(tokenValue, id);
    }
    function msgTokenValueAndTokenIdTest() public payable returns(trcToken, uint256){
        trcToken id = msg.tokenid;
        uint256 value = msg.tokenvalue;
        return (id, value);
    }
    function getTokenBalanceTest(address accountAddress) payable public returns (uint256){
        trcToken id = 1002082;
        return accountAddress.tokenBalance(id);
    }
}